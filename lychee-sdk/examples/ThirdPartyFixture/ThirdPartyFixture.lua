-- Public API 2.2 integration. Lychee is optional; no Host internals are accessed.
local state = { committed=nil, enabled=false, diagnostics={}, opens=0, drags=0 }
local waitingFrame, cachedPanel
-- One reusable structure belongs to this Provider; each mount owns its binding.
local function releasePanel(panel)
    panel.active=false
    panel.context=nil
    if panel.frame then panel.frame:Hide() end
end
local function stopWaiting()
    if waitingFrame then waitingFrame:UnregisterAllEvents(); waitingFrame:SetScript("OnEvent", nil) end
end
local function attach()
    if state.committed then return state.committed end
    local SDK = _G.Lychee
    if not SDK or not SDK.Supports then return nil end
    if not SDK:Supports(2, 2) then state.diagnostics.UNSUPPORTED_API=true; stopWaiting(); return nil end
    local handle, err = SDK:RegisterProvider({
        id="third-party-fixture", apiVersion=2, minApiRevision=2, version="2.2.0",
        scope={products={"retail","classic","titan","anniversary"}},
        i18n={
            enUS={PROVIDER="Third-party fixture",ENTRY="Fixture entry",KIND="Example",DESCRIPTION="An ordinary addon entry with independent interactions.",ALIASES="fixture demo",STATUS="Fixture status",READY="Ready",INFO="Information entries need no action.",INSPECT="View details",KEEP="Keep search open",MOVE="Move",ITEM="Item %d"},
            zhCN={PROVIDER="第三方示例",ENTRY="第三方示例条目",KIND="示例",DESCRIPTION="具有独立交互的插件条目。",ALIASES="示例",STATUS="示例只读状态",READY="已就绪",INFO="信息条目不需要动作。",INSPECT="查看详情",KEEP="保持搜索打开",MOVE="移动",ITEM="物品 %d"},
        },
        title={key="PROVIDER"},
        entries={
            {id="fixture-item-12345",title={key="ENTRY"},
                kindTitle={key="KIND"},description={key="DESCRIPTION"},
                aliases={{key="ALIASES"},"fixture demo"},payload={itemID=12345},actions={"inspect","keep-open"},
                drag={type="provider",handler="move"}},
            {id="status",title={key="STATUS"},subtitle={key="READY"},description={key="INFO"}},
        },
        actions={
            inspect={title={key="INSPECT"},run=function(entry)
                state.opens=state.opens+1
                return {ok=true,view="detail",state={itemID=entry.payload.itemID}}
            end},
            ["keep-open"]={title={key="KEEP"},run=function() return {ok=true,close=false} end},
        },
        drags={move={title={key="MOVE"},begin=function() state.drags=state.drags+1; return {ok=true} end}},
        views={detail={stateSchema={itemID="integer"},create=function()
            if cachedPanel then return cachedPanel end
            local panel={}
            function panel:Mount(context, initialState)
                if not self.frame then
                    self.frame=CreateFrame("Frame",nil,context.contentFrame)
                end
                if self.parent~=context.contentFrame then
                    self.parent=nil -- Partial reparent/layout failure invalidates the old binding too.
                    self.frame:SetParent(context.contentFrame)
                    self.frame:ClearAllPoints()
                    self.frame:SetAllPoints(context.contentFrame)
                    self.parent=context.contentFrame -- Publish only after setters succeed.
                end
                if not self.text then
                    self.text=self.frame:CreateFontString(nil,"ARTWORK","GameFontHighlight")
                end
                if not self.textReady then
                    self.text:SetPoint("TOPLEFT",16,-16)
                    self.textReady=true
                end
                self.context,self.active=context,true
                self:Update(initialState)
                self.frame:Show()
            end
            function panel:Update(viewState)
                if self.active then self.text:SetText(state.committed:Text("ITEM",viewState.itemID)) end
            end
            function panel:Unmount() releasePanel(self) end
            function panel:Dispose() releasePanel(self) end
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
