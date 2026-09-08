local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local locale = GetLocale and GetLocale() or "enUS"
_G.BINDING_HEADER_LYCHEE = "Lychee"
_G.BINDING_NAME_TOGGLELYCHEE = locale == "zhCN" and "打开/关闭 Lychee" or "Open/Close Lychee"

local Palette = {}
Palette.__index = Palette

local WIDTH, HEIGHT = 720, 500
local HEADER_HEIGHT, FOOTER_HEIGHT = 76, 28
local HOME_COLUMNS, HOME_TILE_WIDTH, HOME_TILE_HEIGHT = 6, 104, 92
local HOME_COLUMN_GAP, HOME_ROW_GAP, HOME_GROUP_GAP = 12, 14, 18
local HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE = 4, 64

local FALLBACK = {
    window = { 0.045, 0.048, 0.055, 0.985 }, header = { 0.065, 0.068, 0.078, 1 },
    content = { 0.035, 0.038, 0.044, 1 }, footer = { 0.050, 0.053, 0.061, 1 },
    tile = { 0.075, 0.078, 0.088, 1 }, tileHover = { 0.105, 0.108, 0.120, 1 },
    tileSelected = { 0.135, 0.090, 0.098, 1 },
    border = { 0.18, 0.18, 0.20, 1 }, accent = { 0.90, 0.22, 0.29, 1 },
    text = { 0.94, 0.92, 0.89, 1 }, muted = { 0.62, 0.61, 0.59, 1 },
}

local COLOR_ALIAS = {
    tile = "surface",
    tileHover = "surfaceHover",
    tileSelected = "surfaceSelected",
    muted = "textMuted",
}

local function color(name)
    local theme = Lychee.UI.Theme
    return theme and theme.GetColor and theme:GetColor(COLOR_ALIAS[name] or name) or FALLBACK[name]
end

local function paint(texture, value)
    local theme = Lychee.UI.Theme
    if theme and theme.SetColorTexture then return theme:SetColorTexture(texture, value) end
    if not texture or not value or not texture.SetColorTexture or texture._lycheeColorToken == value then return false end
    texture:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
    texture._lycheeColorToken = value
    return true
end

local function tint(fontString, value)
    local theme = Lychee.UI.Theme
    if theme and theme.SetTextColor then return theme:SetTextColor(fontString, value) end
    if not fontString or not value or not fontString.SetTextColor or fontString._lycheeTextToken == value then return false end
    fontString:SetTextColor(value[1], value[2], value[3], value[4] or 1)
    fontString._lycheeTextToken = value
    return true
end

local function paletteDB()
    LycheeDB = LycheeDB or {}
    LycheeDB.palette = LycheeDB.palette or {}
    local db = LycheeDB.palette
    db.recent = type(db.recent) == "table" and db.recent or {}
    db.pinned = type(db.pinned) == "table" and db.pinned or {}
    return db
end

local function stableItemID(item)
    if type(item) ~= "table" then return nil end
    local record = item.searchRecord
    return (record and record.id) or item.id
end

local function localized(value, fallback)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return fallback or "" end
    local current = GetLocale and GetLocale() or "enUS"
    local internal = _G.LycheeInternal
    local normalizer = internal and internal.Search and internal.Search.Normalizer
    if normalizer and normalizer.Localized then
        local entries = normalizer:Localized(value)
        local defaultText, englishText
        for index = 1, #entries do
            local entry = entries[index]
            local identity = internal.Search.RuntimeIdentity
            if not identity or identity:MatchesScope(nil, entry) then
                if entry.locale == current then return entry.text end
                if entry.locale == "default" and defaultText == nil then defaultText = entry.text end
                if entry.locale == "enUS" and englishText == nil then englishText = entry.text end
            end
        end
        return defaultText or englishText or fallback or ""
    end
    return value[current] or value.default or value.enUS or fallback or ""
end

local function homeLabel(value, fallback)
    if type(value) == "table" then return localized(value, fallback) end
    return value or fallback
end

local function setShown(object, shown)
    if object and object.IsShown and object:IsShown() ~= shown then object:SetShown(shown) end
end

local function setText(fontString, text)
    text = text or ""
    if fontString and fontString.GetText and fontString:GetText() ~= text then fontString:SetText(text) end
end

