local L = _G.LycheeInternal.Locale
local I = _G.LycheeInternal
local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

_G.BINDING_HEADER_LYCHEE = L.name
_G.BINDING_NAME_TOGGLELYCHEE = L["打开/关闭启动器"]

local Palette = {}
Palette.__index = Palette

local WIDTH, HEIGHT = 640, 220
local HEADER_HEIGHT, FOOTER_HEIGHT = Lychee.UI.Theme.Metrics.headerHeight or 56, Lychee.UI.Theme.Metrics.footerHeight or 32
local LIST_METRICS = Lychee.UI.Theme.Metrics

local function localized(value, fallback) return L:Resolve(value, fallback) end

local function setShown(object, shown)
    if object and object.IsShown and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function setText(fontString, text)
    text = text or ""
    if fontString and fontString.GetText and fontString:GetText() ~= text then fontString:SetText(text) end
end


function Palette:ApplyBoundedScale()
    if not self.frame or not self.frame.SetScale then return end
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end
    local scale = math.min(LIST_METRICS.uiScale, (parentWidth - 48) / WIDTH, (parentHeight - 48) / 600)
    if self._scale ~= scale then self.frame:SetScale(scale); self._scale = scale; Lychee.UI.Theme.scale=scale end
    local inset = math.max(24, (parentHeight - 600 * scale) / 2)
    self._presenceSpec.y = -inset / scale
    if self._topInset ~= inset then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, -inset / scale)
        self._topInset = inset
    end
end

