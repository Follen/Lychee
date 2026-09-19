local I, Lychee = _G.LycheeInternal, _G.Lychee
local L = I.Locale
local HomeView = {}
HomeView.__index = HomeView
Lychee.UI.HomeView = HomeView

local WIDTH = 640
local HOME_COLUMNS, HOME_TILE_WIDTH, HOME_TILE_HEIGHT = 7, 81, 76
local HOME_COLUMN_GAP, HOME_ROW_GAP, HOME_GROUP_GAP = 4, 6, 18
local LIST_METRICS = Lychee.UI.Theme.Metrics
local RECENT_LIMIT, RECENT_HEIGHT = 5, LIST_METRICS.rowHeight
local HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE = 4, 8
local function color(name)
    return Lychee.UI.Theme:GetColor(name == "muted" and "textMuted" or name == "tileSelected" and "surfaceSelected" or name)
end
local function paint(texture, value) return Lychee.UI.Theme:SetColorTexture(texture, value) end
local function tint(text, value) return Lychee.UI.Theme:SetTextColor(text, value) end
local function homeLabel(value, fallback)
    if type(value) == "table" then return L:Resolve(value, fallback) end
    return value or fallback
end
local function setShown(object, shown)
    if object and object.IsShown and object:IsShown() ~= shown then object:SetShown(shown) end
end
local function setText(text, value)
    value = value or ""
    if text and text.GetText and text:GetText() ~= value then text:SetText(value) end
end
local function cropIcon(texture)
    if texture and type(texture.SetTexCoord) == "function" then texture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
end
local function navigable(section)
    if not section then return false end
    if section.enabled ~= false then return true end
    local ref = not section.item and (section.pinnedRef or section.recentRef)
    local session = I.Search and I.Search.Session
    if not ref or not session then return false end
    local status = session:GetHomeStatus(ref)
    return status == nil or status == "pending"
end

