local I=_G.LycheeInternal
local words=I.Builtin.AudioLanguage.words
local A={channels={
    {id="master",cvar="Sound_MasterVolume",title="主音量",words=words.master},
    {id="music",cvar="Sound_MusicVolume",title="音乐",words=words.music},
    {id="sfx",cvar="Sound_SFXVolume",title="音效",words=words.sfx},
    {id="ambience",cvar="Sound_AmbienceVolume",title="环境音",words=words.ambience},
    {id="dialog",cvar="Sound_DialogVolume",title="对话",words=words.dialog},
},byID={},subscribers={},sequence=0}
I.Builtin.AudioAdapter=A
for _,channel in ipairs(A.channels) do A.byID[channel.id]=channel end
-- Match the actual setting identity, never its translated label. Voice chat
-- and accessibility settings can share labels but are different controls.
function A.ChannelForSetting(data)
    if not C_CVar or type(C_CVar.GetCVar)~="function" or type(C_CVar.SetCVar)~="function" then return nil end
    local setting=data and data.setting
    if not setting or type(setting.GetVariable)~="function" then return nil end
    local variable=setting:GetVariable()
    for _,channel in ipairs(A.channels) do
        if variable==channel.cvar then return channel.id end
    end
end
function A.Read(channelID)
    local channel=A.byID[channelID]
    if not channel or not C_CVar or type(C_CVar.GetCVar)~="function" then return nil end
    local ok,value=pcall(C_CVar.GetCVar,channel.cvar)
    value=ok and tonumber(value)
    if not value or value~=value or value<0 or value>1 then return nil end
    return math.floor(value*100+0.5)
end
function A.Write(channelID,percent)
    local channel=A.byID[channelID]
    if not channel or type(percent)~="number" or percent%1~=0 or percent<0 or percent>100 then return {status="failed",code="INVALID_ARGS"} end
    if InCombatLockdown and InCombatLockdown() then return {status="failed",code="COMBAT_LOCKED"} end
    local native=I.Builtin.SettingsAdapter
    local spec=native and native.byVariable[channel.cvar]
    if spec then
        A.writing=channelID
        local ok,result=pcall(native.Write,spec,"number",{value=percent},false)
        A.writing=nil
        return ok and result or {status="indeterminate",code="AUDIO_UNCONFIRMED"}
    end
    local before=A.Read(channelID)
    if before==nil or not C_CVar or type(C_CVar.SetCVar)~="function" then return {status="failed",code="AUDIO_UNAVAILABLE"} end
    if before==percent then return {status="succeeded",changed=false} end
    A.writing=channelID
    local ok,result=pcall(C_CVar.SetCVar,channel.cvar,tostring(percent/100))
    A.writing=nil
    if not ok or result~=true then return {status="failed",code="AUDIO_WRITE_FAILED"} end
    if A.Read(channelID)~=percent then return {status="indeterminate",code="AUDIO_UNCONFIRMED"} end
    return {status="succeeded",changed=true}
end
function A.Observe(channelID,publish)
    if not A.byID[channelID] or type(publish)~="function" then return nil end
    local count=0;for _ in pairs(A.subscribers) do count=count+1 end
    if count>=16 then return nil end
    local token={channel=channelID,publish=publish};A.subscribers[token]=true
    if not A.frame then A.frame=CreateFrame("Frame") end
    A.frame:SetScript("OnEvent",function(_,_,name)
        if type(name)~="string" then return end
        local snapshot={}
        for observer in pairs(A.subscribers) do snapshot[#snapshot+1]=observer end
        for _,observer in ipairs(snapshot) do
            local channel=A.byID[observer.channel]
            if observer.publish and channel.cvar:lower()==name:lower() then
                A.sequence=A.sequence+1
                observer.publish({stateRevision=A.sequence,values={percent=A.Read(observer.channel)},correlation=A.writing==observer.channel and "builtin.blizzard-settings:volume" or nil})
            end
        end
    end)
    A.frame:RegisterEvent("CVAR_UPDATE")
    return function()
        token.publish=nil;A.subscribers[token]=nil
        if not next(A.subscribers) then A.frame:UnregisterAllEvents();A.frame:SetScript("OnEvent",nil) end
    end
end
