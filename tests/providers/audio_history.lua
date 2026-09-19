local f=dofile("tests/support/settings_fixture.lua").Load()
local I=f.I
f.add(f.setting("Sound_MasterVolume","主音量",.5,.5),{minValue=0,maxValue=1,steps=100},"SettingsSliderControlTemplate")
I.Registry:SetReady(true);assert(f.M:Init());f.advance()
dofile("addon/Lychee/Core/UserPreferences.lua")
local english=GetLocale()=="enUS" or GetLocale()=="enGB"
local expected=english and "Set Music to 0%" or "音乐设为 0%"
local query=english and "set master volume to 30" or "设置音量为30"
local records
I.Providers.entries[f.M.id].definition.query({raw=query},function(rows) records=rows end)
assert(records and #records==1,"audio command missing")
assert(records[1].title==(english and "Set Master volume to 30%" or "主音量设为 30%"),"TOC-order audio title: "..tostring(records[1].title).." / "..tostring(records[1].id))
assert(records[1].subtitle==(english and "Current 50% → Set to 30%" or "当前 50% → 设置为 30%"),"TOC-order audio read falsely unavailable")
-- Replay a real slider history entry: no entry display was stored by BeginEdit.
local ref={kind="invocation",product="retail",providerID="builtin.blizzard-settings",actionID="set-volume",
 actionVersion=1,target={version=1,key={channel="music"}},args={percent=0},entryID="set-volume",title="设置音量",sourceTitle="暴雪设置"}
local restored=assert(I.Providers:Resolve(ref,{}))
assert(restored.text==expected,"slider history lost channel/value: "..tostring(restored.text))
assert(restored.icon=="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga","slider history lost icon")
assert(restored.kindTitle==(english and "Blizzard settings" or "暴雪设置"),"history lost source category")
assert(restored.ref.args.percent==0 and restored.ref.target.key.channel=="music","history changed action")
assert(ref.title=="设置音量" and ref.icon==nil,"restore must not rewrite the saved reference")
local saved={kind="invocation",product="retail",providerID=f.M.id,actionID="set-volume",actionVersion=1,
 target={version=1,key={channel="master"}},args={percent=30},entryID="volume:master:30",title="主音量"}
local first=assert(I.Providers:Resolve(saved,{}))
assert(first.text==(english and "Set Master volume to 30%" or "主音量设为 30%"))
saved.args.percent=50
local second=assert(I.Providers:Resolve(saved,{}))
assert(second.text==(english and "Set Master volume to 50%" or "主音量设为 50%"))
assert(first.ref.args.percent==30 and second.ref.args.percent==50,"same entryID merged different history arguments")
local owner=I.Providers.entries[f.M.id]
local reader=owner.definition.readEntry
owner.definition.readEntry=function(id,context)
 context.ref.args.percent=20 -- Reader receives an isolated copy.
 return reader(id,context)
end
local guarded=assert(I.Providers:Resolve(ref,{}))
assert(guarded.text==ref.title and guarded.ref.args.percent==0,"mismatching reader replaced saved action presentation")
owner.definition.readEntry=function() return nil end
assert(I.Providers:Resolve(ref,{}).text==ref.title,"missing optional presentation must keep saved fallback")
owner.definition.readEntry=reader
assert(#f.writes==0,"history restoration changed settings")
local command={kind="command",product="retail",providerID=f.M.id,actionID="set-volume",actionVersion=1,target={version=1,key={channel="master"}},title="主音量"}
local controls=assert(I.Providers:Resolve(command,{}))
assert(controls.interaction.primaryActionID=="adjust-volume" and controls.interaction.actions[1].title==(english and "Adjust directly" or "直接调整"),"old command history lost its controls entrance")
assert(I.UserPreferences:TouchRecent(controls,"adjust-volume"))
assert(I.UserPreferences:GetRecent()[1].kind=="command","replaying a saved controls command lost its target")
assert(I.UserPreferences:TouchRecent(first,"panel",{transition={panelID="controls"}}))
assert(I.UserPreferences:GetRecent()[1].kind=="command" and I.UserPreferences:GetRecent()[1].args==nil,"opening invocation controls recorded a write")
assert(I.UserPreferences:Resolve(I.UserPreferences:GetRecent()[1]).interaction.primaryActionID=="adjust-volume")
local edit=assert(I.Invocations:BeginEdit(f.M.id,"set-volume",{version=1,key={channel="music"}},{mode="latest"},{}))
assert(edit:Push({percent=0}));f.advance();assert(edit:Finish());f.advance()
local actual=assert(I.UserPreferences:GetRecent()[1])
assert(actual.args.percent==0 and actual.target.key.channel=="music")
assert(I.UserPreferences:Resolve(actual).text==expected,"actual BeginEdit history lacks its final value")
print("Audio history PASS: real stored slider reference restores channel/value/icon/category without executing")