function Palette:Create()
    if self.frame then return self end
    if InCombatLockdown and InCombatLockdown() then return self end
    local frame = CreateFrame("Frame", "LycheePalette", UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOP", UIParent, "CENTER", 0, 180)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    -- A window is one rigid surface. Do not clip a separately anchored content
    -- tree against an animated shell: native clipping can erase the whole tree.
    Lychee.UI.Theme:CreateRoundedSurface(frame, "window", 10)
    Lychee.UI.Motion:ConfigurePresence(self, {point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=0})
    frame:Hide()
    -- Only the secure snippet hides a protected hierarchy during combat. The
    -- non-combat state deliberately does nothing, so leaving combat never opens it.
    frame:SetAttribute("_onstate-combat", [[if newstate == "hide" then local escape=self:GetFrameRef("escape"); if escape then escape:Hide() end; self:Hide() end]])
    if RegisterStateDriver then RegisterStateDriver(frame, "combat", "[combat] hide; idle") end
    frame:SetScript("OnHide", function()
        if Lychee.UI.Motion then Lychee.UI.Motion:StopAll() end
        if self.visible then self:Hide("external")
        elseif InCombatLockdown and InCombatLockdown() then self.combatCleanupPending=true end
    end)
    -- CloseSpecialWindows hides registered frames synchronously. Give it a
    -- non-rendering child so lost-focus Escape follows the same animated close
    -- as the EditBox, without replacing native dispatch or watching every key.
    self.escapeFrame=CreateFrame("Frame","LycheePaletteEscape",frame)
    self.escapeFrame:Hide()
    if SecureHandlerSetFrameRef then SecureHandlerSetFrameRef(frame,"escape",self.escapeFrame) end
    self.escapeFrame:SetScript("OnHide",function()
        if self.visible and frame:IsShown() and not (InCombatLockdown and InCombatLockdown()) then self:Hide("escape") end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "LycheePaletteEscape") end
    self.frame = frame
    self.session, self.generation, self.visible = 0, 0, false
    local components = Lychee.UI.Components
    self.headerComponent = components:CreateBand(frame, { height = HEADER_HEIGHT, top = true, color = "header" })
    self.header = self.headerComponent.frame
    self.headerComponent.bg:Hide()
    self.footerComponent = components:CreateBand(frame, { height = FOOTER_HEIGHT, top = false, color = "footer" })
    self.footer = self.footerComponent.frame
    self.footerComponent.bg:Hide()
    self.contentComponent = components:CreateSurface(frame, { allPoints = false, color = "content" })
    self.content = self.contentComponent.frame
    if self.content.SetClipsChildren then self.content:SetClipsChildren(true) end
    self.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_HEIGHT)
    self.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, FOOTER_HEIGHT)
    self.content.bg = self.contentComponent.bg
    self.content.bg:Hide()
    self.brandComponent = components:CreateBrand(self.header, {
        iconSize = 42,
        texture = "Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga",
        point = "LEFT",
        x = 14,
    })
    self.brandMark = self.brandComponent.icon
    self.brand = self.brandComponent.label
    self.settingsButton = CreateFrame("Button", nil, self.header)
    self.settingsButton:SetAllPoints(self.brandComponent.frame)
    self.settingsButton:SetScript("OnClick", function() self:OpenSettings() end)
    self.settingsButton:SetScript("OnEnter", function()
        if self.visible then self.brandComponent:PlayMotion() end
    end)
    self.settingsTitle = self.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.settingsTitle:SetPoint("LEFT", self.header, "LEFT", 82, 0)
    Lychee.UI.Theme:SetFont(self.settingsTitle, "body")
    Lychee.UI.Theme:SetTextColor(self.settingsTitle, "text")
    self.settingsTitle:SetText(L["荔枝设置"]); self.settingsTitle:Hide()
    self.settingsBack = components:CreateNavigationButton(self.header, {
        width = 90, height = 28, point = "RIGHT", relativePoint = "RIGHT", x = -66,
        text = L["返回搜索"],
        onClick = function() self:CloseSettings() end,
    })
    local backLabel = self.settingsBack.label
    Lychee.UI.Theme:SetFont(backLabel, "body")
    backLabel:ClearAllPoints()
    backLabel:SetPoint("LEFT", self.settingsBack.frame, "LEFT", 26, 0)
    backLabel:SetPoint("RIGHT", self.settingsBack.frame, "RIGHT", -10, 0)
    backLabel:SetJustifyH("LEFT")
    self.settingsBack.strokes = {}
    for direction = -1, 1, 2 do
        local stroke = self.settingsBack.frame:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(6, 1.25)
        stroke:SetPoint("CENTER", self.settingsBack.frame, "LEFT", 13, direction * 1.9)
        Lychee.UI.Theme:SetColorTexture(stroke, "textMuted")
        stroke:SetRotation(direction * math.pi / 4)
        self.settingsBack.strokes[#self.settingsBack.strokes + 1] = stroke
    end
    self.settingsBack.frame:Hide()
    self.closeComponent = components:CreateButton(self.header, {
        width = 38, height = 26, point = "RIGHT", relativePoint = "RIGHT", x = -16,
        text = "Esc",
        colors = { normal = "transparent" },
        textColors = { normal = "accent", hover = "accentHover", pressed = "accentHover" },
        onClick = function() self:Hide("close") end,
    })
    self.close = self.closeComponent.frame
    Lychee.UI.Theme:SetFont(self.closeComponent.label, "body")
    self.statusComponent = components:CreateStatus(self.footer, { textColor = "textMuted", left=LIST_METRICS.footerInset, right=LIST_METRICS.footerInset })
    self.status = self.statusComponent.label
    Lychee.UI.Theme:SetFont(self.status, "meta")
    self.footerHint = self.footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.footerHint:SetPoint("RIGHT", self.footer, "RIGHT", -LIST_METRICS.footerInset, 0)
    Lychee.UI.Theme:SetTextColor(self.footerHint, Lychee.UI.Theme:GetColor("textMuted"))
    Lychee.UI.Theme:SetFont(self.footerHint, "meta")


    self.emptyStateComponent = components:CreateEmptyState(self.content, {
        title = L["没有找到结果"],
        detail = "",
        titleColor = "text", detailColor = "textMuted", shown = false,
    })
    self.emptyState = self.emptyStateComponent.frame

    self.focus = Lychee.UI.FocusController:New()
    self.input = Lychee.UI.Input:Create(self.header, self.focus)
    self.list = Lychee.UI.ResultList:Create(self.content, self)
    self.homeView = Lychee.UI.HomeView:Create(self.content, self)
    self.homeView:SetSections({})
    self.onHomeSelect = function(section, tile)
        if section and section.item and tile then self:ActivateRow(tile)
        elseif section and section.filter then self:ActivateHomeFilter(section.filter)
        elseif section and section.query then self.input:SetText(section.query)
        elseif section and section.id and self.onHomeCategory then self.onHomeCategory(section.id) end
    end
    self.viewHost = Lychee.UI.ViewHost:Create(self.content)
    self.input:SetChangedCallback(function(text)
        self.activeFilter = nil
        if self.onQuery then self.onQuery(text) end
        self:SetQueryMode(text)
    end)
    self.input:SetSubmitCallback(function()
        if I.Search.Normalizer:IsBlank(self.input:GetText()) then self.homeView:ActivateSelected() else self:ActivateSelected() end
    end)
    self.input:SetMoveCallback(function(delta)
        if I.Search.Normalizer:IsBlank(self.input:GetText()) then self.homeView:Move(delta) else self.list:Move(delta) end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" and self.visible then
            self:Hide("combat")
        elseif event == "PLAYER_REGEN_ENABLED" and self.combatCleanupPending then
            self:FinishHide("combat")
        elseif event == "GLOBAL_MOUSE_DOWN" then
            local menu = self.actionMenu
            if menu and menu.IsShown and menu:IsShown() and menu.IsMouseOver and menu:IsMouseOver() then return end
            self.actionMenu = nil
            -- EditBox 的键盘焦点不会因点击游戏世界自动释放；沿用 Blizzard
            -- ColorPickerFrame 的外部点击判定（事件在 Show 注册、Hide 注销），
            -- 把键盘还给游戏而不吞掉这次点击。focused 标记可能与真实键盘
            -- 焦点失步，用 GetCurrentKeyBoardFocus 复核；IsMouseOver 按矩形
            -- 判定，点击面板上的非鼠标区域时不会误清焦点。
            local focused = self.input.focused
                or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() == self.input.frame)
            if self.visible and focused and not self.frame:IsMouseOver() then
                self.input:ClearFocus()
            end
        end
    end)

    local internal = _G.LycheeInternal
    if internal then
        internal.Host = internal.Host or {}
        internal.Host.PaletteController = self
        local broker = internal.Host.SecureBroker
        if broker and broker.BindPalette then broker:BindPalette(self) end
        if internal.Registry and internal.Registry.OnChange and not internal._paletteLifecycleWired then
            internal._paletteLifecycleWired = true
            internal.Registry:OnChange(function(entry, state)
                if state == "disabled" or state == "retiring" or state == "removed" then self:InvalidateExtension(entry and entry.id) end
                self:MarkHomeDirty()
                if self.settingsOpen and C_Timer and C_Timer.After and not self.settingsRefreshPending then
                    self.settingsRefreshPending = true
                    C_Timer.After(0, function()
                        self.settingsRefreshPending = nil
                        if self.visible and self.settingsOpen then self.settingsView:Refresh() end
                    end)
                end
            end)
        end
        if not internal.Host.ClosePalette then internal.Host.ClosePalette = function(reason) return self:Hide(reason) end end
        if not internal.Host.TogglePalette then internal.Host.TogglePalette = function() return self:Toggle() end end
        if internal.WirePalette then internal.WirePalette(self) end
    end
    return self