local function cropIcon(texture)
    if texture and type(texture.SetTexCoord) == "function" then texture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
end

local function setAlpha(region, alpha)
    if region and type(region.SetAlpha) == "function" then region:SetAlpha(alpha); return true end
    return false
end

local function animate(region, key, from, to, duration, done)
    if not setAlpha(region, from) then if done then done() end; return false end
    local driver = _G.LycheeInternal and _G.LycheeInternal.Scheduler
    if not driver then setAlpha(region, to); if done then done() end; return false end
    driver:Remove(key)
    local elapsed = 0
    driver:Add(key, function(delta)
        elapsed = elapsed + (delta or 0)
        local progress = math.min(1, elapsed / duration)
        local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
        setAlpha(region, from + (to - from) * eased)
        if progress >= 1 then if done then done() end; return false end
        return true
    end)
    return true
end

local function createHomeView(parent, controller)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetAllPoints(parent)
    frame:Hide()
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(664, 1)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    frame:SetScrollChild(content)
    local view = { frame = frame, content = content, controller = controller, tiles = {}, headers = {}, sections = {}, scroll = 0, selected = 1 }

    function view:RenderTileState(tile)
        local selected = tile.section and tile.index == self.selected and tile.section.enabled ~= false
        paint(tile.bg, color((selected or tile._hovered) and "tileHover" or "content"))
        setShown(tile.focus, false)
    end

    function view:Select(index)
        local count = #self.sections
        if count == 0 then self.selected = 1; return nil end
        index = math.max(1, math.min(index or 1, count))
        if self.sections[index] and self.sections[index].enabled == false then
            local direction = index >= (self.selected or 1) and 1 or -1
            local candidate = index
            repeat candidate = candidate + direction
            until candidate < 1 or candidate > count or self.sections[candidate].enabled ~= false
            if candidate < 1 or candidate > count then return nil end
            index = candidate
        end
        self.selected = index
        for tileIndex = 1, #self.tiles do self:RenderTileState(self.tiles[tileIndex]) end
        return self.sections[index]
    end

    function view:Move(delta)
        local direction = (delta or 0) < 0 and -1 or 1
        local candidate = self.selected or 1
        repeat candidate = candidate + direction
        until candidate < 1 or candidate > #self.sections or self.sections[candidate].enabled ~= false
        if candidate >= 1 and candidate <= #self.sections then return self:Select(candidate) end
        return self.sections[self.selected]
    end

    function view:ActivateSelected()
        local section = self.sections[self.selected]
        if section and section.enabled ~= false and self.controller and self.controller.onHomeSelect then
            self.controller.onHomeSelect(section)
        end
    end

    if frame.SetVerticalScroll then
        frame:SetScript("OnMouseWheel", function(_, delta)
            local maxScroll = math.max(0, (content:GetHeight() or 0) - (frame:GetHeight() or 0) + 20)
            view.scroll = math.max(0, math.min(maxScroll, (view.scroll or 0) - delta * 42))
            if view._appliedScroll ~= view.scroll then
                frame:SetVerticalScroll(view.scroll)
                view._appliedScroll = view.scroll
            end
        end)
    end

    function view:AcquireHeader(index)
        local header = self.headers[index]
        if header then return header end
        header = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetJustifyH("LEFT")
        tint(header, color("text"))
        self.headers[index] = header
        return header
    end

    function view:AcquireTile(index)
        local existing = self.tiles[index]
        if existing then return existing end
        local tile = CreateFrame("Button", nil, self.content)
        tile:SetSize(HOME_TILE_WIDTH, HOME_TILE_HEIGHT)
        tile:RegisterForClicks("LeftButtonUp")
        tile.bg = tile:CreateTexture(nil, "BACKGROUND")
        tile.bg:SetAllPoints()
        paint(tile.bg, color("content"))
        tile.focus = tile:CreateTexture(nil, "BORDER")
        tile.focus:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0)
        tile.focus:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 0)
        tile.focus:SetWidth(1)
        paint(tile.focus, color("accent"))
        tile.focus:Hide()
        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetSize(40, 40)
        tile.icon:SetPoint("TOP", tile, "TOP", 0, -10)
        tile.title = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tile.title:SetPoint("TOPLEFT", tile, "TOPLEFT", 5, -58)
        tile.title:SetPoint("RIGHT", tile, "RIGHT", -6, 0)
        tile.title:SetJustifyH("CENTER")
        if tile.title.SetWordWrap then tile.title:SetWordWrap(false) end
        if tile.title.SetMaxLines then tile.title:SetMaxLines(1) end
        tint(tile.title, color("text"))
        tile.meta = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.meta:SetPoint("TOPLEFT", tile.title, "BOTTOMLEFT", 0, -2)
        tile.meta:SetPoint("RIGHT", tile, "RIGHT", -6, 0)
        tile.meta:SetJustifyH("CENTER")
        if tile.meta.SetWordWrap then tile.meta:SetWordWrap(false) end
        tint(tile.meta, color("muted"))
        tile:SetScript("OnClick", function(button)
            local section = button.section
            if section and section.enabled ~= false and controller and controller.onHomeSelect then
                view:Select(button.index)
                controller.onHomeSelect(section)
            end
        end)
        tile:SetScript("OnEnter", function(button)
            button._hovered = true
            view:RenderTileState(button)
            if GameTooltip and button.section and GameTooltip.SetOwner then
                GameTooltip:SetOwner(button, "ANCHOR_TOP")
                GameTooltip:SetText(homeLabel(button.section.title or button.section.text, "Lychee"))
                if button.section.tooltip and GameTooltip.AddLine then GameTooltip:AddLine(button.section.tooltip, 0.78, 0.78, 0.82, true) end
                if GameTooltip.Show then GameTooltip:Show() end
            end
        end)
        tile:SetScript("OnLeave", function(button)
            button._hovered = false
            view:RenderTileState(button)
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
        self.tiles[index] = tile
        return tile
    end

    function view:EnsureCapacity(headerCount, tileCount)
        for index = #self.headers + 1, headerCount do self:AcquireHeader(index) end
        for index = #self.tiles + 1, tileCount do self:AcquireTile(index) end
    end

    function view:SetSections(sections, allowExpand)
        self.sections = sections or {}
        if allowExpand then self:EnsureCapacity(HOME_HEADER_COUNT, #self.sections) end
        local headerCount, tileCount, cursorY = 0, 0, 0
        local groupID, column = nil, 0
        for index = 1, #self.sections do
            local section = self.sections[index]
            if section.groupID ~= groupID then
                if groupID ~= nil then cursorY = cursorY + HOME_GROUP_GAP end
                groupID, column = section.groupID, 0
                headerCount = headerCount + 1
                local header = self.headers[headerCount]
                if not header then break end
                local anchorKey = cursorY
                if header._homeAnchorKey ~= anchorKey then
                    header:ClearAllPoints()
                    header:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -cursorY)
                    header._homeAnchorKey = anchorKey
                end
                setText(header, homeLabel(section.groupTitle, section.groupID or ""))
                setShown(header, true)
                cursorY = cursorY + 24
            end
            tileCount = tileCount + 1
            local tile = self.tiles[tileCount]
            if not tile then break end
            local row = math.floor(column / HOME_COLUMNS)
            local col = column % HOME_COLUMNS
            local layoutY = cursorY + row * (HOME_TILE_HEIGHT + HOME_ROW_GAP)
            local anchorKey = layoutY * HOME_COLUMNS + col
            if tile._homeAnchorKey ~= anchorKey then
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * (HOME_TILE_WIDTH + HOME_COLUMN_GAP), -layoutY)
                tile._homeAnchorKey = anchorKey
            end
            column = column + 1
            local nextSection = self.sections[index + 1]
            if not nextSection or nextSection.groupID ~= groupID then
                local rows = math.max(1, math.ceil(column / HOME_COLUMNS))
                cursorY = cursorY + rows * HOME_TILE_HEIGHT + math.max(0, rows - 1) * HOME_ROW_GAP
            end
            tile.section = section
            tile.index = index
            setText(tile.title, homeLabel(section.title or section.text, "Lychee"))
            -- 名称下方展示类别标签（如"技能"），让最近使用的条目有上下文；
            -- 没有类别信息的磁贴整行隐藏。
            local metaText = homeLabel(section.meta, "")
            local metaColor = section.categoryColor or color("muted")
            if tile._metaColor ~= metaColor then
                tint(tile.meta, metaColor)
                tile._metaColor = metaColor
            end
            if metaText ~= "" then
                setText(tile.meta, metaText)
                setShown(tile.meta, true)
            else
                setText(tile.meta, "")
                setShown(tile.meta, false)
            end
            if section.icon then
                if tile._icon ~= section.icon then tile.icon:SetTexture(section.icon); cropIcon(tile.icon); tile._icon = section.icon end
                setShown(tile.icon, true)
            else
                tile._icon = nil
                setShown(tile.icon, false)
            end
            setShown(tile, true)
            self:RenderTileState(tile)
        end
        for index = tileCount + 1, #self.tiles do
            local tile = self.tiles[index]
            tile.section, tile.index, tile._hovered = nil, nil, nil
            setShown(tile.focus, false)
            setShown(tile, false)
        end
        for index = headerCount + 1, #self.headers do setShown(self.headers[index], false) end
        local height = math.max(1, cursorY + 14)
        if self.content:GetHeight() ~= height then self.content:SetHeight(height) end
        local maxScroll = math.max(0, height - (self.frame:GetHeight() or 0) + 20)
        self.scroll = math.min(self.scroll or 0, maxScroll)
        if self.frame.SetVerticalScroll and self._appliedScroll ~= self.scroll then
            self.frame:SetVerticalScroll(self.scroll)
            self._appliedScroll = self.scroll
        end
        if not self.sections[self.selected] or self.sections[self.selected].enabled == false then
            local firstEnabled
            for index = 1, #self.sections do if self.sections[index].enabled ~= false then firstEnabled = index; break end end
            self.selected = firstEnabled or 1
        end
        for index = 1, #self.tiles do self:RenderTileState(self.tiles[index]) end
    end

    view:EnsureCapacity(HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE)

    return view
