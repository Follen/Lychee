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
local HOME_COLUMNS, HOME_TILE_WIDTH, HOME_TILE_HEIGHT = 7, 81, 76
local HOME_COLUMN_GAP, HOME_ROW_GAP, HOME_GROUP_GAP = 4, 6, 18
local LIST_METRICS = Lychee.UI.Theme.Metrics
local RECENT_LIMIT, RECENT_HEIGHT = 5, LIST_METRICS.rowHeight
local HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE = 4, 8

local FALLBACK = {
    window = { 0.045, 0.048, 0.055, 0.985 }, header = { 0.065, 0.068, 0.078, 1 },
    content = { 0.035, 0.038, 0.044, 1 }, footer = { 0.050, 0.053, 0.061, 1 },
    tile = { 0.075, 0.078, 0.088, 1 }, tileHover = { 0.105, 0.108, 0.120, 1 },
    tileSelected = { 0.085, 0.085, 0.085, 1 },
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

local function localized(value, fallback) return L:Resolve(value, fallback) end

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

local function createHomeView(parent, controller)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetScript("OnHide", function() Lychee.UI.ResultList:HideTooltip() end)
    frame:SetAllPoints(parent)
    frame:Hide()
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(WIDTH - 24, 1)
    frame:SetScrollChild(content)
    local view = { frame = frame, content = content, controller = controller, tiles = {}, headers = {}, sections = {}, scroll = 0, selected = 1 }
    view.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    view.empty:SetText(L["搜索并使用后，常用入口会出现在这里"])
    tint(view.empty, color("muted"))
    Lychee.UI.Theme:SetFont(view.empty, "body")
    view.manage = Lychee.UI.Components:CreateNavigationButton(view.content, {width=48,height=20,text=L["管理"],
        onClick=function() controller:OpenSettings("pins") end})
    Lychee.UI.Theme:SetFont(view.manage.label, "meta")
    view.manage.frame:Hide()

    function view:RenderTileState(tile)
        local selected = tile.section and tile.index == self.selected and tile.section.enabled ~= false
        paint(tile.bg, color("accent"))
        if Lychee.UI.Motion then Lychee.UI.Motion:Selection(tile.bg,selected==true)
        else setShown(tile.bg, selected == true) end
        if tile.selectionFill then
            if Lychee.UI.Motion then Lychee.UI.Motion:Selection(tile.selectionFill,selected == true and tile._recentLayout == true)
            else setShown(tile.selectionFill,selected == true and tile._recentLayout == true) end
        end
    end

    function view:SetHover(tile, hovered)
        tile._hovered = hovered == true
        if hovered and tile.index then self:Select(tile.index) end
        self:RenderTileState(tile)
    end

    function view:ShowTooltip(tile, owner)
        if not tile.section then return end
        if tile.item then return Lychee.UI.ResultList:ShowItemTooltip(tile.item, owner or tile) end
        Lychee.UI.ResultList:ShowTextTooltip(homeLabel(tile.section.title, "Lychee"), owner or tile)
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
            self.controller.onHomeSelect(section, self.tiles[self.selected])
        end
    end

    view.scrollbar = Lychee.UI.Components:CreateScrollbar(frame, function(value) view:SetScroll(value) end)
    function view:RefreshScrollRect()
        if not frame:IsShown() or (InCombatLockdown and InCombatLockdown()) or not frame.UpdateScrollChildRect then return end
        local width,height=frame:GetWidth(),frame:GetHeight()
        local contentHeight=content:GetHeight()
        if not self._scrollRectDirty and self._rectWidth==width and self._rectHeight==height and self._rectContentHeight==contentHeight then return end
        frame:UpdateScrollChildRect()
        self._rectWidth,self._rectHeight,self._rectContentHeight=width,height,contentHeight
        self._scrollRectDirty=false
    end
    function view:SetScroll(value)
        if InCombatLockdown and InCombatLockdown() then return end
        local viewport = math.max(0, frame:GetHeight() - 20)
        self.scroll = math.max(0, math.min(math.max(0, content:GetHeight() - viewport), value))
        if self._appliedScroll ~= self.scroll then
            frame:SetVerticalScroll(self.scroll); self._appliedScroll = self.scroll
        end
        self.scrollbar:SetRange(content:GetHeight(), viewport, self.scroll)
    end
    frame:SetScript("OnSizeChanged", function() view:SetScroll(view.scroll);view:RefreshScrollRect() end)
    frame:SetScript("OnShow",function() view._scrollRectDirty=true;view:RefreshScrollRect() end)
    if frame.SetVerticalScroll then
        frame:SetScript("OnMouseWheel", function(_, delta)
            view:SetScroll(view.scroll - delta * 42)
        end)
    end

    function view:AcquireHeader(index)
        local header = self.headers[index]
        if header then return header end
        header = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetJustifyH("LEFT")
        tint(header, color("muted"))
        Lychee.UI.Theme:SetFont(header, "meta")
        self.headers[index] = header
        return header
    end

    function view:AcquireTile(index)
        local existing = self.tiles[index]
        if existing then return existing end
        local tile = CreateFrame("Button", nil, self.content)
        tile:SetSize(HOME_TILE_WIDTH, HOME_TILE_HEIGHT)
        tile.ownerView = self
        tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        tile.bg = tile:CreateTexture(nil, "BACKGROUND")
        tile.bg:SetSize(32, 2)
        paint(tile.bg, color("accent"))
        tile.bg:Hide()
        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetSize(28, 28)
        tile.icon:SetPoint("TOP", tile, "TOP", 0, -12)
        tile.fallback = {}
        for index = 1, 4 do
            local dot = tile:CreateTexture(nil, "ARTWORK")
            dot:SetSize(8, 8)
            dot:SetPoint("CENTER", tile.icon, "CENTER", (index - 1) % 2 * 12 - 6, 6 - math.floor((index - 1) / 2) * 12)
            paint(dot, color("muted"))
            dot:Hide()
            tile.fallback[index] = dot
        end
        tile.title = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.title:SetPoint("TOPLEFT", tile, "TOPLEFT", 4, -54)
        tile.title:SetPoint("RIGHT", tile, "RIGHT", -4, 0)
        tile.title:SetHeight(28)
        tile.title:SetJustifyH("CENTER")
        if tile.title.SetJustifyV then tile.title:SetJustifyV("TOP") end
        if tile.title.SetWordWrap then tile.title:SetWordWrap(true) end
        if tile.title.SetNonSpaceWrap then tile.title:SetNonSpaceWrap(true) end
        if tile.title.SetMaxLines then tile.title:SetMaxLines(2) end
        tint(tile.title, color("text"))
        Lychee.UI.Theme:SetFont(tile.title, "body")
        tile.bg:SetPoint("TOP", tile.title, "BOTTOM", 0, -5)
        tile.category = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.category:SetPoint("RIGHT", tile, "RIGHT", -12, 0)
        tile.category:SetWidth(90)
        tile.category:SetJustifyH("RIGHT")
        Lychee.UI.Theme:SetFont(tile.category, "meta")
        tint(tile.category, color("muted"))
        tile:SetScript("OnClick", function(button, mouseButton)
            if mouseButton == "RightButton" and controller and (button.item or button.section and button.section.pinnedRef) then
                view:Select(button.index)
                controller:ShowRowActions(button)
                return
            end
            local section = button.section
            if section and section.enabled ~= false and controller and controller.onHomeSelect then
                view:Select(button.index)
                controller.onHomeSelect(section, button)
            end
        end)
        tile:SetScript("OnEnter", function(button)
            view:SetHover(button, true)
            view:ShowTooltip(button)
        end)
        tile:SetScript("OnLeave", function(button)
            view:SetHover(button, false)
            Lychee.UI.ResultList:HideTooltip()
        end)
        tile:SetScript("OnDragStart", function(button) controller:BeginRowDrag(button) end)
        self.tiles[index] = tile
        return tile
    end

    function view:ConfigureLayout(tile, recent)
        if tile._recentLayout == recent then return end
        self._scrollRectDirty=true
        tile._recentLayout = recent
        tile._titleLayoutDirty = true
        tile:SetSize(recent and (LIST_METRICS.resultTileWidth-12) or HOME_TILE_WIDTH, recent and RECENT_HEIGHT or HOME_TILE_HEIGHT)
        tile.icon:ClearAllPoints()
        tile.title:ClearAllPoints()
        tile.bg:ClearAllPoints()
        if recent then
            if not tile.selectionFill then
                tile.selectionFill=tile:CreateTexture(nil,"BACKGROUND",nil,-1)
                tile.selectionFill:SetPoint("TOPLEFT",tile,"TOPLEFT",0,-LIST_METRICS.selectionInsetY)
                tile.selectionFill:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,LIST_METRICS.selectionInsetY)
                paint(tile.selectionFill,color("tileSelected"))
            end
            tile.icon:SetPoint("LEFT", tile, "LEFT", LIST_METRICS.listIconInset, 0)
            tile.title:SetPoint("LEFT", tile, "LEFT", LIST_METRICS.listTitleInset, 0)
            tile.title:SetPoint("RIGHT", tile, "RIGHT", -112, 0)
            tile.title:SetJustifyH("LEFT")
            tile.title:SetHeight(18)
            tile.bg:SetSize(LIST_METRICS.selectionWidth, LIST_METRICS.selectionHeight)
            tile.bg:SetPoint("LEFT", tile, "LEFT", 0, 0)
        else
            tile.icon:SetPoint("TOP", tile, "TOP", 0, -8)
            tile.title:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -43)
            tile.title:SetPoint("RIGHT", tile, "RIGHT", -2, 0)
            tile.title:SetJustifyH("CENTER")
            tile.title:SetHeight(28)
            tile.bg:SetSize(32, 2)
            tile.bg:SetPoint("TOP", tile.title, "BOTTOM", 0, -5)
        end
        if tile.title.SetWordWrap then tile.title:SetWordWrap(not recent) end
        if tile.title.SetMaxLines then tile.title:SetMaxLines(recent and 1 or 2) end
        Lychee.UI.Theme:SetFont(tile.title, recent and "body" or "meta")
        setShown(tile.category, recent)
    end

    function view:EnsureCapacity(headerCount, tileCount)
        for index = #self.headers + 1, headerCount do self:AcquireHeader(index) end
        for index = #self.tiles + 1, tileCount do self:AcquireTile(index) end
    end

    function view:SetSections(sections, allowExpand)
        Lychee.UI.ResultList:HideTooltip()
        self.sections = sections or {}
        setShown(self.empty, #self.sections == 0)
        if allowExpand then self:EnsureCapacity(HOME_HEADER_COUNT, #self.sections) end
        -- ScrollFrame owns the child origin; keep padding in content anchors.
        local headerCount, tileCount, cursorY = 0, 0, 10
        local pinnedHeader
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
                    self._scrollRectDirty=true
                    header:ClearAllPoints()
                    header:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12, -cursorY)
                    header._homeAnchorKey = anchorKey
                end
                setText(header, homeLabel(section.groupTitle, section.groupID or ""))
                setShown(header, true)
                if groupID == "pinned" then
                    pinnedHeader = true
                    if self._manageY ~= cursorY then
                        self.manage.frame:ClearAllPoints()
                        self.manage.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -14, -cursorY+3)
                        self._manageY = cursorY
                    end
                end
                cursorY = cursorY + 24
            end
            tileCount = tileCount + 1
            local tile = self.tiles[tileCount]
            if not tile then break end
            local recent = section.groupID == "recent"
            self:ConfigureLayout(tile, recent)
            local columns = recent and 1 or HOME_COLUMNS
            local tileHeight = recent and RECENT_HEIGHT or HOME_TILE_HEIGHT
            local row = math.floor(column / columns)
            local col = column % columns
            local layoutY = cursorY + row * (tileHeight + HOME_ROW_GAP)
            local anchorKey = layoutY * HOME_COLUMNS + col
            if tile._homeAnchorKey ~= anchorKey then
                self._scrollRectDirty=true
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12 + col * (HOME_TILE_WIDTH + HOME_COLUMN_GAP), -layoutY)
                tile._homeAnchorKey = anchorKey
            end
            column = column + 1
            local nextSection = self.sections[index + 1]
            if not nextSection or nextSection.groupID ~= groupID then
                local rows = math.max(1, math.ceil(column / columns))
                cursorY = cursorY + rows * tileHeight + math.max(0, rows - 1) * HOME_ROW_GAP
            end
            tile.section = section
            tile.index = index
            tile.item = section.item
            local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
            if executor then executor:ConfigureDragTarget(tile, tile.item) end
            tile.session, tile.generation = controller.session, controller.generation
            tile.extensionID = section.item and section.item._ext
            local title = homeLabel(section.title or section.text, "Lychee")
            setText(tile.category, homeLabel(section.meta, ""))
            tint(tile.title, color(section.enabled == false and "muted" or "text"))
            if tile._title ~= title or tile._titleLayoutDirty then
                setText(tile.title, title)
                if not recent and tile.title.GetStringHeight then
                    local height = math.max(14, math.min(28, tile.title:GetStringHeight()))
                    if tile.title:GetHeight() ~= height then tile.title:SetHeight(height) end
                end
                if not recent then
                    local textWidth = tile.title.GetStringWidth and tile.title:GetStringWidth() or 64
                    local markerWidth = math.floor(math.max(16, math.min(36, textWidth * 0.5)) + 0.5)
                    if tile.bg:GetWidth() ~= markerWidth then tile.bg:SetWidth(markerWidth) end
                end
                tile._title = title
                tile._titleLayoutDirty = nil
            end
            if section.icon then
                if tile._icon ~= section.icon then tile.icon:SetTexture(section.icon); cropIcon(tile.icon); tile._icon = section.icon end
                setShown(tile.icon, true)
            else
                tile._icon = nil
                setShown(tile.icon, false)
            end
            for fallbackIndex = 1, #tile.fallback do setShown(tile.fallback[fallbackIndex], not section.icon) end
            if not tile:IsShown() then self._scrollRectDirty=true end
            setShown(tile, true)
            self:RenderTileState(tile)
        end
        setShown(self.manage.frame, pinnedHeader == true)
        for index = tileCount + 1, #self.tiles do
            local tile = self.tiles[index]
            if tile:IsShown() then self._scrollRectDirty=true end
            tile.section, tile.index, tile._hovered = nil, nil, nil
            tile.item, tile.session, tile.generation, tile.extensionID = nil, nil, nil, nil
            setShown(tile.bg, false)
            if Lychee.UI.Motion then
                Lychee.UI.Motion:Cancel(tile.bg,true);tile.bg._lycheeSelectedMotion=nil
                if tile.selectionFill then Lychee.UI.Motion:Cancel(tile.selectionFill,true);tile.selectionFill._lycheeSelectedMotion=nil end
            end
            local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
            if executor then executor:ConfigureDragTarget(tile, nil) end
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
        self.scrollbar:SetRange(height, math.max(0, self.frame:GetHeight() - 20), self.scroll)
        if not self.sections[self.selected] or self.sections[self.selected].enabled == false then
            local firstEnabled
            for index = 1, #self.sections do if self.sections[index].enabled ~= false then firstEnabled = index; break end end
            self.selected = firstEnabled or 1
        end
        for index = 1, #self.tiles do self:RenderTileState(self.tiles[index]) end
        self:RefreshScrollRect()
    end

    view:EnsureCapacity(HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE)

    return view