end

function Palette:SetStatusText(value)
    setText(self.status, value); setText(self.footerHint, "")
end

function Palette:OpenSettings(tab)
    if self._motionClosing then return false end
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    self._motionMode="settings"
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if not self.visible then self:Show() end
    self.settingsOpen = true
    if I.Search.Session then I.Search.Session:Stop("settings") end
    Lychee.UI.ResultList:HideTooltip()
    if self.secureBroker then self.secureBroker:ReleaseAll(); self._searchActionsSuspended = true end
    if self.viewHost then self.viewHost:Unmount("settings") end
    self.input:ClearFocus(); self.input:Hide()
    setShown(self.homeView.frame, false); setShown(self.list.frame, false); setShown(self.emptyState, false)
    if not self.settingsView then self.settingsView = Lychee.UI.SettingsView:Create(self.content, self) end
    self.settingsView.frame:Show(); self.settingsView:SetTab(tab or "providers")
    if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(self.settingsView.frame,"page") end
    self.settingsTitle:Show(); self.settingsBack.frame:Show()
    self:ResizeForMode("settings"); self:SetStatusText(L["更改即时生效"])
    return true
end

function Palette:CloseSettings(clearQuery)
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    self.settingsOpen = false
    if self.settingsView then self.settingsView.frame:Hide() end
    self.settingsTitle:Hide(); self.settingsBack.frame:Hide(); self.input:Show()
    if I.Search.Session then I.Search.Session:Start() end
    if clearQuery then self.input:SetText("") end
    if self.onQuery then self.onQuery(self.input:GetText()) end
    self:EnsureHomeCapacity(); self:SetQueryMode(self.input:GetText()); self.input:Focus()
    return true