end

function Palette:ApplyBoundedScale()
    if not self.frame or not self.frame.SetScale then return end
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end
    local scale = math.max(0.72, math.min(1, (parentWidth - 48) / WIDTH, (parentHeight - 48) / HEIGHT))
    if self._scale ~= scale then self.frame:SetScale(scale); self._scale = scale end
end

function Palette:Create()
    if self.frame then return self end
    local frame = CreateFrame("Frame", "LycheePalette", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        local window, border = color("window"), color("border")
        if frame.SetBackdropColor then frame:SetBackdropColor(window[1], window[2], window[3], window[4]) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4]) end
    end
    frame:Hide()
    frame:SetScript("OnHide", function() if self.visible then self:Hide("external") end end)
    -- 不注册 Frame 级 OnKeyDown：显示中的 Frame 挂 OnKeyDown 会吞掉全部键盘
    -- 输入（DestinyFrame 即此用途），且 SetPropagateKeyboardInput 在 Blizzard
    -- 代码中零先例、行为不可依赖。Escape 关闭由输入框 OnEscapePressed 处理，
    -- 输入框失焦后按键全部直达游戏。
    self.frame = frame
    self.session, self.generation, self.visible = 0, 0, false
    local components = Lychee.UI.Components
    self.headerComponent = components:CreateBand(frame, { height = HEADER_HEIGHT, top = true, color = "header" })
    self.header = self.headerComponent.frame
    self.footerComponent = components:CreateBand(frame, { height = FOOTER_HEIGHT, top = false, color = "footer" })
    self.footer = self.footerComponent.frame
    self.footer:Hide()
    self.contentComponent = components:CreateSurface(frame, { allPoints = false, color = "content" })
    self.content = self.contentComponent.frame
    self.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_HEIGHT)
    self.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    self.content.bg = self.contentComponent.bg
    self.brandComponent = components:CreateBrand(self.header, {
        iconSize = 30,
        texture = "Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga",
        point = "LEFT",
        x = 16,
    })
    self.brandMark = self.brandComponent.icon
    self.brand = self.brandComponent.label
    self.closeComponent = components:CreateButton(self.header, {
        width = 24, height = 24, point = "RIGHT", relativePoint = "RIGHT", x = -14,
        text = "x",
        colors = { normal = "header", hover = "tileHover", pressed = "tileHover" },
        textColors = { normal = "muted", hover = "text", pressed = "text" },
        onClick = function() self:Hide("close") end,
    })
    self.close = self.closeComponent.frame
    -- 关闭仍由 Esc 和快捷键处理，界面不显示额外的 x 控件。
    self.close:Hide()
    self.close:SetScript("OnClick", function() self:Hide("close") end)
    self.close:SetScript("OnEnter", function(button)
        self.closeComponent:SetState("hover")
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
            GameTooltip:SetText(localized({ zhCN = "关闭", enUS = "Close" }, "Close"))
            GameTooltip:Show()
        end
    end)
    self.close:SetScript("OnLeave", function(button)
        self.closeComponent:SetState("normal")
        if GameTooltip then GameTooltip:Hide() end
    end)
    self.statusComponent = components:CreateStatus(self.footer, { textColor = "textMuted" })
    self.status = self.statusComponent.label

    self.emptyStateComponent = components:CreateEmptyState(self.content, {
        title = localized({ zhCN = "没有找到结果", enUS = "No results found" }, "No results found"),
        detail = "",
        titleColor = "text", detailColor = "textMuted", shown = false,
    })
    self.emptyState = self.emptyStateComponent.frame

    self.focus = Lychee.UI.FocusController:New()
    self.input = Lychee.UI.Input:Create(self.header, self.focus)
    self.list = Lychee.UI.ResultList:Create(self.content, self)
    self.homeView = createHomeView(self.content, self)
    self.homeView:SetSections({})
    self.homeDirty = true
    self.onHomeSelect = function(section)
        if section and section.filter then self:ActivateHomeFilter(section.filter)
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
        if self.input:GetText() == "" then self.homeView:ActivateSelected() else self:ActivateSelected() end
    end)
    self.input:SetMoveCallback(function(delta)
        if self.input:GetText() == "" then self.homeView:Move(delta) else self.list:Move(delta) end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" and self.visible then
            self:Hide("combat")
        elseif event == "GLOBAL_MOUSE_DOWN" then
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
            end)
        end
        if not internal.Host.ClosePalette then internal.Host.ClosePalette = function(reason) return self:Hide(reason) end end
        if not internal.Host.TogglePalette then internal.Host.TogglePalette = function() return self:Toggle() end end
        if internal.WirePalette then internal.WirePalette(self) end
    end
    return self