end

function Palette:ApplyBoundedScale()
    if not self.frame or not self.frame.SetScale then return end
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    if not parentWidth or not parentHeight or parentWidth <= 0 or parentHeight <= 0 then return end
    local scale = math.min(1, (parentWidth - 48) / WIDTH, (parentHeight - 48) / 600)
    if self._scale ~= scale then self.frame:SetScale(scale); self._scale = scale end
    local inset = math.max(24, (parentHeight - 600 * scale) / 2)
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
    Lychee.UI.Theme:CreateRoundedSurface(frame, "window", 10)
    frame:Hide()
    -- Only the secure snippet hides a protected hierarchy during combat. The
    -- non-combat state deliberately does nothing, so leaving combat never opens it.
    frame:SetAttribute("_onstate-combat", [[if newstate == "hide" then self:Hide() end]])
    if RegisterStateDriver then RegisterStateDriver(frame, "combat", "[combat] hide; idle") end
    frame:SetScript("OnHide", function()
        if Lychee.UI.Motion then Lychee.UI.Motion:StopAll() end
        if self.visible then self:Hide("external")
        elseif InCombatLockdown and InCombatLockdown() then self.combatCleanupPending=true end
    end)
    -- Let the native Escape dispatcher close the window when the EditBox has
    -- lost focus. OnHide above runs the same cleanup as the close button.
    -- Create is idempotent, so this registers once without a keyboard handler.
    if UISpecialFrames then table.insert(UISpecialFrames, "LycheePalette") end
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
    self.brandComponent = components:CreateBrand(self.header, {
        iconSize = 42,
        texture = "Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga",
        point = "LEFT",
        x = 14,
    })
    self.brandMark = self.brandComponent.icon
    self.brand = self.brandComponent.label
    self.settingsButton = CreateFrame("Button", nil, self.header)
    self.settingsButton:SetAllPoints(self.brandMark)
    self.settingsButton:SetScript("OnClick", function() self:OpenSettings() end)
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
    tint(self.footerHint, color("muted"))
    Lychee.UI.Theme:SetFont(self.footerHint, "meta")
    local footerLine = self.footer:CreateTexture(nil, "BORDER")
    footerLine:SetPoint("TOPLEFT", self.footer, "TOPLEFT", LIST_METRICS.footerInset, 0)
    footerLine:SetPoint("TOPRIGHT", self.footer, "TOPRIGHT", -LIST_METRICS.footerInset, 0)
    footerLine:SetHeight(1)
    Lychee.UI.Theme:SetColorTexture(footerLine,"footerDivider")
    local divider = self.header:CreateTexture(nil, "BORDER")
    divider:SetPoint("LEFT", self.header, "LEFT", 62, 0)
    divider:SetSize(1, 18)
    paint(divider, color("border"))

    self.emptyStateComponent = components:CreateEmptyState(self.content, {
        title = L["没有找到结果"],
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
    if Lychee.RegisterProvider then
        self.settingsProvider = Lychee:RegisterProvider({id="lychee.settings",apiVersion=2,version="1.0.0",title=L["荔枝设置"],
            entries={{id="settings",title=L["荔枝设置"],kindTitle=L["设置"],aliases={"设置","荔枝设置","lychee settings"},
                icon="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\settings.tga",actions={"open"}}},
            actions={open={title=L["打开荔枝设置"],run=function() local ok,err=self:OpenSettings();if not ok then return nil,err end;return {ok=true,close=false} end}}})
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
    if self.secureBroker then self.secureBroker:ReleaseAll() end
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
function Palette:SetHomeSections(sections, allowExpand) if self.homeView then self.homeView:SetSections(sections or {}, allowExpand) end end
function Palette:SetHomeCategoryCallback(callback) self.onHomeCategory = callback end

function Palette:IsHomeVisible()
    return self.visible and not self.settingsOpen and self.homeView and self.homeView.frame:IsShown()
        and not (self.viewHost and self.viewHost:IsActive())
end

function Palette:EnsureHomeCapacity()
    if InCombatLockdown and InCombatLockdown() then return false end
    if not self.homeView or not self.homeView.EnsureCapacity then return false end
    local db = paletteDB()
    local required = math.max(1, #db.recent) + math.max(1, #db.pinned) + 5
    self.homeView:EnsureCapacity(HOME_HEADER_COUNT, required)
    return true
end

function Palette:MarkHomeDirty()
    self.homeDirty = true
    if InCombatLockdown and InCombatLockdown() then return false end
    if self:IsHomeVisible() then return self:RefreshHomeSections(false) end
    return true
end

function Palette:TouchRecent(item)
    if not item or not item.ref or item.ref.providerID == "lychee.settings" or not I.Providers or not I.Providers:CanRemember(item) then return false end
    local ref = item.ref
    local db = paletteDB()
    if I.Search.Personalization and self.input and not self.settingsOpen then
        I.Search.Personalization:Remember(self.input:GetText(),item)
    end
    for index = #db.recent, 1, -1 do
        local previous = db.recent[index]
        if previous.providerID == ref.providerID and previous.entryID == ref.entryID then table.remove(db.recent, index) end
    end
    table.insert(db.recent, 1, { providerID = ref.providerID, entryID = ref.entryID, sourceID = ref.sourceID })
    while #db.recent > 8 do db.recent[#db.recent] = nil end
    self:MarkHomeDirty()
    return true
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
    if InCombatLockdown and InCombatLockdown() then self.homeDirty = true; return false end
    local db, sections = paletteDB(), {}
    local internal = _G.LycheeInternal
    local query = internal and internal.Search and internal.Search.Query
    local preferences = I.UserPreferences
    if preferences then
        preferences:MigratePins()
        for index, pin in ipairs(preferences:GetPins()) do
            local item = preferences:Resolve(pin)
            local title = type(pin) == "table" and (pin.title or pin.entryID) or tostring(pin)
            sections[#sections + 1] = {id="pin:" .. index, groupID="pinned", groupTitle=L["已固定"],
                title=item and item.text or title, icon=item and item.icon or type(pin)=="table" and pin.icon,
                item=item, pinnedRef=pin, enabled=item~=nil, meta=item and item.kindTitle or ""}
        end
    end
    local items = query and query:ResolveRecent(db.recent, RECENT_LIMIT) or {}
    for index = 1, #items do
        local item = items[index]
        sections[#sections + 1] = { id = "saved:" .. item.ref.providerID .. ":" .. item.id, groupID = "recent",
            groupTitle = L["最近使用"],
            title = item.text, icon = item.icon, item = item, meta = item.kindTitle or "", categoryColor = item.categoryColor }
    end
    if self.secureBroker then
        for index = 1, #self.homeView.tiles do self.secureBroker:InvalidateRow(self.homeView.tiles[index]) end
    end
    self:SetHomeSections(sections, allowExpand)
    self.homeDirty = false
    if self:IsHomeVisible() then self:PrepareHome(true); self:ResizeForMode("home") end
    return true
end

function Palette:PrepareHome(rebound)
    if not self.visible or (InCombatLockdown and InCombatLockdown()) then return end
    local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
    for index = 1, #self.homeView.sections do
        local tile = self.homeView.tiles[index]
        tile.session, tile.generation = self.session, self.generation
        -- Query-scoped Provider records can expire while Home is hidden. Rebind
        -- saved identities before the executor rejects and hides individual rows.
        -- A failed resolver gets only this one pass, never recursive retries.
        if not rebound and executor and tile.section.item and not executor:IsRowCurrent(tile) then
            return self:RefreshHomeSections(false)
        end
    end
    if executor then executor:PrepareVisibleRows(self.homeView.tiles) end
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
    if mode == "home" then text = L["输入即搜索"]
    elseif mode == "panel" then text = L["详情"]
    elseif count and count > 0 then text = L["搜索结果："] .. tostring(count)
    else text = L["没有结果"] end
    setText(self.status, text)
    setText(self.footerHint, mode == "home" and "" or L["↑ ↓ 选择   ·   点击使用"])
end

function Palette:ResizeForMode(mode, count)
    if mode=="search" and self.searchPending then return true end
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
        listHeight = self.homeView and self.homeView.content:GetHeight() or 0
        padding = 0 -- Home content includes its own top and bottom spacing.
    end
    if mode == "panel" then listHeight = 360 end
    if mode == "settings" then listHeight = metrics.resultTiles * rowHeight + (metrics.resultTiles - 1) * rowGap end
    if mode == "settings-detail" then listHeight = math.max(0,tonumber(count) or 0) end
    local desired = HEADER_HEIGHT + FOOTER_HEIGHT + padding + listHeight
    desired = math.max(minHeight, math.min(maxHeight, desired))
    if self.frame:GetHeight() ~= desired then
        if Lychee.UI.Motion then Lychee.UI.Motion:Height(self.frame,desired) else self.frame:SetHeight(desired) end
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
        if self.homeDirty then self:RefreshHomeSections(false) end
        setShown(self.homeView.frame, true); self:ResizeForMode("home"); self:PrepareHome(); self:SetStatus("home")
    else
        self:ResizeForMode("search", self.list.items and #self.list.items or 0)
        setShown(self.homeView.frame, false)
        local hasItems = self.list.items and #self.list.items > 0
        setShown(self.list.frame, hasItems)
        setShown(self.emptyState, not hasItems and not self.searchPending)
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
    if InCombatLockdown and InCombatLockdown() then self.homeDirty = true; return end
    if row and row.ownerView == self.homeView then
        row.item = nil
        setShown(row, false)
        return
    end
    if self.list and self.list.InvalidateRow then self.list:InvalidateRow(row) end
end
function Palette:RejectRow(row, err)
    if err == "STALE_GENERATION" or err == "EXTENSION_DISABLED" then self:InvalidateRow(row) end
    self:ReportActionResult(false, err)
    return false, err
end
function Palette:InvalidateExtension(extensionID)
    if not extensionID then return false end
    if InCombatLockdown and InCombatLockdown() then self.homeDirty = true; return false end
    if self.viewHost and self.viewHost:IsOwnedBy(extensionID) then
        self.viewHost:Unmount("extension-disabled")
    end
    if not self.list then return true end
    for index = 1, #self.list.rows do if self.list.rows[index].extensionID == extensionID then self:InvalidateRow(self.list.rows[index]) end end
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
    if executor then executor:PrepareVisibleRows(self.list.rows) end
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
    local inspector=I.Builtin and I.Builtin.AddonInspector
    if inspector and inspector.running then inspector:Stop() end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if self.visible then return true end
    self:Create()
    self.input:SetEnabled(true)
    if self._motionClosing then self:FinishHide("reopen") end
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll();self.frame:SetAlpha(1) end
    self._motionClosing=nil
    if self.combatCleanupPending then self:FinishHide("combat") end
    self.input:SetText("")
    self:ApplyBoundedScale()
    self.visible = true
    self.frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self:ResizeForMode("home")
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Start() end
    if I.Search.Normalizer:IsBlank(self.input:GetText()) and not self.activeFilter then self:RefreshHomeSections(true) end
    self.frame:Show(); self.input:SetText(self.input:GetText()); self:SetQueryMode(self.input:GetText()); self.input:Show()
    if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(self.frame,"enter") end
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
    Lychee.UI.ResultList:HideTooltip()
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    -- Invalidate the session only after marking the UI inactive; a synchronous
    -- result callback must not repaint a protected row on combat entry.
    self.visible = false
    self.searchPending=false
    self.actionMenu = nil
    local searchSession = _G.LycheeInternal and _G.LycheeInternal.Search and _G.LycheeInternal.Search.Session
    if searchSession then searchSession:Stop(reason or "hide") end
    if not self.frame then return true end
    self.frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self.activeFilter = nil
    if self.secureBroker and self.secureBroker.ReleaseAll then self.secureBroker:ReleaseAll() end
    self.input:ClearFocus()
    self.input:SetEnabled(false)
    if InCombatLockdown and InCombatLockdown() then
        self.combatCleanupPending = true
        return true
    end
    local motion=Lychee.UI.Motion
    if motion and self.frame:IsShown() and not motion:IsReduced() and self.frame.CreateAnimationGroup then
        self._motionClosing=true
        motion:Alpha(self.frame,0,motion.durations.exit,function()
            if self._motionClosing and not self.visible then self._motionClosing=nil;self:FinishHide(reason) end
        end)
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
function Palette:OpenView(factory, context, state)
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if Lychee.UI.Motion then Lychee.UI.Motion:StopAll(self.frame) end
    setShown(self.homeView and self.homeView.frame, false); setShown(self.list and self.list.frame, false); setShown(self.emptyState, false)
    local mounted, err = self.viewHost:Mount(factory, context or {}, state)
    if mounted then
        self._motionMode="panel"
        self:ResizeForMode("panel"); self:SetStatus("panel")
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(self.viewHost.frame,"page") end
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
