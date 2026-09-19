local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local Components = {}

local Theme = Lychee.UI.Theme

local function setShown(region, shown)
    shown = shown == true
    if region and region:IsShown() ~= shown then
        region:SetShown(shown)
    end
end

local function setText(label, value)
    value = value or ""
    if not label or label:GetText() == value then return false end
    label:SetText(value); return true
end

local function componentSetShown(self, shown) setShown(self.frame, shown) end
local function componentSetText(self, value) return setText(self.label, value) end

function Components:CreateBand(parent, options)
    options = options or {}
    local component = self:CreateSurface(parent, { allPoints=false, color=options.color })
    local frame = component.frame
    frame:SetHeight(options.height or 0)
    local edge = options.top == true and "TOP" or "BOTTOM"
    frame:SetPoint(edge.."LEFT", parent, edge.."LEFT", 0, 0)
    frame:SetPoint(edge.."RIGHT", parent, edge.."RIGHT", 0, 0)
    return component
end

function Components:CreateSurface(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    if options.allPoints ~= false then frame:SetAllPoints(parent) end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local component = { frame = frame, bg = bg }
    function component:SetColor(token)
        return Theme:SetColorTexture(self.bg, token)
    end
    component:SetColor(options.color)
    return component
end

function Components:CreateToggle(parent)
    local metrics=Theme.Metrics
    local frame=CreateFrame("Button",nil,parent)
    frame:SetSize(metrics.switchWidth,metrics.switchHeight)
    Theme:CreateRoundedSurface(frame,"switchOff",8)
    frame.bg=CreateFrame("Frame",nil,frame);frame.bg:SetAllPoints(frame)
    Theme:CreateRoundedSurface(frame.bg,"accent",8)
    frame.knob=CreateFrame("Frame",nil,frame);frame.knob:SetSize(14,14)
    Theme:CreateRoundedSurface(frame.knob,"text",6.9)
    -- Thumb must not inherit the accent overlay's fading alpha.
    if frame.knob.SetFrameLevel then frame.knob:SetFrameLevel(frame.bg:GetFrameLevel()+1) end
    function frame:SetChecked(checked,instant)
        checked=checked==true
        if self._enabled==checked and not instant then return end
        self._enabled=checked
        local x=checked and metrics.switchWidth-16 or 2
        local motion=Lychee.UI.Motion
        if motion then
            motion:Slide(self.knob,self,x,instant)
            motion:Alpha(self.bg,checked and 1 or 0,instant and 0 or 0.18)
        else
            if self.knob._slideX~=x then self.knob:ClearAllPoints();self.knob:SetPoint("LEFT",self,"LEFT",x,0);self.knob._slideX=x end
            if self.bg.SetAlpha then self.bg:SetAlpha(checked and 1 or 0) else setShown(self.bg,checked) end
        end
    end
    function frame:FinishMotion()
        if Lychee.UI.Motion then Lychee.UI.Motion:Cancel(self.knob,true);Lychee.UI.Motion:Cancel(self.bg,true) end
    end
    frame:SetScript("OnHide",function() frame:FinishMotion() end)
    return frame
end

function Components:CreateBrand(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    local iconSize = options.iconSize or 32
    local asset = options.texture or "Interface\\AddOns\\Lychee\\Media\\lychee-logo.tga"
    frame:SetSize(options.width or iconSize, options.height or iconSize)
    frame:SetPoint(options.point or "LEFT", parent, options.relativePoint or "LEFT", options.x or 16, options.y or 0)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    if type(icon.SetTexCoord) == "function" then icon:SetTexCoord(0, 1, 0, 1) end
    icon:SetTexture(asset)

    local label
    if options.label and options.label ~= "" then
        label = frame:CreateFontString(nil, "OVERLAY", options.font or "GameFontNormalLarge")
        label:SetPoint("LEFT", icon, "RIGHT", options.labelGap or 8, 0)
        setText(label, options.label)
        Theme:SetTextColor(label, options.textColor or "text")
    end

    local component = { frame = frame, icon = icon, label = label, _texture = asset, _label = options.label }
    function component:SetTexture(asset)
        if self._texture == asset then return false end
        self:StopMotion()
        self.icon:SetTexture(asset)
        self._texture = asset
        return true
    end
    function component:SetLabel(value)
        if self._label == value then return false end
        local changed = setText(self.label, value)
        self._label = value
        return changed
    end
    component.SetShown = componentSetShown
    function component:PlayMotion()
        local motion=Lychee.UI.Motion
        if motion then return motion:Brand(self.icon,self.frame,iconSize) end
        return false
    end
    function component:StopMotion()
        local motion=Lychee.UI.Motion
        if motion then motion:Cancel(self.icon,true) end
    end
    frame:SetScript("OnHide",function() component:StopMotion() end)
    return component
end

function Components:CreateButton(parent, options)
    options = options or {}
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(options.width or 24, options.height or 24)
    if options.point then frame:SetPoint(options.point, parent, options.relativePoint or options.point, options.x or 0, options.y or 0) end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local rounded
    if options.radius then
        bg:Hide()
        rounded=Theme:CreateRoundedSurface(frame,"transparent",options.radius)
    end
    local label = frame:CreateFontString(nil, "OVERLAY", options.font or "GameFontNormal")
    label:SetAllPoints()
    if label.SetJustifyH then label:SetJustifyH("CENTER") end
    local component = { frame = frame, bg = bg, label = label, _state = nil }
    function component:SetState(state)
        if InCombatLockdown and InCombatLockdown() then return false end
        state = state or "normal"
        if self.enabled == false then state = "disabled" end
        if self._state == state then return false end
        if Lychee.UI.Motion then Lychee.UI.Motion:Alpha(self.label,state=="pressed" and 0.70 or 1,Lychee.UI.Motion.durations.feedback) end
        local token = options.colors and options.colors[state]
        if not token then token = options.colors and options.colors.normal end
        if token then
            if rounded then rounded:SetColor(token) else Theme:SetColorTexture(self.bg, token) end
        end
        local textToken = options.textColors and options.textColors[state]
        if not textToken then textToken = options.textColors and options.textColors.normal end
        if textToken then Theme:SetTextColor(self.label, textToken) end
        if self.feedbackIcon and textToken then Theme:SetVertexColor(self.feedbackIcon,state=="normal" and "text" or textToken) end
        if self.strokes and textToken then
            for index = 1, #self.strokes do Theme:SetColorTexture(self.strokes[index], textToken) end
        end
        self._state = state
        return true
    end
    function component:RefreshPointerState()
        local hovered = self._hovered == true
        if frame.IsMouseOver then hovered = frame:IsMouseOver() end
        return self:SetState(frame:IsShown() and hovered and "hover" or "normal")
    end
    component.SetText = componentSetText
    function component:SetEnabled(enabled)
        enabled = enabled ~= false
        if self.enabled ~= enabled then
            if enabled and type(frame.Enable) == "function" then frame:Enable()
            elseif not enabled and type(frame.Disable) == "function" then frame:Disable() end
            self.enabled = enabled
        end
        return self:RefreshPointerState()
    end
    frame:SetScript("OnEnter", function() component._hovered = true; component:SetState("hover") end)
    frame:SetScript("OnLeave", function() component._hovered = false; component:SetState("normal") end)
    frame:SetScript("OnMouseDown", function() component:SetState("pressed") end)
    frame:SetScript("OnMouseUp", function() component:RefreshPointerState() end)
    frame:SetScript("OnHide", function() component._hovered = false; component:SetState("normal") end)
    if options.onClick then
        frame:SetScript("OnClick", function(...)
            if component.enabled ~= false then return options.onClick(...) end
        end)
    end
    component:SetText(options.text)
    component:SetState("normal")
    return component
end

function Components:CreateNavigationButton(parent, options)
    options = options or {}
    options.colors = { normal = "transparent" }
    options.textColors = { normal = options.primary and "accentHover" or options.muted and "textMuted" or "text", hover = "accentHover", pressed = "accentHover", disabled = "disabled" }
    local component = self:CreateButton(parent, options)
    if options.direction then
        component.strokes={}
        for index=1,2 do
            local stroke=component.frame:CreateTexture(nil,"ARTWORK")
            stroke:SetSize(6,1.25);component.strokes[index]=stroke
        end
        function component:SetDirection(direction)
            if self._direction==direction then return end
            self._direction=direction
            for index,stroke in ipairs(self.strokes) do
                local sign=index==1 and 1 or -1
                local vertical=direction=="down" or direction=="up"
                local x=vertical and sign*2 or 0
                local y=vertical and 0 or sign*2
                local angle=(direction=="left" or direction=="down") and sign*math.pi/4 or -sign*math.pi/4
                stroke:ClearAllPoints();stroke:SetPoint("CENTER",self.frame,"LEFT",8+x,y);stroke:SetRotation(angle)
            end
        end
        component:SetDirection(options.direction)
    end
    component._state=nil;component:RefreshPointerState()
    function component:SetSelected(selected)
        local token = selected and "text" or "textMuted"
        if options.textColors.normal == token then return end
        options.textColors.normal = token
        self._state = nil
        self:RefreshPointerState()
    end
    return component
end

-- Form fields own their surface state; page controllers retain validation and
-- commit behavior. One surface and three event callbacks, created only once.
function Components:StyleEditBox(input)
    if input._lycheeField then return input._lycheeField end
    Theme:CreateSurface(input,"field","fieldBorder")
    local style={focused=false,invalid=false}
    input._lycheeField=style
    function style:Apply()
        Theme:ApplySurface(input,"field",self.invalid and "danger" or self.focused and "accentHover" or "fieldBorder")
    end
    function style:SetInvalid(invalid)
        self.invalid=invalid==true;self:Apply()
    end
    input:SetScript("OnEditFocusGained",function() style.focused=true;style:Apply() end)
    input:SetScript("OnEditFocusLost",function() style.focused=false;style:Apply() end)
    input:SetScript("OnHide",function() style.focused=false;style.invalid=false;style:Apply() end)
    return style
end

-- One track and thumb per viewport. The only per-frame work is an active drag.
function Components:CreateScrollbar(parent, onChanged)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(12)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -2)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 2)
    frame:EnableMouse(true)
    local thumb = frame:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    Theme:SetColorTexture(thumb, "accent")
    local bar = { frame = frame, thumb = thumb, maximum = 0, value = 0, total = 0, viewport = 0 }
    function bar:StopDrag()
        if self.dragOffset == nil then return end
        self.dragOffset = nil
        frame:SetScript("OnUpdate", nil)
    end
    function bar:SetRange(total, viewport, value)
        self.total, self.viewport = total, viewport
        self.maximum = math.max(0, total - viewport)
        self.value = math.max(0, math.min(self.maximum, value or 0))
        local height = math.max(0, frame:GetHeight())
        local thumbHeight = math.min(height, 48, math.max(24, height * viewport / math.max(1, total)))
        self.travel = math.max(0, height - thumbHeight)
        local offset = self.maximum > 0 and self.travel * self.value / self.maximum or 0
        if self._height ~= thumbHeight then thumb:SetHeight(thumbHeight); self._height = thumbHeight end
        if self._offset ~= offset then
            thumb:ClearAllPoints(); thumb:SetPoint("TOP", frame, "TOP", 0, -offset); self._offset = offset
        end
        if self.maximum == 0 then self:StopDrag() end
        setShown(frame, self.maximum > 0 and height > 0)
    end
    function bar:SetValue(value)
        if InCombatLockdown and InCombatLockdown() then self:StopDrag(); return end
        value = math.max(0, math.min(self.maximum, value))
        if value ~= self.value then onChanged(value) end
    end
    local function cursorOffset()
        local _, y = GetCursorPosition()
        local top = frame:GetTop()
        return top and top - y / frame:GetEffectiveScale()
    end
    local function drag()
        if (InCombatLockdown and InCombatLockdown()) or not IsMouseButtonDown("LeftButton") then bar:StopDrag(); return end
        local offset = cursorOffset()
        if offset and bar.travel > 0 then bar:SetValue((offset - bar.dragOffset) / bar.travel * bar.maximum) end
    end
    frame:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or bar.maximum == 0 or (InCombatLockdown and InCombatLockdown()) then return end
        local offset = cursorOffset()
        if not offset then return end
        local relative = offset - bar._offset
        bar.dragOffset = relative >= 0 and relative <= bar._height and relative or bar._height / 2
        drag()
        if bar.dragOffset ~= nil then frame:SetScript("OnUpdate", drag) end
    end)
    frame:SetScript("OnMouseUp", function() bar:StopDrag() end)
    frame:SetScript("OnHide", function() bar:StopDrag() end)
    frame:SetScript("OnSizeChanged", function() bar:SetRange(bar.total, bar.viewport, bar.value) end)
    frame:Hide()
    return bar
