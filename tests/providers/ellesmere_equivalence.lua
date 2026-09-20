-- Deterministic provider-interface transcript, usable against a prior source file.
-- The caller compares stdout byte-for-byte; no implementation internals are read.
local definition,active,timers=nil,false,{}
local digestA,digestB=0,0
local transcript=arg and arg[2]=="--transcript"
local function write(...)
    for i=1,select("#",...) do
        local text=tostring(select(i,...))
        for j=1,#text do local byte=text:byte(j);digestA=(digestA*31+byte)%2147483647;digestB=(digestB*37+byte)%2147483647 end
        if transcript then io.write(text) end
    end
end
local translations={Frames="框体",Health="生命",Layout="布局",Border="边框"}
local L=setmetatable({resources={}},{__index=function(_,key) return key end})
LycheeInternal={Search={},ProviderModules={Support={Scope=function() return {products={"retail"}} end}},
    ProviderLocales={Module=function() return L end}}
LycheeDB={}
dofile("addon/Lychee/Search/Normalizer.lua")
dofile("addon/Lychee/Core/Boundary.lua")
dofile("addon/Lychee/Core/Resources.lua")
function InCombatLockdown() return false end
function debugprofilestop() return 0 end
function hooksecurefunc(owner,key,callback)
    local original=owner[key];owner[key]=function(...) original(...);callback(...) end
end
C_Timer={NewTimer=function(_,fn)
    local t={fn=fn};function t:Cancel() self.cancelled=true end
    timers[#timers+1]=t;return t
end}
Lychee={RegisterProvider=function(_,desc)
    definition=desc
    return {GetState=function() return true end}
end}
EllesmereUI={_modules={},_deferredLoaded=true,_RegisterSearchEntry=function() end,
    TAB_LABEL_OVERRIDES={Health="Life"},L=function(s) return translations[s] or s end,
    EnsureLoaded=function() end,EnsureUnlockCore=function() end,
    OpenUnlockMode=function(self) self._unlockActive=true end,
    NavigateToElementSettings=function(_,folder,page,section,select,label)
        write("ACTION\t",folder,"\t",page,"\t",section or "","\t",label or "","\n")
        if select then select() end
    end}
local adapter=io.open("addon/Lychee/Providers/Ellesmere/Adapter.lua","r")
if adapter then adapter:close();dofile("addon/Lychee/Providers/Ellesmere/Adapter.lua") end
dofile(arg[1] or "addon/Lychee/Providers/Ellesmere/Provider.lua")
local M=LycheeInternal.ProviderModules.Ellesmere
M:Init();local disable=definition.onEnable()
for m=1,8 do
    local pages={"Frames","Health","Layout"}
    for i=1,45 do pages[#pages+1]="Page "..i end
    EllesmereUI._modules["Module"..m]={title="Module title "..m,pages=pages}
    for i=1,80 do
        EllesmereUI._RegisterSearchEntry("Border "..i,nil,"Tooltip "..i,"Module"..m,pages[i%#pages+1],"Section",
            function(key) write("SELECT\t",key,"\n") end,"selector"..m)
    end
end
local function emit(value)
    if type(value)~="table" then return string.format("%q",tostring(value)) end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local parts={};for _,key in ipairs(keys) do parts[#parts+1]=emit(key).."="..emit(value[key]) end
    return "{"..table.concat(parts,",").."}"
end
for _,query in ipairs({"","生命","框体","布局","border","边框","module","page 4","Module title 3 Border","notfound","unlock"}) do
    for _,limit in ipairs({1,7,20,50}) do
        local result
        local resources=LycheeInternal.Resources:Create(function() return true end)
        definition.query({normalized=LycheeInternal.Search.Normalizer:Normalize(query),limit=limit,
            filter={sourceID="builtin.ellesmere:records"}},function(rows) result=rows end,{resources=resources})
        while #timers>0 do local t=table.remove(timers,1);if not t.cancelled then t.fn() end end
        LycheeInternal.Resources:Close(resources,"complete")
        assert(result)
        write("QUERY\t",query,"\t",limit,"\n",emit(result),"\n")
        for _,row in ipairs(result) do
            assert(emit(definition.resolve(row.id))==emit(row),"resolve preserves full record")
        end
        if result[1] then assert(definition.actions[result[1].actions[1]].run(result[1]).ok) end
    end
end
disable()
-- Established by running this transcript against 3b0af04's unmodified Provider.
assert(digestA==827088762 and digestB==192411782,"full business transcript differs from the pre-optimization baseline")
print("Ellesmere transcript PASS: 44 queries, full records/resolution/action arguments "..digestA..":"..digestB)
