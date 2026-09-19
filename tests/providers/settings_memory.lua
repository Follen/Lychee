local f=dofile("tests/support/settings_fixture.lua").Load()
for n=1,500 do f.add(f.setting("memory_toggle_"..n,"Test toggle "..n,false,true)) end
local calls=0
local original=f.I.Builtin.SettingsInvocations.Record
f.I.Builtin.SettingsInvocations.Record=function(spec) calls=calls+1;return original(spec) end
collectgarbage("collect");local before=collectgarbage("count")
f.I.Registry:SetReady(true);assert(f.M:Init());f.advance()
collectgarbage("collect");print(string.format("SETTINGS500 retained_KiB=%.2f",collectgarbage("count")-before))
assert(calls==0,"directory eagerly materialized actions")
local owner=f.I.Providers.entries[f.M.id]
assert(owner.recordMap["setting:memory_toggle_1"].actions==nil,"Host retained eager actions")
local _,hits=f.I.Search.Query:Query("test toggle",{visible=true})
assert(#hits==20 and calls==20,"reader must materialize only selected results")
local record=assert(f.M.readEntry("setting:memory_toggle_1"))
assert(#record.actions==5 and record.primaryActionID=="toggle")
record.actions[1].invocation.target.key.setting="wrong"
assert(f.M.readEntry("setting:memory_toggle_1").actions[1].invocation.target.key.setting=="setting:memory_toggle_1")
assert(f.M.handle:Unregister())
assert(not next(f.A.byID))
assert(f.M:Init());f.advance()
assert(f.I.Providers:Resolve({providerID=f.M.id,entryID="setting:memory_toggle_1"}),"re-registration cannot restore")
print("Settings memory PASS: lazy actions, bounded materialization, isolated restore and lifecycle")
