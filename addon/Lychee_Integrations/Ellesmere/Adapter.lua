-- Version-sensitive upstream contract. No UI construction, polling or index prebuild.
local _,I=...
local A={}
I.Modules.EllesmereAdapter=A
local function upstream()
    local eui=_G.EllesmereUI
    if type(eui)=="table" then return eui end
end
function A.Modules(eui) return type(eui._modules)=="table" and eui._modules or nil end
function A.Translate(eui,value)
    if type(eui.L)~="function" then return value end
    local ok,result=pcall(eui.L,value)
    return ok and type(result)=="string" and result or value
end
function A.Display(eui,page)
    local overrides=eui.TAB_LABEL_OVERRIDES
    local display=type(overrides)=="table" and overrides[page]
    return type(display)=="string" and display or page
end
function A.Page(eui,folder,page)
    local modules=A.Modules(eui)
    local config=modules and modules[folder]
    if type(config)~="table" or type(config.pages)~="table" then return end
    for index=1,math.min(#config.pages,1024) do if config.pages[index]==page then return config end end
end
function A.Ready()
    if InCombatLockdown and InCombatLockdown() then return nil,"请先脱离战斗" end
    local eui=upstream()
    if not eui then return nil,"请先启用 Ellesmere UI" end
    if type(eui.EnsureLoaded)~="function" or not pcall(eui.EnsureLoaded,eui)
        or not eui._deferredLoaded or not A.Modules(eui) then return nil,"Ellesmere UI 设置暂不可用" end
    return eui
end
function A.Observe(owner)
    local eui=upstream()
    if not eui or type(eui._RegisterSearchEntry)~="function" or type(hooksecurefunc)~="function" then return end
    if owner.hooked==eui then return end
    -- An unremovable hook short-circuits through Capture's active/owner checks.
    -- Publish the attachment only after a successful hook, allowing failure retry.
    local ok=pcall(hooksecurefunc,eui,"_RegisterSearchEntry",function(...) owner:Capture(eui,...) end)
    if ok then owner.hooked=eui end
end
function A.Suppressed(eui) return eui._searchIndexSuppress end
function A.Navigate(eui,module,page,option)
    if type(eui.NavigateToElementSettings)~="function" then return false end
    local preSelect
    if option and option.setter and option.selector then preSelect=function() option.setter(option.selector) end end
    return pcall(eui.NavigateToElementSettings,eui,module,page,option and option.section,preSelect,option and option.label)
end
function A.Unlock()
    if InCombatLockdown and InCombatLockdown() then return nil,"请先脱离战斗" end
    local eui=upstream()
    if not eui then return nil,"请先启用 Ellesmere UI" end
    if type(eui.EnsureUnlockCore)=="function" and not pcall(eui.EnsureUnlockCore,eui) then return nil,"Ellesmere UI 设置暂不可用" end
    if type(eui.OpenUnlockMode)~="function" or not pcall(eui.OpenUnlockMode,eui)
        or not eui._unlockActive then return nil,"Ellesmere UI 设置暂不可用" end
    return true
end
A.Get=upstream
