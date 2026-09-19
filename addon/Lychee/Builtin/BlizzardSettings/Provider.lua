local I=_G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.blizzard-settings")
local C = I.Builtin.CatalogProvider
local iconRoot="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
local function nameID(name)
    local hash=0
    for index=1,#name do hash=(hash*31+name:byte(index))%2147483647 end
    return tostring(hash)
end
local function build(_,put,checkpoint)
    put({id="reload",title=L["重载界面"],kind="command",kindTitle=L["系统"],icon=iconRoot.."reload.tga",
        subtitle=L["重新加载插件与界面"],aliases={"rl","reload","/rl","/reload"},actions={"reload"}},"reload:1")
    if I.Search.RuntimeIdentity:Current().product=="retail" then
    put({id="cdm",title=L["暴雪冷却管理器"],kind="setting",kindTitle=L["暴雪设置"],icon=iconRoot.."cooldown-manager.tga",
        subtitle=L["打开冷却管理器设置"],aliases={"cdm","cooldown manager","冷却设置"},actions={"cdm"}},"cdm:1")
    end
    if I.Builtin.SettingsInvocations then
        local adapter=I.Builtin.SettingsAdapter
        adapter.Scan(checkpoint);I.Builtin.SettingsLanguage.Build(adapter.ordered,checkpoint)
        for _,spec in ipairs(adapter.ordered) do
            local record=I.Builtin.SettingsInvocations.Record(spec)
            put(record,spec.id.."\0"..spec.name.."\0"..spec.categoryName.."\0"..spec.kind.."\0"..tostring(adapter.Staged(spec)))
            checkpoint()
        end
        return
    end
    if not SettingsPanel or not SettingsPanel.GetAllCategories or not Settings then return end
    local count=0
    for _,category in ipairs(SettingsPanel:GetAllCategories()) do
        if category:GetCategorySet()==Settings.CategorySet.Game then
            local categoryID,categoryName=category:GetID(),category:GetName()
            local layout=SettingsPanel:GetLayout(category)
            local initializers=layout and layout.GetInitializers and layout:GetInitializers()
            if initializers then
                local seen={}
                for _,initializer in ipairs(initializers) do
                    local data=initializer.data
                    local name=data and data.name
                    if type(name)=="string" and name~="" and not seen[name] then
                        seen[name]=true; count=count+1
                        if count>4094 then error("SETTINGS_LIMIT") end
                        local id="setting:"..categoryID..":"..nameID(name)
                        local audio=I.Builtin.AudioAdapter
                        local channel=audio and audio.ChannelForSetting(data)
                        local aliases={categoryName,"设置","settings"}
                        if channel then
                            aliases[#aliases+1],aliases[#aliases+2],aliases[#aliases+3]="音量","volume","audio"
                            for _,word in ipairs(audio.byID[channel].words) do aliases[#aliases+1]=word end
                        end
                        put({id=id,title=name,kind="setting",kindTitle=L["暴雪设置"],icon=iconRoot.."settings.tga",
                            subtitle=L:Format(channel and "%s · 直接调整" or "%s · 点击定位",categoryName),aliases=aliases,
                            payload={categoryID=categoryID,name=name,channel=channel},
                            actions=channel and {"adjust-volume","open"} or {"open"},
                            primaryActionID=channel and "adjust-volume" or "open"},categoryID.."\0"..categoryName.."\0"..name.."\0"..(channel or ""))
                    end
                    checkpoint()
                end
            end
        end
        checkpoint()
    end
end
local actions={
    open={title=L["打开并定位"],run=function(entry)
        local p=entry.payload
        if not C_SettingsUtil or not C_SettingsUtil.OpenSettingsPanel then return {ok=false,code="SETTINGS_NOT_READY"} end
        C_SettingsUtil.OpenSettingsPanel(p.categoryID,p.name)
        local selected=SettingsPanel and SettingsPanel:GetCurrentCategory()
        local ok=selected and selected:GetID()==p.categoryID and SettingsPanel:IsShown()
        return {ok=ok==true,close=ok==true}
    end},
    reload={title=L["重载界面"],run=function()
        if not ReloadUI then return {ok=false,code="UI_UNAVAILABLE"} end
        ReloadUI(); return {ok=true,close=true}
    end},
    cdm={title=L["打开冷却管理器"],run=function()
        if not CooldownViewerSettings and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
        if not CooldownViewerSettings or not CooldownViewerSettings.ShowUIPanel then return {ok=false,code="UI_UNAVAILABLE"} end
        CooldownViewerSettings:ShowUIPanel()
        local ok=CooldownViewerSettings:IsShown()
        return {ok=ok==true,close=ok==true}
    end},
}
local M=C:New("builtin.blizzard-settings",L["暴雪设置"],{"ADDON_LOADED"},build,actions)
function M:onEvent(event,name)
    if event~="ADDON_LOADED" or name=="Blizzard_Settings" or name=="Blizzard_SettingsDefinitions_Frame" then self:MarkDirty() end
end
I.Builtin.BlizzardSettings=M
function M:Init()
    if I.Builtin.Audio then I.Builtin.Audio:Attach(self) end
    if I.Builtin.SettingsInvocations then I.Builtin.SettingsInvocations.Attach(self) end
    return C.Init(self)
end