function HomeView:Create(parent, controller)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetScript("OnHide", function() Lychee.UI.ResultList:HideTooltip() end)
    frame:SetAllPoints(parent)
    frame:Hide()
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(WIDTH - 24, 1)
    frame:SetScrollChild(content)
    local view = setmetatable({ frame = frame, content = content, controller = controller, tiles = {}, headers = {}, sections = {}, scroll = 0, selected = 1, dirty = true }, HomeView)
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
        local selected = tile.index == self.selected and navigable(tile.section)
        paint(tile.bg, color("accent"))
        if Lychee.UI.Motion then Lychee.UI.Motion:Selection(tile.bg,selected==true)
        else setShown(tile.bg, selected == true) end
        if tile.selectionFill then
            if Lychee.UI.Motion then Lychee.UI.Motion:Selection(tile.selectionFill,selected == true and tile._recentLayout == true)
            else setShown(tile.selectionFill,selected == true and tile._recentLayout == true) end
        end
    end

    function view:SetHover(tile, hovered)
        if self.frozen then return end
        tile._hovered = hovered == true
        if hovered and tile.index then self:Select(tile.index) end
        self:RenderTileState(tile)
    end

    function view:ShowTooltip(tile, owner)
        if self.frozen then return end
        if not tile.section then return end
        if tile.item then return Lychee.UI.ResultList:ShowItemTooltip(tile.item, owner or tile) end
        local title=homeLabel(tile.section.title, "Lychee")
        if tile.section.meta and tile.section.meta~="" then title=title.."\n"..homeLabel(tile.section.meta, "") end
        Lychee.UI.ResultList:ShowTextTooltip(title, owner or tile)
    end

    function view:Select(index)
        if self.frozen then return end
        local count = #self.sections
        if count == 0 then self.selected = 1; return nil end
        index = math.max(1, math.min(index or 1, count))
        if not navigable(self.sections[index]) then
            local direction = index >= (self.selected or 1) and 1 or -1
            local candidate = index
            repeat candidate = candidate + direction
            until candidate < 1 or candidate > count or navigable(self.sections[candidate])
            if candidate < 1 or candidate > count then return nil end
            index = candidate
        end
        self.selected = index
        for tileIndex = 1, #self.tiles do self:RenderTileState(self.tiles[tileIndex]) end
        return self.sections[index]
    end

    function view:Move(delta)
        if self.frozen then return end
        local direction = (delta or 0) < 0 and -1 or 1
        local candidate = self.selected or 1
        repeat candidate = candidate + direction
        until candidate < 1 or candidate > #self.sections or navigable(self.sections[candidate])
        if candidate >= 1 and candidate <= #self.sections then self:Select(candidate) end
        local tile = self.tiles[self.selected]
        if tile and tile:IsShown() then
            local _,_,_,_,y = tile:GetPoint(1)
            if y then
                local top = -y
                local bottom = top + tile:GetHeight() - frame:GetHeight()
                if top < self.scroll then self:SetScroll(top)
                elseif bottom > self.scroll then self:SetScroll(bottom) end
            end
        end
        return self.sections[self.selected]
    end

    function view:ActivateSelected()
        if self.frozen then return end
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
        if self.frozen then return end
        if InCombatLockdown and InCombatLockdown() then return end
        local viewport = math.max(0, frame:GetHeight())
        self.scroll = math.max(0, math.min(math.max(0, content:GetHeight() - viewport), value))
        if self._appliedScroll ~= self.scroll then
            frame:SetVerticalScroll(self.scroll); self._appliedScroll = self.scroll
        end
        self.scrollbar:SetRange(content:GetHeight(), viewport, self.scroll)
        self:ReportDemand()
    end
    frame:SetScript("OnSizeChanged", function() view:SetScroll(view.scroll);view:RefreshScrollRect() end)
    frame:SetScript("OnShow",function()
        view._scrollRectDirty=true;view:RefreshScrollRect()
        view:ReportDemand()
    end)
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
        tile.category:SetWidth(LIST_METRICS.sourceLabelWidth)
        tile.category:SetHeight(16)
        tile.category:SetWordWrap(false)
        tile.category:SetNonSpaceWrap(false)
        tile.category:SetMaxLines(1)
        tile.category:SetJustifyH("RIGHT")
        Lychee.UI.Theme:SetFont(tile.category, "meta")
        tint(tile.category, color("muted"))
        local binding = I.InteractionBinding
        binding:Attach(tile, tile)
        tile:SetScript("OnClick", function(button, mouseButton)
            if not binding:Consume(button, button, mouseButton) then return end
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
            if controller.DeferRowHover and controller:DeferRowHover(button) then return end
            view:SetHover(button, true)
            view:ShowTooltip(button)
        end)
        tile:SetScript("OnLeave", function(button)
            view:SetHover(button, false)
            Lychee.UI.ResultList:HideTooltip()
        end)
        tile:SetScript("OnDragStart", function(button) if binding:Consume(button, button, "LeftButton") then controller:BeginRowDrag(button) end end)
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
        tile.category:ClearAllPoints()
        if recent then
            tile.category:SetPoint("RIGHT",tile,"RIGHT",-12,0)
            tile.category:SetWidth(LIST_METRICS.sourceLabelWidth)
            tile.category:SetJustifyH("RIGHT")
            if not tile.selectionFill then
                tile.selectionFill=tile:CreateTexture(nil,"BACKGROUND",nil,-1)
                tile.selectionFill:SetPoint("TOPLEFT",tile,"TOPLEFT",0,-LIST_METRICS.selectionInsetY)
                tile.selectionFill:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,LIST_METRICS.selectionInsetY)
                paint(tile.selectionFill,color("tileSelected"))
            end
            tile.icon:SetPoint("LEFT", tile, "LEFT", LIST_METRICS.listIconInset, 0)
            tile.title:SetPoint("LEFT", tile, "LEFT", LIST_METRICS.listTitleInset, 0)
            tile.title:SetPoint("RIGHT", tile.category, "LEFT", -14, 0)
            tile.title:SetJustifyH("LEFT")
            tile.title:SetHeight(18)
            tile.bg:SetSize(LIST_METRICS.selectionWidth, LIST_METRICS.selectionHeight)
            tile.bg:SetPoint("LEFT", tile, "LEFT", 0, 0)
        else
            tile.category:SetPoint("TOPLEFT",tile,"TOPLEFT",2,-60)
            tile.category:SetWidth(HOME_TILE_WIDTH-4)
            tile.category:SetJustifyH("CENTER")
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
        if self.frozen then
            self.frozen = nil
            frame:SetAlpha(1); self.scrollbar.frame:EnableMouse(true)
        end
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
            tile._demandTop,tile._demandHeight=layoutY,tileHeight
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
            I.InteractionBinding:Bind(tile, section, self.session, self.generation)
            tile.section = section
            tile.index = index
            tile.item = section.item
            tile.snapshotOwner = nil; tile:EnableMouse(true)
            local executor = _G.LycheeInternal and _G.LycheeInternal.ResultActionExecutor
            if executor then executor:ConfigureDragTarget(tile, tile.item) end
            tile.session, tile.generation = self.session, self.generation
            tile.extensionID = section.item and section.item._ext
            local title = homeLabel(section.title or section.text, "Lychee")
            setText(tile.category, homeLabel(section.meta, ""))
            local recovery=not recent and not section.item and section.enabled==false and section.meta~=nil and section.meta~=""
            if tile._recoveryLayout~=recovery then
                tile._recoveryLayout=recovery;tile._titleLayoutDirty=true
                if not recent and tile.title.SetMaxLines then tile.title:SetMaxLines(recovery and 1 or 2) end
            end
            setShown(tile.category,recent or recovery)
            tint(tile.title, color(section.enabled == false and "muted" or "text"))
            if tile._title ~= title or tile._titleLayoutDirty then
                setText(tile.title, title)
                if not recent and tile.title.GetStringHeight then
                    local height = math.max(14, math.min(recovery and 14 or 28, tile.title:GetStringHeight()))
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
            I.InteractionBinding:Bind(tile, nil, nil, nil)
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
        local maxScroll = math.max(0, height - (self.frame:GetHeight() or 0))
        self.scroll = math.min(self.scroll or 0, maxScroll)
        if self.frame.SetVerticalScroll and self._appliedScroll ~= self.scroll then
            self.frame:SetVerticalScroll(self.scroll)
            self._appliedScroll = self.scroll
        end
        self.scrollbar:SetRange(height, math.max(0, self.frame:GetHeight()), self.scroll)
        if not navigable(self.sections[self.selected]) then
            local firstEnabled
            for index = 1, #self.sections do if navigable(self.sections[index]) then firstEnabled = index; break end end
            self.selected = firstEnabled or 1
        end
        for index = 1, #self.tiles do self:RenderTileState(self.tiles[index]) end
        self:RefreshScrollRect()
        self:ReportDemand()
    end

    function view:FreezePresentation()
        if self.frozen then return end
        self.frozen = true
        Lychee.UI.Motion:Cancel(frame, true)
        frame:SetAlpha(0.8)
        self.scrollbar:StopDrag(); self.scrollbar.frame:EnableMouse(false)
        self.manage.frame:Hide()
        for _,tile in ipairs(self.tiles) do
            local section=tile.section
            local ref=section and (section.pinnedRef or section.recentRef)
            tile.snapshotOwner = tile.extensionID or ref and ref.providerID
            I.InteractionBinding:Cancel(tile)
            tile:EnableMouse(false)
        end
        self:ReleaseBindings(true)
    end

    function view:ReleaseBindings(preserveSnapshot)
        if self.frozen and not preserveSnapshot then
            self.frozen = nil
            frame:SetAlpha(1); self.scrollbar.frame:EnableMouse(true)
        end
        self.dirty = true
        self.sections = {}
        local executor = I.ResultActionExecutor
        for _,tile in ipairs(self.tiles) do
            if not preserveSnapshot then tile.snapshotOwner = nil end
            I.InteractionBinding:Bind(tile, nil, nil, nil)
            tile.section,tile.item,tile.index,tile._hovered=nil,nil,nil,nil
            tile.session,tile.generation,tile.extensionID=nil,nil,nil
            if executor then executor:ConfigureDragTarget(tile,nil) end
        end
    end

    view:EnsureCapacity(HOME_HEADER_COUNT, HOME_TILE_PREALLOCATE)

    return view