end

function Palette:SetQueryCallback(callback) self.onQuery = callback end
function Palette:SetActivateCallback(callback) self.onActivate = callback end
function Palette:SetDragCallback(callback) self.onDrag = callback end
function Palette:SetHomeSections(sections, allowExpand) if self.homeView then self.homeView:SetSections(sections or {}, allowExpand) end end
function Palette:SetHomeCategoryCallback(callback) self.onHomeCategory = callback end

function Palette:IsHomeVisible()
    return self.visible and self.homeView and self.homeView.frame:IsShown()
        and not (self.viewHost and self.viewHost:IsActive())
end

function Palette:EnsureHomeCapacity()
    if not self.homeView or not self.homeView.EnsureCapacity then return false end
    local db = paletteDB()
    local required = math.max(1, #db.recent) + math.max(1, #db.pinned) + 5
    self.homeView:EnsureCapacity(HOME_HEADER_COUNT, required)
    return true
end

function Palette:MarkHomeDirty()
    self.homeDirty = true
    self:EnsureHomeCapacity()
    if self:IsHomeVisible() then return self:RefreshHomeSections(false) end
    return true
end

function Palette:TouchRecent(item)
    local id = stableItemID(item)
    if not id then return false end
    local db = paletteDB()
    for index = #db.recent, 1, -1 do if db.recent[index] == id then table.remove(db.recent, index) end end
    table.insert(db.recent, 1, id)
    while #db.recent > 8 do db.recent[#db.recent] = nil end
    self:MarkHomeDirty()
    return true
end

function Palette:SetPinned(item, pinned)
    local id = stableItemID(item)
    if not id then return false end
    local db = paletteDB()
    local found
    for index = #db.pinned, 1, -1 do
        if db.pinned[index] == id then found = true; if not pinned then table.remove(db.pinned, index) end end
    end
    if pinned and not found then db.pinned[#db.pinned + 1] = id end
    while #db.pinned > 16 do table.remove(db.pinned, 1) end
    self:MarkHomeDirty()
    return true
end

function Palette:_IndexedRecordsByID()
    local records, index = {}, {}
    local static = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.StaticIndex
    if not static or type(static.entries) ~= "table" then return records, index end
    for _, entry in pairs(static.entries) do
        local record = entry and entry.record
        if type(record) == "table" and type(record.id) == "string" and not index[record.id] then
            index[record.id], records[#records + 1] = record, record
        end
    end
    return records, index
end

function Palette:RefreshHomeSections(allowExpand)
    if not self.homeView then return false end
    local records, byID = self:_IndexedRecordsByID()
    local db, sections = paletteDB(), {}
    local function appendSaved(groupID, groupTitle, emptyTitle, ids)
        local count = 0
        for index = 1, #ids do
            local record = byID[ids[index]]
            if record then
                sections[#sections + 1] = { id = "saved:" .. ids[index], groupID = groupID, groupTitle = groupTitle,
                    title = localized(record.title, ids[index]),
                    meta = localized(record.category and record.category.title, localized({ zhCN = "实体", enUS = "Entity" }, "Entity")),
                    categoryColor = record.category and record.category.color,
                    icon = record.icon, query = localized(record.title, ids[index]) }
                count = count + 1
            end
        end
    end
    appendSaved("recent", localized({ zhCN = "最近使用", enUS = "Recent" }, "Recent"),
        localized({ zhCN = "还没有最近记录", enUS = "No recent items" }, "No recent items"), db.recent)
    self:SetHomeSections(sections, allowExpand)
    self.homeDirty = false
    return true
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
    if mode == "home" then text = ""
    elseif mode == "panel" then text = localized({ zhCN = "详情", enUS = "Detail" }, "Detail")
    elseif count and count > 0 then text = localized({ zhCN = "搜索结果：", enUS = "Results: " }, "Results: ") .. tostring(count)
    else text = localized({ zhCN = "没有结果", enUS = "No results" }, "No results") end
    setText(self.status, text)
end

function Palette:ResizeForMode(mode, count)
    if not self.frame or not self.frame.SetHeight then return false end
    if mode == "home" or mode == "panel" then
        if self.frame:GetHeight() ~= HEIGHT then self.frame:SetHeight(HEIGHT) end
        return true
    end
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
    local desired = HEADER_HEIGHT + padding + listHeight
    desired = math.max(minHeight, math.min(maxHeight, desired))
    if self.frame:GetHeight() ~= desired then self.frame:SetHeight(desired) end
    return true
end

function Palette:ReportActionResult(result, err)
    local ok = result == true or (type(result) == "table" and result.ok == true)
    if ok then
        setText(self.status, "")
        return true
    end
    local labels = {
        COMBAT_LOCKED = { zhCN = "战斗中不可用", enUS = "Unavailable in combat" },
        ACTION_UNAVAILABLE = { zhCN = "当前不可用", enUS = "Currently unavailable" },
        ACTION_REQUIRES_HARDWARE_CLICK = { zhCN = "请点击施放", enUS = "Click to cast" },
        HANDLER_UNAVAILABLE = { zhCN = "功能暂不可用", enUS = "Feature unavailable" },
        DRAG_UNSUPPORTED = { zhCN = "不支持拖动", enUS = "Drag unsupported" },
    }
    local text = labels[err]
    setText(self.status, localized(text or { zhCN = "执行失败", enUS = "Action failed" }, "Action failed"))
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
    local empty = (text or "") == ""
    if not self.homeView or not self.list then return end
    if self.viewHost and self.viewHost:IsActive() then self.viewHost:Unmount("query-change") end
    setShown(self.viewHost and self.viewHost.frame, false)
    if empty and not self.activeFilter then
        self:ResizeForMode("home")
        setShown(self.list.frame, false); setShown(self.emptyState, false)
        if self.homeDirty then self:RefreshHomeSections(false) end
        setShown(self.homeView.frame, true); self:SetStatus("home")
    else
        self:ResizeForMode("search", self.list.items and #self.list.items or 0)
        setShown(self.homeView.frame, false)
        local hasItems = self.list.items and #self.list.items > 0
        setShown(self.list.frame, hasItems)
        setShown(self.emptyState, not hasItems); self:SetStatus("search", hasItems and #self.list.items or 0)
    end
end

function Palette:IsRowCurrent(row, session, generation, item, extensionID)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "STALE_GENERATION" end
    return executor:IsRowCurrent(row, session, generation, item, extensionID)
end
function Palette:ValidateRowAction(row, session, generation, item, extensionID)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "STALE_GENERATION" end
    return executor:Validate(row, session, generation, item, extensionID)
end
function Palette:InvalidateRow(row)
    if self.secureBroker and self.secureBroker.InvalidateRow then self.secureBroker:InvalidateRow(row) end
    if self.list and self.list.InvalidateRow then self.list:InvalidateRow(row) end
end
function Palette:RejectRow(row, err)
    if err == "STALE_GENERATION" or err == "EXTENSION_DISABLED" then self:InvalidateRow(row) end
    self:ReportActionResult(false, err)
    return false, err
end
function Palette:InvalidateExtension(extensionID)
    if not extensionID then return false end
    if self.viewHost and self.viewHost.panel and self.viewHost.panel.context and self.viewHost.panel.context.extensionID == extensionID then
        self.viewHost:Unmount("extension-disabled")
    end
    if not self.list then return true end
    for index = 1, #self.list.rows do if self.list.rows[index].extensionID == extensionID then self:InvalidateRow(self.list.rows[index]) end end
    return true
end

function Palette:ApplyResults(items, generation, session)
    if not self.visible then return false end
    if session and session ~= self.session then return false end
    if generation and generation ~= self.generation then return false end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    items = items or {}
    self.list:SetItems(items, self.session, self.generation)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if executor then executor:PrepareVisibleRows(self.list.rows) end
    if self.viewHost and self.viewHost:IsActive() then
        setShown(self.homeView.frame, false); setShown(self.list.frame, false); setShown(self.emptyState, false)
        setShown(self.viewHost.frame, true); self:SetStatus("panel")
    elseif self.input:GetText() ~= "" or self.activeFilter then
        self:ResizeForMode("search", #items)
        setShown(self.homeView.frame, false); setShown(self.list.frame, #items > 0); setShown(self.emptyState, #items == 0)
        self:SetStatus("search", #items)
    end
    return true
end
function Palette:SetResults(items, generation, session)
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then return searchSession:_Accept(items, generation or searchSession.generation, session or searchSession.session) end
    return self:ApplyResults(items, generation, session)
end

function Palette:Show()
    self:Create()
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    self:ApplyBoundedScale()
    self.visible = true
    self.frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self:ResizeForMode("home")
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Start() end
    if self.input:GetText() == "" and not self.activeFilter then self:RefreshHomeSections(true) end
    self.frame:Show(); self.input:SetText(self.input:GetText()); self:SetQueryMode(self.input:GetText()); self.input:Show()
    -- Defer focus one frame: the keystroke that opened the palette (e.g. the space
    -- in ALT-SPACE) delivers its character to whichever EditBox is focused during
    -- the same input dispatch; focusing synchronously would swallow it as query text.
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if self.visible then self.input:Focus() end
        end)
    else
        self.input:Focus()
    end
    animate(self.frame, "lychee.palette.open", 0, 1, 0.18)
    return true
end
function Palette:Hide(reason)
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Stop(reason or "hide") end
    if not self.frame or not self.visible then return true end
    self.visible = false
    self.frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self.activeFilter = nil
    self.list:Clear(); setShown(self.emptyState, false)
    if self.viewHost then self.viewHost:Unmount(reason or "hide") end
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.focus:Restore(); self.input:ClearFocus(); self.input:Hide()
    animate(self.frame, "lychee.palette.close", 1, 0, 0.14, function()
        self.frame:Hide(); setAlpha(self.frame, 1)
    end)
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
function Palette:BeginRowDrag(row)
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    if not executor then return false, "DRAG_UNSUPPORTED" end
    local result, err = executor:BeginDrag(row)
    self:ReportActionResult(result, err)
    return result, err
end
function Palette:OpenView(factory, context, state)
    setShown(self.homeView and self.homeView.frame, false); setShown(self.list and self.list.frame, false); setShown(self.emptyState, false)
    local mounted, err = self.viewHost:Mount(factory, context or {}, state)
    if mounted then self:SetStatus("panel") end
    return mounted, err
end
function Palette:CloseView(reason)
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
if not (_G.LycheeInternal and _G.LycheeInternal.Host and _G.LycheeInternal.Host.PaletteController) then Palette:Create() end
