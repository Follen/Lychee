local locale=arg[1] or "zhCN"
local flavor=arg[2] or "Mainline"
local interfaces={Mainline=120100,Mists=50504,Wrath=38002,TBC=20506}
local timers,calls={},{}
local virtual=0
local frames,locked=0,false
function GetLocale() return locale end
function GetBuildInfo() return "fixture","70000","fixture",interfaces[flavor] end
function UnitGUID() return "Player-1-fixture" end
function InCombatLockdown() return locked end
function debugprofilestop() return os.clock()*1000 end
function GetTime() return 100 end
function CreateFrame() frames=frames+1;return {SetScript=function() end,RegisterEvent=function() end,Hide=function() end} end
function IsSecureCmd(s) return s:lower()=="/cast" end
DEFAULT_CHAT_FRAME={editBox={}}
C_Timer={NewTimer=function(delay,fn)
    local timer={fn=fn,due=virtual+delay};function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer;return timer
end}
C_AddOns={GetAddOnMetadata=function(folder,key)
    if folder=="ExampleAddon" then
        return key=="Title" and "Example tools" or key=="IconTexture" and "Interface\\AddOns\\ExampleAddon\\logo.tga" or nil
    end
    if folder~="RurutiaSuite" then return end
    if key=="Title" then return "|cffff559aRurutiaSuite|r" end
    if key=="IconTexture" then return "Interface\\AddOns\\RurutiaSuite\\Media\\icon.tga" end
end}
local console={embeds={}}
function console:RegisterChatCommand(alias,method)
    local key="ACECONSOLE_"..alias:upper()
    if type(method)=="string" then
        SlashCmdList[key]=function(message,box) self[method](self,message,box) end
    else SlashCmdList[key]=method end
    _G["SLASH_"..key.."1"]="/"..alias
end
function console:UnregisterChatCommand(alias)
    local key="ACECONSOLE_"..alias:upper()
    SlashCmdList[key]=nil;_G["SLASH_"..key.."1"]=nil;hash_SlashCmdList[("/"..alias):upper()]=nil
end
function console:Embed(receiver)
    receiver.RegisterChatCommand=self.RegisterChatCommand
    receiver.UnregisterChatCommand=self.UnregisterChatCommand
    self.embeds[receiver]=true
end
-- A receiver embedded before Lychee loads still holds the original method.
local early={name="ExampleAddon",ownerFolder="ExampleAddon",Open=function() end}
console:Embed(early)
LibStub={GetLibrary=function(_,name) if name=="AceConsole-3.0" then return console end end}
local hooks=0
function hooksecurefunc(object,key,callback)
    hooks=hooks+1
    local original=object[key]
    object[key]=function(...) local result=original(...);callback(...);return result end
end
function issecurevariable(object,key)
    if type(object)=="table" and rawget(object,"ownerFolder") then return false,object.ownerFolder end
    if key=="ARBITRARY_REGISTRATION" or key=="/EXAMPLELOGO" then return false,"ExampleAddon" end
    if key=="ACECONSOLE_RS" or key=="/RS" then return false,"SharedLibraryLoader" end
    return true
end
local maxBatch=0
local function drain()
    local count=0
    while #timers>0 do
        count=count+1;assert(count<10000,"runaway")
        table.sort(timers,function(a,b) return a.due<b.due end)
        local timer=table.remove(timers,1)
        if not timer.cancelled then virtual=timer.due;local start=os.clock();timer.fn();maxBatch=math.max(maxBatch,(os.clock()-start)*1000) end
    end
