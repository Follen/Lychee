-- Combined real Provider/index workload; external game collection is deterministic.
-- lua tests/performance_memory.lua [--check|--stress]
-- LYCHEE_PERF_BASELINE optionally points to an extracted committed source tree.
local baselineRoot=os.getenv("LYCHEE_PERF_BASELINE")
if baselineRoot and baselineRoot~="" then
    local nativeDofile=dofile
    dofile=function(file)
        if file:sub(1,15)=="addon/Lychee/" then file=baselineRoot.."/"..file end
        return nativeDofile(file)
    end
end
local originalPrint=print
collectgarbage("collect")
local baseline=collectgarbage("count")
print=function() end
dofile("tests/builtin_providers_smoke.lua")
print=originalPrint
local I=LycheeInternal
collectgarbage("collect")
local bosses=collectgarbage("count")-baseline
local mountNames={"星光云端翔龙","无敌","机械路霸","翡翠梦境角鹰兽","冰霜巨龙","炽焰凤凰","午夜战马","岩石始祖幼龙"}
C_Timer=nil
C_MountJournal={
    GetMountIDs=function() local ids={};for n=1,1500 do ids[n]=n end;return ids end,
    GetMountInfoByID=function(n) return mountNames[(n-1)%#mountNames+1]..n,100000+n,123456,false,true,1,false,false,nil,false,true,n end,
}
TestPackages:File("addon/Lychee_Player/Runtime/CatalogLedger.lua")
assert(loadfile("addon/Lychee_Player/Mounts/Provider.lua"))("Lychee_Player",TestPackages.namespaces.Lychee_Player);TestPackages:Refresh()
assert(TestPackages.Modules.Mounts:Init())
if arg[1]=="--stress" then
    local spells={}
    for n=1,1000 do
        spells[n]={id="spell:"..n,title=(n%2==0 and "冰霜技能" or "传送技能")..n,kindTitle="技能",keywords={"技能"},
            aliases={"stress spell "..n},icon=123456,actions={{id="cast",title="施放",kind="secure-spell",spellID=200000+n}},
            drag={type="spell",spellID=200000+n}}
    end
    assert(dofile("tests/support/provider_fixture.lua"):Register({id="stress.spells",title="压力技能",version="1.0.0",apiVersion=3,catalog=spells}))
end
collectgarbage("collect")
local retained=collectgarbage("count")-baseline
local queries={"熔","熔火","熔火之心","巫妖王","纹章","星","星光","星光云端","无敌","午夜","not-found","翡翠"}
local function run()
    for n=1,4 do
        for _,text in ipairs(queries) do
            local _,items=I.Search.Query:Query(text,{visible=true})
            if text~="not-found" then assert(#items>0,"lost search matches: "..text) end
        end
    end
end
run();collectgarbage("collect")
local warm=collectgarbage("count")
collectgarbage("stop")
local start=os.clock();run();local ms=(os.clock()-start)*1000
local allocated=collectgarbage("count")-warm
collectgarbage("restart");collectgarbage("collect")
local growth=collectgarbage("count")-warm
local count=0;for _,ns in pairs(TestPackages.namespaces) do for _,m in pairs(ns.Modules) do if type(m)=="table" and m.handle and m.handle.catalog then count=count+m.handle.catalog:GetState().entries end end end
print(string.format("MEMORY entries=%d builtins_KiB=%.1f combined_KiB=%.1f 48_queries_alloc_KiB=%.1f retained_growth_KiB=%.1f query_mean_ms=%.3f",count,bosses,retained,allocated,growth,ms/48))
if arg[1]=="--disable" then
    assert(I.Registry:SetUserEnabled("lychee.mounts",false))
    collectgarbage("collect")
    local disabled=collectgarbage("count")-baseline
    assert(I.Registry:SetUserEnabled("lychee.mounts",true))
    collectgarbage("collect")
    print(string.format("DISABLE retained_KiB=%.1f reenabled_KiB=%.1f",disabled,collectgarbage("count")-baseline))
end
if arg[1]=="--check" then
    assert(retained<7168,"combined directory exceeds 7 MiB retained memory budget")
    assert(allocated<4096,"48 searches allocate more than 4 MiB")
    assert(growth<512,"repeated search retains more than 512 KiB")
end
