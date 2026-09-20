local locale=arg[1] or "zhCN"
local baseline=arg[2] and arg[2]~="-" and arg[2] or nil
local timers,frames={},{}
local locked=false
function GetLocale() return locale end
function GetBuildInfo() return "12.1.0","69875","fixture",120100 end
function UnitGUID() return "Player-toys" end
function GetTime() return 100 end
function debugprofilestop() return os.clock()*1000 end
function InCombatLockdown() return locked end
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(k,v) self[k]=v end
    frames[#frames+1]=f;return f
end
C_Timer={NewTimer=function(_,fn)
    local t={fn=fn};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
local owned,names,reads,requests={}, {},0,{}
function PlayerHasToy(id) reads=reads+1;return owned[id]==true end
C_ToyBox={GetToyInfo=function(id) return id,names[id],134400 end,
    GetToyFromIndex=function() error("do not use filtered journal") end,
    SetFilterString=function() error("do not modify journal filters") end}
C_Item={GetItemNameByID=function(id) return names[id] end,GetItemIconByID=function() return 134400 end,RequestLoadItemDataByID=function(id) requests[id]=(requests[id] or 0)+1 end}
dofile("tests/support/runtime.lua").Load("provider",{"Core/Scheduler.lua","Search/ProviderPolicy.lua",
    "Providers/Shared/CatalogProvider.lua","Providers/Toys/Data.lua","Providers/Toys/Provider.lua",
    "Providers/Toys/Locales/enUS.lua","Providers/Toys/Locales/zhCN.lua"},
    {overrides=baseline and {["Providers/Toys/Provider.lua"]=baseline}})
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.ProviderModules.Toys
local ids=I.ProviderModules.ToyIDs
for index,id in ipairs(ids) do
    owned[id]=index%2==0
    names[id]=(locale=="zhCN" or locale=="zhTW") and ("测试玩具"..id) or ("Fixture Toy "..id)
end
local peak=0
local function drain()
    local count=0
    while #timers>0 do
        count=count+1;assert(count<10000,"unbounded work")
        local t=table.remove(timers,1)
        if not t.cancelled then local start=os.clock();t.fn();peak=math.max(peak,(os.clock()-start)*1000) end
    end
end
collectgarbage("collect");local base=collectgarbage("count")
assert(M:Init());drain();assert(not M.lastError,M.lastError)
local entry=I.Providers.entries[M.id]
local function query(text)
    local _,rows=I.Search.Query:Query(text,{visible=true})
    drain();return rows
end
for index,id in ipairs(ids) do
    assert((entry.recordMap["toy:"..id]~=nil)==owned[id],"collection differs from independent reference")
end
local toy=ids[2]
local rows=query(tostring(toy));assert(#rows>0)
if not baseline then assert(not entry.recordMap["toy:"..toy].actions,"directory retains eager actions") end
local row=assert(baseline and entry.recordMap["toy:"..toy] or I.Providers:ReadEntry(M.id,"toy:"..toy))
assert(row.actions[1].kind=="secure-item" and row.actions[1].itemID==toy)
if not baseline then
    row.actions[1].itemID=-1
    assert(I.Providers:ReadEntry(M.id,"toy:"..toy).actions[1].itemID==toy,"reader leaked mutable actions")
    assert(not M.readEntry("toy:999999") and not M.readEntry("invalid"))
end
assert(entry.definition.icon:find("toys.tga",1,true) and #entry.definition.scope.products==1)
local beforeReads=reads
local materialized=0
for index=1,20 do materialized=materialized+#query(tostring(toy)) end
assert(reads-beforeReads==(baseline and 0 or materialized),"warm searches must only check selected toys")
if arg[3] then
    local function encode(value)
        if type(value)~="table" then return string.format("%q",tostring(value)) end
        local keys,out={},{}
        for key in pairs(value) do keys[#keys+1]=key end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        for _,key in ipairs(keys) do out[#out+1]=encode(key)..":"..encode(value[key]) end
        return "{"..table.concat(out,",").."}"
    end
    local output=assert(io.open(arg[3],"w"))
    local queries={"玩具","toy","fixture","测试",tostring(toy),"XYZ-unmatched","toy 1","放置"}
    for _,text in ipairs(queries) do
        local result={}
        for _,hit in ipairs(query(text)) do
            result[#result+1]={id=hit.id,text=hit.text,kindTitle=hit.kindTitle,subtext=hit.subtext,
                icon=hit.icon,payload=hit.payload,confidence=hit.confidence,evidence=hit.evidence,
                interaction=hit.interaction,ref=hit.ref}
        end
        output:write(text,"\t",encode(result),"\n")
    end
    output:close()
    collectgarbage("collect");local startMemory=collectgarbage("count");collectgarbage("stop")
    local start=os.clock()
    for round=1,3 do for _,text in ipairs(queries) do query(text) end end
    local ms=(os.clock()-start)*1000;local allocation=collectgarbage("count")-startMemory
    collectgarbage("restart");collectgarbage("collect")
    print(string.format("Toy mixed24 ms=%.3f alloc=%.1f KiB growth=%.1f KiB",ms,allocation,collectgarbage("count")-startMemory))
end
local missing=ids[4];names[missing]=nil;M:onEvent("TOYS_UPDATED");drain()
assert(entry.recordMap["toy:"..missing].title:find(tostring(missing),1,true) and requests[missing]==1)
M:onEvent("ITEM_DATA_LOAD_RESULT",missing,false);drain();assert(requests[missing]==1)
names[missing]="Loaded toy";M:onEvent("ITEM_DATA_LOAD_RESULT",missing,true);drain()
assert(entry.recordMap["toy:"..missing].title=="Loaded toy")
owned[toy]=false;M:onEvent("TOYS_UPDATED");drain();assert(not entry.recordMap["toy:"..toy])
owned[999999]=true;names[999999]="Hotfix toy";M:onEvent("NEW_TOY_ADDED",999999);drain()
assert(entry.recordMap["toy:999999"] and #M.extra==1)
M:onEvent("NEW_TOY_ADDED",999999);drain();assert(#M.extra==1)
locked=true;beforeReads=reads;M:onEvent("TOYS_UPDATED");drain();assert(reads==beforeReads and M.dirty)
locked=false;M.frame.OnEvent(M.frame,"PLAYER_REGEN_ENABLED");drain();assert(not M.dirty)
M:MarkDirty();assert(M.handle:SetAvailability(false));drain()
assert(not M.active and not M.timer and not M.job and not next(M.frame.events))
assert(M.handle:SetAvailability(true));drain();assert(entry.recordMap["toy:999999"])
local synchronous=ids[6];names[synchronous]=nil
local originalRequest=C_Item.RequestLoadItemDataByID
C_Item.RequestLoadItemDataByID=function(id)
    names[id]="Synchronous toy";M:onEvent("ITEM_DATA_LOAD_RESULT",id,true)
end
M:MarkDirty();drain();assert(entry.recordMap["toy:"..synchronous].title=="Synchronous toy")
C_Item.RequestLoadItemDataByID=originalRequest
local frameCount=#frames
collectgarbage("collect");local steady=collectgarbage("count");collectgarbage("stop")
for index=1,20 do query(tostring(missing)) end
local allocated=collectgarbage("count")-steady;collectgarbage("restart");collectgarbage("collect")
local growth=collectgarbage("count")-steady
assert(growth<128 and peak<8 and #frames==frameCount and #timers==0)
assert(M.handle:Unregister());drain();assert(not M.handle and not next(M.frame.events))
print(string.format("Toys PASS %s ids=%d retained=%.1f KiB alloc20=%.1f KiB growth=%.1f KiB peak=%.3f ms",locale,#ids,steady-base,allocated,growth,peak))
