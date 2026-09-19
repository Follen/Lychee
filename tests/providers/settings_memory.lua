local f=dofile("tests/support/settings_fixture.lua").Load()
for n=1,500 do f.add(f.setting("memory_toggle_"..n,"Test toggle "..n,false,true)) end
collectgarbage("collect");local before=collectgarbage("count")
f.I.Registry:SetReady(true);assert(f.M:Init());f.advance()
collectgarbage("collect");print(string.format("SETTINGS500 retained_KiB=%.2f",collectgarbage("count")-before))
local r=f.I.Providers.entries[f.M.id].recordMap["setting:memory_toggle_1"]
local targets={};local unique=0
for _,a in ipairs(r.actions) do if a.invocation and not targets[a.invocation.target] then targets[a.invocation.target]=true;unique=unique+1 end end
print("targets_per_record",unique)
local public=f.I.Providers:PublicRecord(r,f.M.id)
public.actions[1].invocation.target.key.setting="wrong"
assert(r.actions[1].invocation.target.key.setting=="setting:memory_toggle_1","public copy changed retained target")
assert(unique==1,"identical target tables retained per action")