end

function Palette:SetQueryCallback(callback) self.onQuery = callback end
function Palette:SetActivateCallback(callback) self.onActivate = callback end
function Palette:SetDragCallback(callback) self.onDrag = callback end
function Palette:SetHomeSections(sections, allowExpand)
    if self.homeView then self.homeView:SetSections(sections or {}, allowExpand) end
end
function Palette:SetHomeCategoryCallback(callback) self.onHomeCategory = callback end

function Palette:IsHomeVisible()
    return self.visible and not self.settingsOpen and self.homeView and self.homeView.frame:IsShown()
        and not (self.viewHost and self.viewHost:IsActive())
end

function Palette:EnsureHomeCapacity()
    return self.homeView and self.homeView:EnsureSavedCapacity() or false
end

function Palette:MarkHomeDirty()
    if not self.homeView then return false end
    self.homeView:Invalidate()
    if InCombatLockdown and InCombatLockdown() then return false end
    if self:IsHomeVisible() then return self:PrepareHome() end
    return true
end

function Palette:TouchRecent(item)
    if not I.UserPreferences:TouchRecent(item) then return false end
    if I.Search.Personalization and self.input and not self.settingsOpen then
        I.Search.Personalization:Remember(self.input:GetText(), item)
    end
    return self:MarkHomeDirty()
end

function Palette:SetPinned(item, pinned)
    local preferences = I.UserPreferences
    if not preferences or not item then return false end
    if pinned then
        local ok, err = preferences:Pin(item)
        if not ok then return false, err end
    else
        local index = preferences:PinIndex(item.ref)
        if index then preferences:Remove(index) end
    end
    self:EnsureHomeCapacity(); self:MarkHomeDirty()
    if self.settingsOpen then self.settingsView:Refresh() end
    return true
end

function Palette:RefreshHomeSections(allowExpand)
    if not self.homeView then return false end
    self.homeView:Invalidate()
    return self:PrepareHome(allowExpand)
end

function Palette:PrepareHome(allowExpand)
    if not self.visible or not self.homeView then return false end
    local prepared = self.homeView:Prepare(self.session, self.generation, allowExpand)
    if prepared and self:IsHomeVisible() then self:ResizeForMode("home") end
    return prepared
end

function Palette:ActivateHomeFilter(filter)
    if type(filter) ~= "table" then return false, "INVALID_FILTER" end
    self.activeFilter = { categoryID = filter.categoryID, sourceID = filter.sourceID }
    self:SetQueryMode("")
    local session = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if not session or type(session.Filter) ~= "function" then return false, "SEARCH_UNAVAILABLE" end
    local ok, generation = session:Filter(self.activeFilter)
    if not ok then self.activeFilter = nil; self:SetQueryMode("") end
    return ok, generation
end

function Palette:SetStatus(mode, count)
    local text
    if mode == "home" then
        local preferences = I.UserPreferences
        text = preferences and preferences:GetRecoveryError() and L["固定项数据异常，原始存档已保留"] or L["输入即搜索"]
    elseif mode == "panel" then text = L["详情"]
    elseif count and count > 0 then text = L["搜索结果："] .. tostring(count)
    else text = L["没有结果"] end
    local panel=mode=="panel" and self.viewHost and self.viewHost.panel
    if panel and panel.footerHint~=nil then
        setText(self.status, "");setText(self.footerHint,panel.footerHint)
    else
        setText(self.status, text)
        setText(self.footerHint, mode == "home" and "" or L["↑ ↓ 选择   ·   点击使用"])
    end
end