end

function Components:CreateStatus(parent, options)
    options = options or {}
    local label = parent:CreateFontString(nil, "OVERLAY", options.font or "GameFontHighlightSmall")
    label:SetPoint("LEFT", parent, "LEFT", options.left or 16, 0)
    label:SetPoint("RIGHT", parent, "RIGHT", -(options.right or 16), 0)
    if label.SetJustifyH then label:SetJustifyH(options.justifyH or "LEFT") end
    Theme:SetTextColor(label, options.textColor or "textMuted")
    local component = { frame = label, label = label }
    component.SetText = componentSetText
    component:SetText(options.text or "")
    return component
end

function Components:CreateEmptyState(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local title = frame:CreateFontString(nil, "OVERLAY", options.titleFont or "GameFontNormalLarge")
    title:SetPoint("CENTER", frame, "CENTER", 0, options.titleY or 12)
    Theme:SetTextColor(title, options.titleColor or "text")
    Theme:SetFont(title, "title")
    local detail = frame:CreateFontString(nil, "OVERLAY", options.detailFont or "GameFontHighlightSmall")
    detail:SetPoint("TOP", title, "BOTTOM", 0, options.detailGap or -8)
    Theme:SetTextColor(detail, options.detailColor or "textMuted")
    Theme:SetFont(detail, "body")
    local component = { frame = frame, title = title, detail = detail }
    function component:SetTitle(value)
        return setText(self.title, value)
    end
    function component:SetDetail(value)
        return setText(self.detail, value)
    end
    component.SetShown = componentSetShown
    component:SetTitle(options.title or "")
    component:SetDetail(options.detail or "")
    component:SetShown(options.shown == true)
    return component
end

function Components:HideTooltip(owner)
    local tip = Components.tooltip
    if not tip or not tip._owner or owner and tip._owner~=owner then return end
    if Lychee.UI.Motion then Lychee.UI.Motion:Cancel(tip,true) end
    tip:SetScript("OnUpdate", nil)
    tip._cursorX, tip._cursorY = nil, nil
    tip._owner = nil
    tip:ClearAllPoints()
    setShown(tip, false)
end


local function floatingFrame(strata, mouse)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata(strata)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(mouse)
    Theme:CreateRoundedSurface(frame, "tooltip", 8)
    return frame
end

local function tooltipLabel(parent, role, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Theme:SetFont(label, role)
    Theme:SetTextColor(label, color)
    return label
end


local function tooltipLine(tip, index, text, y, gap)
    local label = tip.labels[index]
    text = text or ""
    setText(label, text)
    setShown(label, text ~= "")
    if text == "" then return y end
    y = y + (gap or 0)
    if label._y ~= y then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", tip, "TOPLEFT", 14, -y)
        label._y = y
    end
    return y + math.max(label:GetStringHeight(), index == 1 and 22 or index == 3 and 18 or 14)
end

local function scoreTable(tip, rows, y, headers)
    tip.scoreLabels=tip.scoreLabels or {}
    local count=rows and math.min(#rows,16) or 0
    for index=1,count+1 do
        if count==0 then break end
        local labels=tip.scoreLabels[index]
        if not labels then
            labels={};tip.scoreLabels[index]=labels
            for column=1,3 do
                local label=tooltipLabel(tip,index==1 and "meta" or "body",index==1 and "textDim" or "text")
                label:SetWidth(column==1 and 210 or column==2 and 98 or 64)
                label:SetJustifyH(column==1 and "LEFT" or "RIGHT")
                label:SetWordWrap(false)
                labels[column]=label
            end
        end
        local row=index>1 and rows[index-1]
        for column,label in ipairs(labels) do
            local value=row and row[column] or headers and headers[column] or ""
            setText(label,value);setShown(label,true)
            local top=y+(index-1)*25
            if label._y~=top then
                label:ClearAllPoints();label:SetPoint("TOPLEFT",tip,"TOPLEFT",column==1 and 14 or column==2 and 232 or 338,-top);label._y=top
            end
        end
    end
    for index=count>0 and count+2 or 1,#tip.scoreLabels do
        for _,label in ipairs(tip.scoreLabels[index]) do setShown(label,false);setText(label,"") end
    end
    return count>0 and y+(count+1)*25 or y
end

function Components:ShowTooltip(owner, content)
    if not owner or not owner:IsShown() or (InCombatLockdown and InCombatLockdown()) then return end
    local tip = Components.tooltip
    if not tip then
        tip = floatingFrame("TOOLTIP", false)
        tip:SetScript("OnHide", Components.HideTooltip)
        tip.labels = {}
        for index = 1, 5 do
            local label = tooltipLabel(tip, index == 1 and "tooltipTitle" or index == 3 and "body" or "tooltipMeta",
                index == 1 and "text" or index == 4 and "tooltipAccent" or index == 3 and "textMuted" or "textDim")
            label:SetJustifyH("LEFT")
            label:SetWordWrap(true)
            if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
            tip.labels[index] = label
        end
        tip:Hide()
        Components.tooltip = tip
        tip.UpdatePosition = function(tip)
            if not tip._owner or not tip._owner:IsShown() or (InCombatLockdown and InCombatLockdown()) then
                Components:HideTooltip()
                return
            end
            local x, y = GetCursorPosition()
            local scale = tip:GetEffectiveScale()
            x, y = x / scale + 12, y / scale + 12
            scale = UIParent:GetEffectiveScale() / scale
            if x + tip:GetWidth() > UIParent:GetWidth() * scale - 8 then x = x - tip:GetWidth() - 24 end
            if y + tip:GetHeight() > UIParent:GetHeight() * scale - 8 then y = y - tip:GetHeight() - 24 end
            x, y = math.max(8, x), math.max(8, y)
            if tip._cursorX ~= x or tip._cursorY ~= y then
                tip:ClearAllPoints()
                tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                tip._cursorX, tip._cursorY = x, y
            end
        end
    end
    local scale=Theme.scale or Theme.Metrics.uiScale
    if tip._scale~=scale then tip:SetScale(scale);tip._scale=scale end
    tip._owner = owner
    local title,kind,description,clickHint,dragHint,scoreRows=content.title,content.meta,content.description,content.hint,content.dragHint,content.rows
    local wide=type(scoreRows)=="table" and #scoreRows>0
    local width=wide and 416 or content.scrollable and 400 or 280
    if tip._width~=width then
        tip:SetWidth(width)
        for _,label in ipairs(tip.labels) do label:SetWidth(width-28) end
        tip._width=width
    end
    local y = tooltipLine(tip, 1, title, 14)
    y = tooltipLine(tip, 2, kind, y, 2)
    local top=y
    local label=tip.labels[3]
    if tip.reading then label:SetParent(tip);label:SetWidth(width-28);label._y=nil;tip.reading:Hide() end
    y = tooltipLine(tip, 3, wide and "" or description, y, 12)
    local limit=content.scrollable and math.max(60,math.min(240,UIParent:GetHeight()/scale-160))
    if content.scrollable and y-top>limit then
        local reading=tip.reading
        if not reading then
            reading=CreateFrame("ScrollFrame",nil,tip);tip.reading=reading
            reading.body=CreateFrame("Frame",nil,reading);reading:SetScrollChild(reading.body)
            reading.bar=Components:CreateScrollbar(reading,function(value) reading:SetVerticalScroll(value) end)
        end
        reading:ClearAllPoints();reading:SetPoint("TOPLEFT",tip,"TOPLEFT",14,-top-12);reading:SetSize(width-28,limit)
        label:SetParent(reading.body);label:ClearAllPoints();label:SetPoint("TOPLEFT");label:SetWidth(width-42);label._y=nil
        local height=label:GetStringHeight();reading.body:SetSize(width-42,height)
        reading:SetVerticalScroll(0);reading.bar:SetRange(height,limit,0);reading:Show()
        y=top+12+limit
    end
    if wide then y=scoreTable(tip,scoreRows,y+14,content.headers)
    elseif tip.scoreLabels then scoreTable(tip,nil,y) end
    y = tooltipLine(tip, 4, clickHint, y, 12)
    y = tooltipLine(tip, 5, dragHint, y, clickHint and clickHint ~= "" and 2 or 12)
    if tip:GetHeight() ~= y + 14 then tip:SetHeight(y + 14) end
    tip:UpdatePosition()
    if not tip:IsShown() then
        tip:Show()
        tip:SetScript("OnUpdate", tip.UpdatePosition)
        if Lychee.UI.Motion then Lychee.UI.Motion:Reveal(tip,"feedback") end
    end
end

function Components:ScrollTooltip(owner,delta)
    local tip=self.tooltip
    if not tip or tip._owner~=owner or not tip.reading or not tip.reading:IsShown() then return false end
    tip.reading.bar:SetValue(tip.reading:GetVerticalScroll()-delta*24)
    return true
end

-- Owned menus are deliberately outside Blizzard's globally reskinned menu pool.
function Components:HideActionMenu()
    local menu=self.actionMenu
    if not menu or not menu.owner then return false end
    menu.owner=nil;menu:Hide();menu:ClearAllPoints()
    for _,button in ipairs(menu.buttons) do
        button.callback=nil;button.pressed=nil;button.frame:Hide();button:SetText("")
    end
    return true
end

function Components:ShowActionMenu(owner, generator)
    if not owner or (InCombatLockdown and InCombatLockdown()) then return end
    self:HideActionMenu();self:HideTooltip()
    local menu=self.actionMenu
    if not menu then
        menu=floatingFrame("FULLSCREEN_DIALOG",true);self.actionMenu=menu
        menu.title=tooltipLabel(menu,"title","text")
        menu.title:SetPoint("TOPLEFT",20,-12);menu.title:SetPoint("TOPRIGHT",-20,-12)
        menu.title:SetJustifyH("LEFT");menu.title:SetWordWrap(false)
        menu.title:SetText("|TInterface\\AddOns\\Lychee\\Media\\MenuIcons\\game-menu.tga:14:14|t  ".._G.LycheeInternal.Locale["操作菜单"])
        menu.buttons={}
        function menu:CreateButton(title,callback)
            local index=self.count+1;assert(index<=18,"action menu capacity exceeded")
            self.count=index
            local button=self.buttons[index]
            if not button then
                button=Components:CreateNavigationButton(self,{width=144,height=30,text=""})
                Theme:SetFont(button.label,"body")
                button.label:ClearAllPoints();button.label:SetPoint("LEFT",12,0);button.label:SetPoint("RIGHT",-12,0)
                button.label:SetJustifyH("LEFT");button.label:SetWordWrap(false)
                local y=-36-(index-1)*30
                button.frame:SetPoint("TOPLEFT",8,y);button.frame:SetPoint("TOPRIGHT",-8,y)
                button.frame:HookScript("OnMouseDown",function(_,mouse) button.pressed=mouse=="LeftButton" and button.callback or nil end)
                button.frame:SetScript("OnClick",function()
                    local callback=button.callback
                    if not callback or button.pressed~=callback or not self.owner or not self.owner:IsShown() then return end
                    Components:HideActionMenu()
                    if not (InCombatLockdown and InCombatLockdown()) then return callback() end
                end)
                self.buttons[index]=button
            end
            button.callback=callback;button:SetText(title);button.frame:Show();button:RefreshPointerState()
            self.width=math.max(self.width,math.min(280,button.label:GetStringWidth()+24))
            return button
        end
    end
    menu.owner=owner;menu.count=0;menu.width=144
    if not owner._lycheeMenuHook then
        owner._lycheeMenuHook=true
        owner:HookScript("OnHide",function() if menu.owner==owner then Components:HideActionMenu() end end)
    end
    generator(owner,menu)
    if menu.count==0 then self:HideActionMenu();return end
    local height=44+menu.count*30
    menu:SetSize(menu.width+16,height)
    menu:SetScale(math.min(Theme.scale or Theme.Metrics.uiScale,(UIParent:GetHeight()-32)/height))
    local x,y=GetCursorPosition();local scale=menu:GetEffectiveScale()
    menu:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
    menu:Show()
    return menu
end

Lychee.UI.Components = Components
