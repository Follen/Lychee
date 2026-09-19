local I=_G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.blizzard-settings")
local C = I.Builtin.CatalogProvider
local iconRoot="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\"
local function document(spec)
    return {id=spec.id,title=spec.name,aliases=spec.aliases,subtitle=L:Format("%s · 点击定位",spec.categoryName)}
end
local function build(owner,put,checkpoint)
    put({id="reload",title=L["重载界面"],
        subtitle=L["重新加载插件与界面"],aliases={"rl","reload","/rl","/reload"}},"reload:1")
    if I.Search.RuntimeIdentity:Current().product=="retail" then
    put({id="cdm",title=L["暴雪冷却管理器"],
        subtitle=L["打开冷却管理器设置"],aliases={"cdm","cooldown manager","冷却设置"}},"cdm:1")
    end
    local adapter=I.Builtin.SettingsAdapter
    adapter.Scan(checkpoint);I.Builtin.SettingsLanguage.Build(adapter.ordered,checkpoint)
    for _,spec in ipairs(adapter.ordered) do
        put(document(spec),spec.id.."\0"..spec.name.."\0"..spec.categoryName)
        checkpoint()
    end
end
local actions={
    open={title=L["打开并定位"],run=function(entry)
        local spec=I.Builtin.SettingsAdapter.byID[entry.id]
        local result=I.Builtin.SettingsAdapter.Open(spec)
        local ok=result.status=="succeeded"
        return {ok=ok,close=ok,code=result.code,message=ok and L:Format("已打开：%s",spec.name) or nil}
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
function M:Record(spec)
    local record=document(spec)
    record.kind,record.kindTitle,record.icon="setting",L["暴雪设置"],iconRoot.."settings.tga"
    record.actions,record.primaryActionID={"open"},"open"
    return record
end
function M:onStop() I.Builtin.SettingsAdapter.Clear() end
function M:Init()
    if not self.readEntry then
        local function read(id,context)
            if id=="reload" then
                return {id=id,title=L["重载界面"],kind="command",kindTitle=L["系统"],icon=iconRoot.."reload.tga",
                    subtitle=L["重新加载插件与界面"],aliases={"rl","reload","/rl","/reload"},actions={"reload"}}
            elseif id=="cdm" and I.Search.RuntimeIdentity:Current().product=="retail" then
                return {id=id,title=L["暴雪冷却管理器"],kind="setting",kindTitle=L["暴雪设置"],icon=iconRoot.."cooldown-manager.tga",
                    subtitle=L["打开冷却管理器设置"],aliases={"cdm","cooldown manager","冷却设置"},actions={"cdm"}}
            end
            local spec=I.Builtin.SettingsAdapter.byID[id]
            if spec then return self:Record(spec) end
        end
        self.entryMode,self.readEntry="documents",read
    end
    return C.Init(self)
end