end

-- The page owns saved-content recovery and live bindings. Palette only supplies
-- the current search identity and controls which page is presented.
function HomeView:Invalidate() self.dirty = true end
function HomeView:GetContentHeight() return self.content:GetHeight() end

function HomeView:EnsureSavedCapacity()
    if InCombatLockdown and InCombatLockdown() then return false end
    local pins = I.UserPreferences and I.UserPreferences:GetPins() or {}
    self:EnsureCapacity(HOME_HEADER_COUNT, math.max(1, #pins) + math.max(1, #I.UserPreferences:GetRecent()) + 5)
    return true
end

local homeStatusText={pending="正在恢复…",disabled="插件已禁用",missing="找不到来源",deleted="目标已删除",
    incompatible="当前版本不兼容",timeout="恢复超时，请重新打开重试",dependency="依赖插件不可用",
    unavailable="目标暂不可用",failed="恢复失败，请重新打开重试"}
function HomeView:GetRecoveryText(ref)
    local session=I.Search and I.Search.Session
    local status=session and session.GetHomeStatus and session:GetHomeStatus(ref)
    local text=status and homeStatusText[status]
    return text and L[text] or ""
end
local function recoveryDisplay(self,ref,item,index)
    if item then return item.text,item.icon,item.text end
    -- Retain only display scalars from the same saved reference. Old result
    -- objects and actions are never rebound while the owner is recovering.
    local previous=self.sections[index]
    if previous and (previous.pinnedRef or previous.recentRef)~=ref then previous=nil end
    local status=self:GetRecoveryText(ref)
    -- Status placeholders must follow recovery state, not become saved titles.
    local recoveredTitle=ref.title or previous and previous.recoveredTitle
    return recoveredTitle or (status~="" and status or L["正在恢复…"]),
        ref.icon or previous and previous.icon,recoveredTitle
end
local function restore(self, allowExpand)
    local sections, preferences, session = {}, I.UserPreferences, I.Search.Session
    if preferences then
        for index, pin in ipairs(preferences:GetPins()) do
            local item=session:GetHomeItem(pin)
            local title,icon,recoveredTitle=recoveryDisplay(self,pin,item,#sections+1)
            sections[#sections + 1] = {id="pin:" .. index, groupID="pinned", groupTitle=L["已固定"],
                title=title, icon=icon, recoveredTitle=recoveredTitle,
                item=item, pinnedRef=pin, enabled=item~=nil, meta=item and item.kindTitle or self:GetRecoveryText(pin)}
        end
    end
    local refs=I.UserPreferences:GetRecent()
    for index=1,math.min(RECENT_LIMIT,#refs) do
        local ref=refs[index]
        if type(ref)=="table" and type(ref.providerID)=="string" and (type(ref.entryID)=="string" or type(ref.kind)=="string") then
            local item=session:GetHomeItem(ref)
            local title,icon,recoveredTitle=recoveryDisplay(self,ref,item,#sections+1)
            sections[#sections+1]={id="saved:"..ref.providerID..":"..index,groupID="recent",groupTitle=L["最近使用"],
                title=title,icon=icon,recoveredTitle=recoveredTitle,item=item,recentRef=ref,
                enabled=item~=nil,meta=item and item.kindTitle or self:GetRecoveryText(ref)}
        end
    end
    local broker = self.controller.secureBroker
    if broker then for index = 1, #self.tiles do broker:InvalidateRow(self.tiles[index]) end end
    self:SetSections(sections, allowExpand)
    self.dirty = false
end

-- Demand is stable identity plus existing layout geometry; the widget neither
-- loads addons nor owns Provider preparation, caches or directory knowledge.
function HomeView:GetVisibleReferences(limit)
    local out,seen={},{}
    local top,bottom=self.scroll or 0,(self.scroll or 0)+math.max(0,self.frame:GetHeight())
    for _,tile in ipairs(self.tiles) do
        local section=tile.section
        local ref=section and (section.pinnedRef or section.recentRef or section.item and section.item.ref)
        if ref and tile._demandTop and tile._demandTop<bottom and tile._demandTop+(tile._demandHeight or 0)>top and not seen[ref] then
            out[#out+1]=ref;seen[ref]=true
            if #out>=math.min(limit or 20,20) then break end
        end
    end
    return out
end
function HomeView:HasPresentation()
    return self.frame:IsShown() and #self.sections>0
end
function HomeView:InvalidateOwner(id,callback)
    if not id then return false end
    for _,tile in ipairs(self.tiles) do
        if tile.snapshotOwner==id then
            tile.snapshotOwner=nil;tile:Hide()
        elseif tile.extensionID==id then
            if callback then callback(tile)
            elseif self.controller and self.controller.InvalidateRow then self.controller:InvalidateRow(tile)
            else self:InvalidateRow(tile) end
        end
    end
    return true
end
function HomeView:ReportDemand()
    if self.frozen or not self.frame:IsShown() then return end
    local session=I.Search and I.Search.Session
    if session and session.HomeReferences and session:IsCurrent(self.session,self.generation) then session:HomeReferences(self:GetVisibleReferences(20)) end
end

function HomeView:Prepare(session, generation, allowExpand)
    if InCombatLockdown and InCombatLockdown() then self:Invalidate(); return false end
    self.session, self.generation = session, generation
    self:ReportDemand()
    for _,section in ipairs(self.sections) do
        local ref=section.pinnedRef or section.recentRef
        if ref and not section.item and I.Search.Session:GetHomeItem(ref) then self.dirty=true;break end
    end
    local rebound = self.dirty
    if rebound then
        restore(self, allowExpand)
        -- Already-loaded owners may resolve during demand reporting. Bind that
        -- synchronous completion once, without recursively refreshing layout.
        for _,section in ipairs(self.sections) do
            local ref=section.pinnedRef or section.recentRef
            if ref and not section.item and I.Search.Session:GetHomeItem(ref) then restore(self,allowExpand);break end
        end
    end
    local executor = I.ResultActionExecutor
    for index = 1, #self.sections do
        local tile = self.tiles[index]
        tile.session, tile.generation = session, generation
        -- At most one recovery attempt; a failed resolver must not recurse.
        if not rebound and executor and tile.section.item and not executor:IsRowCurrent(tile) then
            restore(self, allowExpand)
            break
        end
    end
    if executor then executor:PrepareVisibleRows(self.tiles) end
    return true
end

function HomeView:InvalidateRow(row)
    if not row or row.ownerView ~= self then return false end
    row.item = nil
    setShown(row, false)
    return true
end
