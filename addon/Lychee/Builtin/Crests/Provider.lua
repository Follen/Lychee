local I = _G.LycheeInternal
local L = I.ProviderLocales:Builtin("builtin.crests")
local M = {}
I.Builtin.Crests = M

-- CurrencyTypes, retail 12.1.0.69587, zhCN. Real wallet currencies (category 282),
-- not the similarly named item/display currencies 3437-3441.
local currencies = {
    { id=3446, name="神话迷雾纹章", icon=7734060 },
    { id=3445, name="英雄迷雾纹章", icon=7734058 },
    { id=3444, name="勇士迷雾纹章", icon=7734056 },
    { id=3443, name="老兵迷雾纹章", icon=7734062 },
    { id=3442, name="冒险者迷雾纹章", icon=7734054 },
}
local cachedPanel

local function createPanel()
    if cachedPanel then return cachedPanel end
    local panel = { rows={}, byID={} }
    function panel:Refresh(currencyID)
        if not self.active then return end
        for index = 1, #currencies do
            local currency, row = currencies[index], self.rows[index]
            if not currencyID or currencyID == currency.id then
                local ok, info = false, nil
                if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                    ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currency.id)
                end
                local name = ok and info and info.name or (I.Locale:IsChinese() and currency.name or L:Format("货币 %d",currency.id))
                local quantity = ok and info and info.quantity or nil
                local icon = ok and info and info.iconFileID or currency.icon
                if name == "" then name = I.Locale:IsChinese() and currency.name or L:Format("货币 %d",currency.id) end
                if not icon or icon == 0 then icon = currency.icon end
                local text = quantity ~= nil and tostring(quantity) or "—"
                if row.appliedName ~= name then row.name:SetText(name); row.appliedName=name end
                if row.appliedQuantity ~= text then row.quantity:SetText(text); row.appliedQuantity=text end
                if row.appliedIcon ~= icon then row.icon:SetTexture(icon); row.appliedIcon=icon end
            end
        end
    end
    function panel:Mount(context)
        local Theme = _G.Lychee.UI.Theme
        if not self.frame then
            self.frame = CreateFrame("Frame", nil, context.contentFrame)
            self.frame:SetAllPoints(context.contentFrame)
            self.parent = context.contentFrame
            local heading = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            heading:SetPoint("TOPLEFT", 20, -14)
            Theme:SetFont(heading, "title"); Theme:SetTextColor(heading, "text")
            heading:SetText(L["纹章"])
            local subtitle = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            subtitle:SetPoint("TOPRIGHT", -20, -16)
            Theme:SetFont(subtitle, "meta"); Theme:SetTextColor(subtitle, "textDim")
            subtitle:SetText(L["当前角色 · 迷雾纹章"])
            for index = 1, #currencies do
                local row = CreateFrame("Frame", nil, self.frame)
                row:SetPoint("TOPLEFT", 20, -44 - (index - 1) * 52)
                row:SetPoint("TOPRIGHT", -20, -44 - (index - 1) * 52)
                row:SetHeight(48)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetPoint("LEFT", 0, 0); row.icon:SetSize(32, 32)
                row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                row.quantity = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.quantity:SetPoint("RIGHT", -4, 0); row.quantity:SetWidth(100); row.quantity:SetJustifyH("RIGHT")
                Theme:SetFont(row.quantity, "title"); Theme:SetTextColor(row.quantity, "text")
                row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 14, 0)
                row.name:SetPoint("RIGHT", row.quantity, "LEFT", -12, 0); row.name:SetJustifyH("LEFT")
                Theme:SetFont(row.name, "body"); Theme:SetTextColor(row.name, "textMuted")
                self.rows[index], self.byID[currencies[index].id] = row, row
            end
            self.frame:SetScript("OnEvent", function(_, _, currencyID)
                if not currencyID or self.byID[currencyID] then self:Refresh(currencyID) end
            end)
            self.frame:SetScript("OnShow", function()
                if self.active then self.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE"); self:Refresh() end
            end)
            self.frame:SetScript("OnHide", function() self.frame:UnregisterAllEvents() end)
        elseif self.parent ~= context.contentFrame then
            self.frame:SetParent(context.contentFrame)
            self.frame:ClearAllPoints(); self.frame:SetAllPoints(context.contentFrame)
            self.parent = context.contentFrame
        end
        self.active = true
        if self.frame:IsShown() then
            self.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
            self:Refresh()
        else
            self.frame:Show()
        end
    end
    function panel:Update() self:Refresh() end
    function panel:Unmount()
        self.active = false
        if self.frame then self.frame:UnregisterAllEvents(); self.frame:Hide() end
    end
    function panel:Dispose() self:Unmount() end
    cachedPanel = panel
    return panel
end

function M:Init()
    if self.handle then return true end
    local handle, err = _G.Lychee:RegisterProvider({
        id="builtin.crests", apiVersion="1.0.0",i18n=L.resources, version="1.0.0", title=L["纹章"], scope=I.Builtin.Support:Scope("builtin.crests"),
        entries={{ id="crests", title=L["纹章"], kindTitle=L["角色货币"], icon=7734060,
            subtitle=L["查看当前角色的迷雾纹章数量"], aliases={"神话", "英雄", "勇士", "老兵", "冒险者", "迷雾", "crest", "crests", "纹章数量",
                "神话迷雾纹章", "迷雾神话纹章", "英雄迷雾纹章", "勇士迷雾纹章", "老兵迷雾纹章", "冒险者迷雾纹章"}, actions={"open"} }},
        actions={open={title=L["查看纹章"],run=function() return {ok=true, view="balances", state={}} end}},
        views={balances={stateSchema={}, create=createPanel}},
        onEnable=function() return function(reason)
            if cachedPanel then cachedPanel:Unmount() end
            if reason == "unregister" then M.handle=nil end
        end end,
    })
    self.handle = handle
    return handle ~= nil, err
end