function Palette:ResizeForMode(mode, count)
    if mode=="search" and self.searchPending and (tonumber(count) or 0)==0 then return true end
    if not self.frame or not self.frame.SetHeight then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local theme = Lychee.UI and Lychee.UI.Theme
    local metrics = theme and theme.Metrics or {}
    local minHeight = metrics.paletteMinHeight or 220
    local maxHeight = metrics.paletteMaxHeight or HEIGHT
    local rowHeight = metrics.rowHeight or 56
    local rowGap = metrics.rowGap or 4
    local padding = metrics.resultPadding or 20
    local tiles = math.max(0, math.min(tonumber(count) or 0, self.list and self.list.maxRows or 12))
    local columns = self.list and self.list.gridColumns or 4
    local rows = tiles > 0 and math.ceil(tiles / columns) or 0
    local listHeight = rows > 0 and (rows * rowHeight + (rows - 1) * rowGap) or 0
    if mode == "home" then
        listHeight = self.homeView and self.homeView:GetContentHeight() or 0
        padding = 0 -- Home content includes its own top and bottom spacing.
    end
    if mode == "panel" then
        if count then listHeight=math.max(0,tonumber(count) or 0);padding=0 else listHeight=360 end
    end
    if mode == "settings" then listHeight = metrics.resultTiles * rowHeight + (metrics.resultTiles - 1) * rowGap end
    if mode == "settings-detail" then listHeight = math.max(0,tonumber(count) or 0) end
    local desired = HEADER_HEIGHT + FOOTER_HEIGHT + padding + listHeight
    desired = math.max(minHeight, math.min(maxHeight, desired))
    local growOnly=mode=="search" and self.searchPending
    if Lychee.UI.Motion then
        Lychee.UI.Motion:Height(self.frame,desired,growOnly)
    elseif self.frame:GetHeight()~=desired and (not growOnly or desired>self.frame:GetHeight()) then
        self.frame:SetHeight(desired)
    end
    self:ApplyBoundedScale()
    return true
end

function Palette:ReportActionResult(result, err)
    local ok = result == true or (type(result) == "table" and result.ok == true)
    if ok then
        if type(result) == "table" and result.awaitingHardwareClick then
            local title = type(result.actionTitle) == "string" and (" · " .. result.actionTitle) or ""
            setText(self.status, L["点击施放"] .. title)
            return true
        end
        setText(self.status, "")
        return true
    end
    local code = type(err) == "table" and err.code or err
    if code == "NO_ACTION" then setText(self.status, ""); return false end
    if type(err) == "table" and type(err.message) == "string" and err.message ~= "" then setText(self.status, err.message); return false end
    local labels = {
        COMBAT_LOCKED = L["战斗中不可用"],
        ACTION_UNAVAILABLE = L["当前不可用"],
        ACTION_REQUIRES_HARDWARE_CLICK = L["请点击施放"],
        HANDLER_UNAVAILABLE = L["功能暂不可用"],
        DRAG_UNSUPPORTED = L["不支持拖动"],
    }
    local text = labels[code]
    setText(self.status, localized(text or L["执行失败"], "Action failed"))
    return false
end

function Palette:SetActionFeedback(state, actionOrError)
    local title = type(actionOrError) == "table" and (actionOrError.title or actionOrError.label) or nil
    if state == "pending" then
        setText(self.status, "")
    elseif state == "success" then
        setText(self.status, "")
    else
        self:ReportActionResult(false, type(actionOrError) == "string" and actionOrError or nil)
    end
    return true
end

