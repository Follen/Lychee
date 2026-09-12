-- Explicit preparation only; compiled into Engine.lua, never run at addon load.
local _, carrier = ...
function carrier.PrepareEllesmere(ctx)
    local eui=_G.EllesmereUI
    local r={status="preparing",loadedBefore=eui and eui._deferredLoaded==true or false,
        addonPresent=type(eui)=="table",newPermanentHook=false,
        scope="Normal settings initialization and one existing/default page; no search prebuild, selectors, setters, installer or business actions"}
    ctx.report.ellesmerePreparation=r
    local function skip(reason) r.status="skipped";r.reason=reason end
    if type(eui)~="table" then skip("addon_global_missing");return end
    for _,key in ipairs({"EnsureLoaded","ShowModule","Hide","IsShown","GetMainFrame","GetActiveModule","GetActivePage"}) do
        if type(eui[key])~="function" then skip("missing_api:"..key);return end
    end
    if InCombatLockdown() then error("Combat before Ellesmere preparation") end
    if eui:IsShown() then skip("upstream_window_already_visible");return end
    if eui._openPending then skip("upstream_open_pending");return end
    if eui._unlockCoreInit then skip("upstream_login_initialization_pending");return end
    if eui.SpecOverrides_EditSessionActive and eui.SpecOverrides_EditSessionActive() then skip("upstream_override_edit_session");return end
    local original=eui._RegisterSearchEntry
    if type(original)~="function" then skip("search_registration_unavailable");return end
    local owned,wrapper
    local observer={capture=ctx.capture,report=r}
    wrapper=function(...)
        original(...)
        if observer.capture then
            local ok,why=pcall(observer.capture,...)
            if not ok then observer.report.captureError=tostring(why) end
        end
    end
    local function restore()
        observer.capture=nil;observer.report=nil
        if eui._RegisterSearchEntry==wrapper then eui._RegisterSearchEntry=original;r.registrationRestored=true
        elseif not r.registrationRestored then r.registrationRestored=false;r.restoreReason="callback_replaced_by_other_owner" end
        if owned then
            if not InCombatLockdown() then eui:Hide();r.closed=not eui:IsShown();owned=false
            else r.closeDeferred="upstream combat handler owns protected close" end
        end
    end
    ctx.setCleanup(restore);eui._RegisterSearchEntry=wrapper
    r.upstreamVersion=eui.VERSION
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        r.coreLoadedOrLoadingBefore,r.coreLoadedBefore=C_AddOns.IsAddOnLoaded("EllesmereUI")
        r.optionsLoadedOrLoadingBefore,r.optionsLoadedBefore=C_AddOns.IsAddOnLoaded("EllesmereUIOptions")
    end
    local began=debugprofilestop();ctx.timed(eui.EnsureLoaded,eui)
    r.initializationMs=debugprofilestop()-began;r.loadedAfter=eui._deferredLoaded==true
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        r.coreLoadedOrLoadingAfter,r.coreLoadedAfter=C_AddOns.IsAddOnLoaded("EllesmereUI")
        r.optionsLoadedOrLoadingAfter,r.optionsLoadedAfter=C_AddOns.IsAddOnLoaded("EllesmereUIOptions")
    end
    if not r.loadedAfter or type(eui._modules)~="table" then r.status="failed";r.reason="settings_initialization_incomplete";restore();return end
    r.initializationRetained=true
    ctx.pause(0.05) -- Separate executions; do not create the upstream deferred Show callback.
    if InCombatLockdown() then error("Combat before Ellesmere ShowModule") end
    local selected=eui:GetActiveModule()
    if not selected or not eui._modules[selected] then
        if eui._modules.EllesmereUIUnitFrames then selected="EllesmereUIUnitFrames"
        else
            local names={}
            for name,definition in pairs(eui._modules) do
                if type(name)=="string" and type(definition)=="table" and type(definition.pages)=="table" and #definition.pages>0 then names[#names+1]=name end
                if #names>128 then error("Ellesmere module limit") end
            end
            table.sort(names);selected=names[1]
        end
    end
    if not selected then r.status="failed";r.reason="no_registered_settings_module";restore();return end
    r.selectedModule=selected;owned=true
    local begin=debugprofilestop();ctx.timed(eui.ShowModule,eui,selected);r.showCallMs=debugprofilestop()-begin
    ctx.pause(0.8)
    r.shown=eui:IsShown()==true;r.page=eui:GetActivePage()
    local frame=eui:GetMainFrame();if frame and frame.GetRect then r.rect={frame:GetRect()} end
    r.optionsCaptured=ctx.optionCount();r.preparationWallMs=debugprofilestop()-began
    restore()
    r.status=r.shown and r.closed and r.registrationRestored and not r.captureError and "complete" or "failed"
    if r.status~="complete" then r.reason=r.reason or "visibility_capture_or_cleanup_check_failed" end
end