end
dofile("tests/support/runtime.lua").Load("provider",{"Providers/SlashCommands/Locales/enUS.lua","Providers/SlashCommands/Locales/zhCN.lua","Search/ProviderPolicy.lua","Core/Scheduler.lua","Providers/SlashCommands/Provider.lua"},{toc="Lychee_"..flavor..".toc"})
local I=LycheeInternal
I.Registry:SetReady(true)
local M=I.ProviderModules.SlashCommands
local baseFrames=frames
M:Init()
assert(M.handle and M.active and #timers==0 and frames==baseFrames)
local definition=I.Providers.entries[M.id].definition
assert(#definition.scope.products==4 and definition.icon:find("slash%-commands"))
local proxy={}
SlashCmdList=setmetatable({},{__index=proxy})
hash_SlashCmdList={};hash_ChatTypeInfoList={}
local function register(key,slash,fn)
    SlashCmdList[key]=fn or function(msg,box) assert(msg=="" and box==DEFAULT_CHAT_FRAME.editBox);calls[#calls+1]=slash end
    _G["SLASH_"..key.."1"]=slash
end
local function import()
    for key,fn in pairs(SlashCmdList) do
        local index=1
        while _G["SLASH_"..key..index] do
            local slash=_G["SLASH_"..key..index]:upper()
            hash_SlashCmdList[slash]=fn;hash_ChatTypeInfoList[slash]=key;index=index+1
        end
        proxy[key]=fn;SlashCmdList[key]=nil
    end
end
local function query(text)
    local result
    local _,initial=I.Search.Query:Query(text,{visible=true},nil,function(rows) result=rows end)
    drain()
    local records={}
    for _,row in ipairs(result or initial) do records[#records+1]=assert(I.Providers.entries[M.id].dynamic[row.id]) end
    return records
end
register("DEV","/dev");SLASH_DEV2="/developer"
RurutiaSuite={name="RurutiaSuite",ownerFolder="RurutiaSuite",OnChatCommand=function() end}
console:Embed(RurutiaSuite)
RurutiaSuite:RegisterChatCommand("rs","OnChatCommand")
register("CAST","/cast",function() error("secure dispatch") end)
local dev=query("dev")[1];assert(dev.id=="slash:/dev" and dev.title=="/dev")
assert(query("/dev")[1].id==dev.id)
local rs=query("rs")[1];assert(rs.id=="slash:/rs" and rs.icon:find("RurutiaSuite",1,true))
assert(rs.title=="RurutiaSuite","use actual addon metadata, not a translated hardcoded title")
register("ARBITRARY_REGISTRATION","/examplelogo")
early:RegisterChatCommand("earlylogo","Open")
assert(query("earlylogo")[1].icon:find("ExampleAddon",1,true),"pre-existing embedded references must be observed")
local hookCount=hooks
M:ObserveConsole();M:ObserveConsole();assert(hooks==hookCount,"no duplicate hooks")
local example=query("examplelogo")[1]
assert(example and example.icon=="Interface\\AddOns\\ExampleAddon\\logo.tga","arbitrary command must use registering addon logo")
assert(#query("cast")==0 and #calls==0,"discovery never executes commands")
assert(definition.actions.run.run(dev).ok and calls[1]=="/dev")
import()
assert(next(SlashCmdList)==nil and query("dev")[1].id==dev.id,"imported command remains searchable")
assert(query("rs")[1].icon==rs.icon and M:Resolve(dev.id))
-- The shared library loader is deliberately wrong in the fixture. A replaced,
-- uncaptured wrapper must lose the old identity instead of borrowing its logo.
register("ACECONSOLE_RS","/rs",function() end)
assert(query("rs")[1].icon:find("slash%-commands"),"stale owner or library loader must not supply a logo")
RurutiaSuite:RegisterChatCommand("rs","OnChatCommand");import()
assert(query("rs")[1].icon==rs.icon)
early:UnregisterChatCommand("earlylogo")
assert(not M:Resolve("slash:/earlylogo"))
early:RegisterChatCommand("renamedlogo",function() end)
assert(query("renamedlogo")[1].icon==example.icon,"function callbacks use validated generic receiver identity")
local provenance=issecurevariable;issecurevariable=nil
assert(query("examplelogo")[1].icon:find("slash%-commands"),"missing provenance API degrades without guessing")
issecurevariable=provenance
register("DEV","/dev",function() calls[#calls+1]="replacement" end)
assert(definition.actions.run.run(dev).ok and calls[#calls]=="replacement","pending replacement wins hash")
import()
hash_SlashCmdList["/DEV"]=nil
assert(not M:Resolve(dev.id) and not definition.actions.run.run(dev).ok,"hash removal is authoritative")
register("DEV","/dev",function() error("fixture command failure") end)
assert(not definition.actions.run.run(dev).ok)
register("DEV","/dev")
assert(definition.actions.run.run(dev).ok,"retry")
locked=true;assert(not definition.actions.run.run(dev).ok);locked=false
for index=1,1000 do register("FIX"..index,"/fixture"..index) end
local function managed(reply)
    local scope=assert(I.Resources:Create(function() return M.active end,nil,assert(M.handle:Resources())))
    local cancel=M:Query({normalized="fixture",limit=20},reply,{resources=scope})
    return function() cancel("cancelled");I.Resources:Close(scope,"cancelled") end
end
local replied=false
local cancel=managed(function() replied=true end);cancel();drain();assert(not replied)
local rows=query("fixture");assert(#rows==20)
local all={};for _,row in ipairs(rows) do assert(row.id:match("^slash:/fixture"));assert(not all[row.id]);all[row.id]=true end
-- Independent full enumeration and full sort, rather than the Provider's Top K.
local expected={}
for index=1,1000 do
    local slash="/fixture"..index
    local score=I.Search.Normalizer:MatchRecord("fixture",{title=slash,aliases={slash,slash:sub(2)}}).confidence
    expected[#expected+1]={id="slash:"..slash,score=score}
end
table.sort(expected,function(a,b) return a.score>b.score or a.score==b.score and a.id<b.id end)
local rawRows
local closeReference=managed(function(result) rawRows=result end);drain();closeReference()
for index=1,20 do
    assert(rawRows[index].id==expected[index].id,"Provider full-scan order differs")
    assert(all[expected[index].id],"Host lost a selected candidate")
end
assert(query("cmd: dev")[1].id==dev.id and query("命令: dev")[1].id==dev.id)
assert(#query("missingcommanduniquexyz")==0)
assert(M.handle:SetAvailability(false));drain();assert(not M.active and not M:Resolve(dev.id))
assert(M.handle:SetAvailability(true));assert(M.active and query("dev")[1].id==dev.id)
assert(query("rs")[1].icon==rs.icon,"enable restores still-current captured ownership")
collectgarbage("collect");local before=collectgarbage("count")
collectgarbage("stop")
for index=1,20 do assert(#query("fixture")==20) end
local allocated=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect");local retained=collectgarbage("count")-before
assert(retained<128,"retained growth")
assert(maxBatch<8,"callback budget")
assert(#timers==0 and frames==baseFrames,"no idle resources")
for index=1001,8300 do register("FIX"..index,"/fixture"..index) end
local status=query("fixture")
assert(#status==1 and status[1].id=="status" and M.lastError:find("SLASH_COMMAND_LIMIT",1,true),"overflow is visible")
print(string.format("Slash commands PASS %s/%s: allocation=%.1f KiB retained=%.1f KiB maxBatch=%.3f ms",locale,flavor,allocated,retained,maxBatch))