function Palette:SetQueryMode(text)
    if self.settingsOpen then return false end
    if not self.visible or (InCombatLockdown and InCombatLockdown()) then return false end
    self._navigationRevision = (self._navigationRevision or 0) + 1
    if self._openingView then self.viewHost:Unmount("query-navigation") end
    local empty = I.Search.Normalizer:IsBlank(text)
    local nextMode=empty and not self.activeFilter and "home" or "search"
    local changedMode=self._motionMode~=nextMode
    if changedMode and Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    self._motionMode=nextMode
    if not self.homeView or not self.list then return end
    if self.viewHost and self.viewHost:IsActive() then self.viewHost:Unmount("query-change") end
    setShown(self.viewHost and self.viewHost.frame, false)
    if empty and not self.activeFilter then
        setShown(self.list.frame, false); setShown(self.emptyState, false)
        setShown(self.homeView.frame, true); self:PrepareHome(); self:SetStatus("home")
    else
        self:ResizeForMode("search", self.list.items and #self.list.items or 0)
        setShown(self.homeView.frame, false)
        local hasItems = self.list.items and #self.list.items > 0
        setShown(self.list.frame, hasItems)
        setShown(self.emptyState, not hasItems and not self.searchPending)
        if hasItems and self._searchActionsSuspended and I.ResultActionExecutor then
            I.ResultActionExecutor:PrepareVisibleRows(self.list.rows)
            self._searchActionsSuspended = nil
        end
        if self.searchPending then self:SetStatusText(L["搜索中…"]) else self:SetStatus("search", hasItems and #self.list.items or 0) end
    end
    if changedMode and Lychee.UI.Motion then Lychee.UI.Motion:Reveal(nextMode=="home" and self.homeView.frame or self.list.frame,"page") end
end

function Palette:IsRowCurrent(row, session, generation, item, extensionID)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "STALE_GENERATION" end
    return executor:IsRowCurrent(row, session, generation, item, extensionID)
end
function Palette:ValidateRowAction(row, session, generation, item, extensionID, preparing)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "STALE_GENERATION" end
    return executor:Validate(row, session, generation, item, extensionID, preparing)
end
function Palette:InvalidateRow(row)
    Lychee.UI.ResultList:HideTooltip()
    if self.secureBroker and self.secureBroker.InvalidateRow then self.secureBroker:InvalidateRow(row) end
    if InCombatLockdown and InCombatLockdown() then self.homeView:Invalidate(); return end
    if self.homeView and self.homeView:InvalidateRow(row) then return end
    if self.list and self.list.InvalidateRow then self.list:InvalidateRow(row) end
end
function Palette:RejectRow(row, err)
    if err == "STALE_GENERATION" or err == "EXTENSION_DISABLED" then self:InvalidateRow(row) end
    self:ReportActionResult(false, err)
    return false, err
end
function Palette:InvalidateExtension(extensionID)
    if not extensionID then return false end
    if InCombatLockdown and InCombatLockdown() then self.homeView:Invalidate(); return false end
    if self.viewHost and self.viewHost:IsOwnedBy(extensionID) then
        self.viewHost:Unmount("extension-disabled")
    end
    if not self.list then return true end
    for index = 1, #self.list.rows do if self.list.rows[index].extensionID == extensionID then self:InvalidateRow(self.list.rows[index]) end end
    return true
end

-- SearchSession is the sole publisher. Scrolling only re-renders the already
-- accepted list and never rewrites the query's identity or waiting state.
function Palette:ApplySearchState(session, generation, pending, items)
    self.session, self.generation, self.searchPending = session, generation, pending == true
    if items then return self:ApplyResults(items, generation, session) end
    return true
end

function Palette:ApplyResults(items, generation, session, offset)
    if self.settingsOpen then return false end
    if not self.visible then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if session and session ~= self.session then return false end
    if generation and generation ~= self.generation then return false end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    items = items or {}
    self.list:SetItems(items, self.session, self.generation, offset)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if executor and not (self.viewHost and self.viewHost:IsActive()) then
        executor:PrepareVisibleRows(self.list.rows); self._searchActionsSuspended = nil
    else self._searchActionsSuspended = true end
    if self.viewHost and self.viewHost:IsActive() then
        setShown(self.homeView.frame, false); setShown(self.list.frame, false); setShown(self.emptyState, false)
        setShown(self.viewHost.frame, true); self:SetStatus("panel")
    elseif not I.Search.Normalizer:IsBlank(self.input:GetText()) or self.activeFilter then
        self:ResizeForMode("search", #items)
        setShown(self.homeView.frame, false); setShown(self.list.frame, #items > 0); setShown(self.emptyState, #items == 0 and not self.searchPending)
        if self.searchPending then self:SetStatusText(L["搜索中…"]) else self:SetStatus("search", #items) end
    elseif self:IsHomeVisible() then
        self:PrepareHome()
    end
    return true
end
function Palette:SetResults(items, generation, session)
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then return searchSession:_Accept(items, generation or searchSession.generation, session or searchSession.session) end
    return self:ApplyResults(items, generation, session)
end

function Palette:Show()
    if I.NotifyPaletteVisibility then I.NotifyPaletteVisibility(true) end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self.visible then return true end
    self:Create()
    local motion,initialPhase=Lychee.UI.Motion,nil
    if self._motionClosing and motion then
        initialPhase=motion:StopPresence(false)
    end
    if self._motionClosing then self:FinishHide("reopen") end
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll();self.frame:SetAlpha(1) end
    self._motionClosing=nil
    if self.combatCleanupPending then self:FinishHide("combat") end
    self.input:SetEnabled(true)
    self.input:SetVisualFrozen(false)
    self.input:SetText("")
    self:ApplyBoundedScale()
    self.visible = true
    self.frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self:ResizeForMode("home")
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Start() end
    if I.Search.Normalizer:IsBlank(self.input:GetText()) and not self.activeFilter then self:RefreshHomeSections(true) end
    self.frame:Show(); self.input:SetText(self.input:GetText()); self:SetQueryMode(self.input:GetText()); self.input:Show()
    if self.escapeFrame then self.escapeFrame:Show() end
    if motion then motion:Presence(self.frame,true,nil,initialPhase,self) end
    self.brandComponent:PlayMotion()
    -- Defer focus one frame: the keystroke that opened the palette (e.g. the space
    -- in ALT-SPACE) delivers its character to whichever EditBox is focused during
    -- the same input dispatch; focusing synchronously would swallow it as query text.
    if C_Timer and type(C_Timer.After) == "function" then
        local focusSession = self.session
        C_Timer.After(0, function()
            if self.visible and not self.settingsOpen and self.session == focusSession then self.input:Focus() end
        end)
    else
        self.input:Focus()
    end
    return true
end
function Palette:Hide(reason)
    if self._motionClosing and not self.visible and not (InCombatLockdown and InCombatLockdown()) then return true end
    Lychee.UI.ResultList:HideTooltip()
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    -- Invalidate the session only after marking the UI inactive; a synchronous
    -- result callback must not repaint a protected row on combat entry.
    self.visible = false
    if I.NotifyPaletteVisibility then I.NotifyPaletteVisibility(false) end
    self.searchPending=false
    self.actionMenu = nil
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Stop(reason or "hide") end
    if not self.frame then return true end
    self.frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self.activeFilter = nil
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.input:SetVisualFrozen(true)
    self.input:ClearFocus()
    self.input:SetEnabled(false)
    if InCombatLockdown and InCombatLockdown() then
        self.combatCleanupPending = true
        return true
    end
    if self.escapeFrame then self.escapeFrame:Hide() end
    local motion=Lychee.UI.Motion
    if motion and self.frame:IsShown() and not motion:IsReduced() and self.frame.CreateAnimationGroup then
        self._motionClosing=true
        motion:Presence(self.frame,false,function()
            if self._motionClosing and not self.visible then self._motionClosing=nil;self:FinishHide(reason) end
        end,nil,self)
        return true
    end
    return self:FinishHide(reason)
end

function Palette:FinishHide(reason)
    if InCombatLockdown and InCombatLockdown() then return false end
    self.combatCleanupPending = false
    self._motionClosing=nil
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll() end
    self.settingsOpen = false
    if self.settingsView then self.settingsView.frame:Hide() end
    self.settingsTitle:Hide(); self.settingsBack.frame:Hide()
    self.list:Clear(); setShown(self.emptyState, false)
    if self.viewHost then self.viewHost:Unmount(reason or "hide") end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    if reason == "combat" then self.focus:Clear(); self.focus.previous = nil else self.focus:Restore() end
    self.input:ClearFocus(); self.input:Hide()
    self.frame:Hide()
    if self.homeView then self.homeView:ReleaseBindings() end
    return true
end
function Palette:Toggle()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self.visible then return self:Hide("toggle") end
    return self:Show()
end
function Palette:ActivateRow(row)
    local valid, err = self:IsRowCurrent(row)
    if not valid then return self:RejectRow(row, err) end
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "ACTION_UNAVAILABLE" end
    local result, actionErr = executor:ExecutePrimary(row)
    self:ReportActionResult(result, actionErr)
    return result, actionErr
end
function Palette:ActivateSelected() return self.list:ActivateSelected() end
function Palette:ActivateRowAction(row, actionID)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "ACTION_UNAVAILABLE" end
    local result, err = executor:Execute(row, actionID)
    self:ReportActionResult(result, err)
    return result, err
end
function Palette:ShowRowActions(row)
    Lychee.UI.ResultList:HideTooltip()
    if row and not row.item and row.section and row.section.pinnedRef and MenuUtil and MenuUtil.CreateContextMenu then
        if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
        local pin = row.section.pinnedRef
        Lychee.UI.Components:StyleActionMenuOwner(row)
        self.actionMenu = MenuUtil.CreateContextMenu(row, function(_, root)
            local description = root:CreateButton(L["取消固定"], function()
                if not self.visible or self.settingsOpen or InCombatLockdown() then return false end
                for index, current in ipairs(I.UserPreferences:GetPins()) do
                    if current == pin then I.UserPreferences:Remove(index); self:MarkHomeDirty(); return true end
                end
            end)
            Lychee.UI.Components:StyleActionMenuButton(description)
        end)
        return true
    end
    local result, err = I.ResultActionExecutor:ShowActions(row)
    self:ReportActionResult(result, err)
    return result, err
end
function Palette:EditAlias(item)
    if not I.UserPreferences:CanPin(item) then return false end
    local ref,title=item.ref,item.text
    if not self:OpenSettings("general") then return false end
    self.settingsView:OpenAliases(ref,title)
    return true
end
function Palette:BeginRowDrag(row)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "DRAG_UNSUPPORTED" end
    local result, err = executor:BeginDrag(row)
    self:ReportActionResult(result, err)
    return result, err
end
-- Internal view layout requests are owned by the currently mounted instance.
-- Store during Mount; commit presentation only after navigation succeeds.
function Palette:ResizeView(instance, height)
    local panel=self.viewHost and self.viewHost.panel
    if not self.visible or not panel or panel.instance~=instance or not self.viewHost:IsActive() then return false end
    if type(height)~="number" or height~=height or height<0 or height==math.huge then return false end
    panel.contentHeight=height
    if not self._openingView then return self:ResizeForMode("panel",height) end
    return true
end

function Palette:SetViewFooter(instance, hint)
    local panel=self.viewHost and self.viewHost.panel
    if not self.visible or not panel or panel.instance~=instance or not self.viewHost:IsActive() then return false end
    if type(hint)~="string" or #hint>256 then return false end
    panel.footerHint=hint
    if not self._openingView then self:SetStatus("panel") end
    return true
end

function Palette:OpenView(factory, context, state)
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self._openingView then return false, "PANEL_BUSY" end
    if not self.visible then return false, "PANEL_CANCELLED" end
    local session, navigation, settings = self.session, self._navigationRevision, self.settingsOpen
    local replacing = self.viewHost:IsActive()
    local focused = self.input.frame.HasFocus and self.input.frame:HasFocus()
    self._openingView = true
    -- Keep the existing presentation until the external create/Mount succeeds.
    -- ViewHost owns provisional resources; Palette owns the presentation commit.
    local mounted, err = self.viewHost:Mount(factory, context or {}, state)
    self._openingView = nil
    -- Catalogue refreshes advance search generation, not user navigation.
    if not self.visible or session ~= self.session or navigation ~= self._navigationRevision or settings ~= self.settingsOpen then
        if mounted then self.viewHost:Unmount("navigation-cancelled") end
        if self.visible and not self.settingsOpen then self:SetQueryMode(self.input:GetText()) end
        return false, "PANEL_CANCELLED"
    end
    if mounted then
        if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
        if self.secureBroker then self.secureBroker:ReleaseAll(); self._searchActionsSuspended = true end
        setShown(self.homeView and self.homeView.frame, false); setShown(self.list and self.list.frame, false); setShown(self.emptyState, false)
        self._motionMode="panel"
        self:ResizeForMode("panel",self.viewHost.panel and self.viewHost.panel.contentHeight); self:SetStatus("panel")
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(self.viewHost.frame,"page") end
    else
        -- A replaced custom instance has already been disposed. Recover the
        -- current home/search page instead of resurrecting disposed resources.
        if replacing then self:SetQueryMode(self.input:GetText()) end
        if focused then self.input:Focus() end
    end
    return mounted, err
end
function Palette:CloseView(reason)
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    local result = self.viewHost:Unmount(reason or "close")
    self:SetQueryMode(self.input:GetText())
    return result
end

function Lychee_Toggle()
    if InCombatLockdown and InCombatLockdown() then return end
    local internal = _G.LycheeInternal
    local controller = internal and internal.Host and internal.Host.PaletteController
    if not controller then controller = Palette:Create() end
    controller:Toggle()
end

Lychee.UI.Palette = Palette
-- Construct the protected hierarchy on the first out-of-combat open, then reuse
-- it. Loading the addon does not need a hidden search window and all of its rows.
