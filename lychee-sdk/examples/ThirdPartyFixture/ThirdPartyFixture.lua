-- Public API 2 integration. Lychee is optional; no Host internals are accessed.
local state = { committed=nil, enabled=false, diagnostics={}, opens=0, drags=0 }
local waitingFrame, cachedPanel
local function stopWaiting()
    if waitingFrame then waitingFrame:UnregisterAllEvents(); waitingFrame:SetScript("OnEvent", nil) end
end
local function attach()
    if state.committed then return state.committed end
    local SDK = _G.Lychee
    if not SDK or not SDK.Supports then return nil end
    if not SDK:Supports(2, 1) then state.diagnostics.UNSUPPORTED_API=true; stopWaiting(); return nil end
    local handle, err = SDK:RegisterProvider({
        id="third-party-fixture", apiVersion=2, version="2.0.0",
        title={default="Third-party fixture",zhCN="第三方示例"},
        entries={
            {id="fixture-item-12345",title={default="Fixture entry",zhCN="第三方示例条目"},
                kindTitle={default="Example",zhCN="示例"},description="An ordinary addon entry with independent interactions.",
                aliases={default="fixture demo",zhCN="示例"},payload={itemID=12345},actions={"inspect","keep-open"},
                drag={type="provider",handler="move",title="Move inside the fixture addon"}},
            {id="status",title={default="Fixture status",zhCN="示例只读状态"},subtitle="Ready",description="Information entries need no action."},
        },
        actions={
            inspect={title="查看详情",run=function(entry)
                state.opens=state.opens+1
                return {ok=true,view="detail",state={itemID=entry.payload.itemID}}
            end},
            ["keep-open"]={title="保持搜索打开",run=function() return {ok=true,close=false} end},
        },
        drags={move={title="Move",begin=function() state.drags=state.drags+1; return {ok=true} end}},
        views={detail={stateSchema={itemID="integer"},create=function()
            if cachedPanel then return cachedPanel end
            local panel={}
            function panel:Mount(context, initialState)
                self.context=context
                if not self.frame then
                    self.frame=CreateFrame("Frame",nil,context.contentFrame)
                    self.frame:SetAllPoints(context.contentFrame)
                    self.text=self.frame:CreateFontString(nil,"ARTWORK","GameFontHighlight")
                    self.text:SetPoint("TOPLEFT",16,-16)
                end
                self:Update(initialState)
                self.frame:Show()
            end
            function panel:Update(viewState) self.text:SetText("Item " .. tostring(viewState.itemID)) end
            function panel:Unmount() if self.frame then self.frame:Hide() end; self.context=nil end
            function panel:Dispose() self:Unmount() end
            cachedPanel=panel
            return panel
        end}},
        onEnable=function()
            state.enabled=true
            return function() state.enabled=false; if cachedPanel then cachedPanel:Unmount() end end
        end,
    })
    if not handle then state.diagnostics[err and err.code or "REGISTRATION_FAILED"]=true; return nil end
    state.committed=handle
    stopWaiting()
    return handle
end
if not attach() and not _G.Lychee and CreateFrame then
    waitingFrame=CreateFrame("Frame")
    waitingFrame:RegisterEvent("ADDON_LOADED")
    waitingFrame:SetScript("OnEvent",function(_,_,loadedName) if loadedName=="Lychee" then attach(); stopWaiting() end end)
end
_G.ThirdPartyFixture={
    TryAttach=attach,
    GetProvider=function() return state.committed end,
    GetDiagnostics=function() return state.diagnostics end,
    GetPanel=function() return cachedPanel end,
    SetEnabled=function(enabled) if state.committed then return state.committed:SetEnabled(enabled) end end,
    Unregister=function()
        stopWaiting()
        if not state.committed then return true end
        local result=state.committed:Unregister()
        if result then state.committed=nil end
        return result
    end,
}
