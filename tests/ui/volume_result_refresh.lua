local env=assert(loadfile("tests/support/palette.lua"))(arg[1])
local now,timers,value,writes=0,{},.3,0
GetTime=function() return now end;GetTimePreciseSec=GetTime
C_Timer={NewTimer=function(delay,fn) local t={at=now+delay,fn=fn,Cancel=function(self) self.cancelled=true end};timers[#timers+1]=t;return t end}
local function advance()
 for _=1,100 do now=now+.02;local due={};for _,t in ipairs(timers) do if not t.done and not t.cancelled and t.at<=now then t.done=true;due[#due+1]=t end end;for _,t in ipairs(due) do t.fn() end end
end
C_CVar={GetCVar=function() return tostring(value) end,SetCVar=function(_,v) value=tonumber(v);writes=writes+1;return true end}
for _,file in ipairs({"Audio/Locales","BlizzardSettings/Provider","BlizzardSettings/Graphics","BlizzardSettings/Adapter","Audio/Language","Audio/Adapter","Audio/View","Audio/Provider","BlizzardSettings/Aliases","BlizzardSettings/Language","BlizzardSettings/Invocations"}) do dofile("addon/Lychee/Builtin/"..file..".lua") end
local I=LycheeInternal
I.Registry:SetReady(true);assert(I.Builtin.BlizzardSettings:Init());advance()
local palette=Lychee.UI.Palette:Create();assert(palette:Show())
local text=arg[1]=="enUS" and "set master volume to 40" or "把音量调节到40"
palette.input:SetText(text)
I.Search.Session:Input(text);advance()
local row=palette.list.rows[1]
assert(row.item and row.item.subtext==(arg[1]=="enUS" and "Current 30% → Set to 40%" or "当前 30% → 设置为 40%"),"initial volume missing")
local queries=0;local original=I.Search.Query.Query
I.Search.Query.Query=function(self,...) queries=queries+1;return original(self,...) end
assert(I.ResultActionExecutor:ExecutePrimary(row).ok)
advance()
assert(value==.4 and writes==1,"volume was not written")
assert(row.subtext:GetText():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")==(arg[1]=="enUS" and "Current 40%" or "当前 40%"),"visible result stayed at "..row.subtext:GetText())
assert(queries==0,"action refresh reran search")
assert(palette.input:GetText()==text,"refresh changed input")
print("Volume result refresh PASS: actual write and visible subtitle, no search rerun")


local current=row.item
assert(not palette:RefreshResultDisplay(current,{subtext="wrong"},palette.session,palette.generation-1))
assert(row.item==current and current.subtext==(arg[1]=="enUS" and "Current 40%" or "当前 40%"),"stale generation replaced the row")
C_CVar.SetCVar=function() return false end
value=.3
assert(not I.ResultActionExecutor:ExecutePrimary(row))
assert(row.item==current and current.subtext==(arg[1]=="enUS" and "Current 40%" or "当前 40%"),"failed action painted an unconfirmed value")
palette:Hide("test")
assert(not palette:RefreshResultDisplay(current,{subtext="wrong"},palette.session,palette.generation))
assert(queries==0,"cleanup started a search")
