local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local Components = {}

local function getTheme()
    return Lychee.UI and Lychee.UI.Theme
end

local function setShown(region, shown)
    shown = shown == true
    if region and type(region.IsShown) == "function" and region:IsShown() ~= shown then
        region:SetShown(shown)
    end
end

local function setText(label, value)
    value = value or ""
    if label and type(label.GetText) == "function" and label:GetText() == value then return false end
    if label and type(label.SetText) == "function" then label:SetText(value); return true end
    return false
end

local function setColorTexture(texture, token)
    local theme = getTheme()
    if theme and type(theme.SetColorTexture) == "function" then
        return theme:SetColorTexture(texture, token)
    end
    return false
end

local function setTextColor(label, token)
    local theme = getTheme()
    if theme and type(theme.SetTextColor) == "function" then
        return theme:SetTextColor(label, token)
    end
    return false
end

local function setTexture(texture, asset)
    if not texture or type(texture.SetTexture) ~= "function" or texture._lycheeTextureAsset == asset then return false end
    texture:SetTexture(asset)
    texture._lycheeTextureAsset = asset
    return true
end

local function anchorBand(frame, parent, top)
    if top then
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    else
        frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end
end

function Components:CreateBand(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(options.height or 0)
    anchorBand(frame, parent, options.top == true)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local component = { frame = frame, bg = bg, _color = false }
    function component:SetColor(token)
        if self._color == token then return false end
        local changed = setColorTexture(self.bg, token)
        self._color = token
        return changed
    end
    component:SetColor(options.color)
    return component
end

function Components:CreateSurface(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    if options.allPoints ~= false then frame:SetAllPoints(parent) end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local component = { frame = frame, bg = bg, _color = false }
    function component:SetColor(token)
        if self._color == token then return false end
        local changed = setColorTexture(self.bg, token)
        self._color = token
        return changed
    end
    component:SetColor(options.color)
    return component
end

function Components:CreateToggle(parent)
    local theme=getTheme();local metrics=theme.Metrics
    local frame=CreateFrame("Button",nil,parent)
    frame:SetSize(metrics.switchWidth,metrics.switchHeight)
    theme:CreateRoundedSurface(frame,"switchOff",8)
    frame.bg=CreateFrame("Frame",nil,frame);frame.bg:SetAllPoints(frame)
    theme:CreateRoundedSurface(frame.bg,"accent",8)
    frame.knob=CreateFrame("Frame",nil,frame);frame.knob:SetSize(14,14)
    theme:CreateRoundedSurface(frame.knob,"text",6.9)
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
    setTexture(icon, asset)

    local label
    if options.label and options.label ~= "" then
        label = frame:CreateFontString(nil, "OVERLAY", options.font or "GameFontNormalLarge")
        label:SetPoint("LEFT", icon, "RIGHT", options.labelGap or 8, 0)
        setText(label, options.label)
        setTextColor(label, options.textColor or "text")
    end

    local component = { frame = frame, icon = icon, label = label, _texture = asset, _label = options.label }
    function component:SetTexture(asset)
        if self._texture == asset then return false end
        self._texture = asset
        return setTexture(self.icon, asset)
    end
    function component:SetLabel(value)
        if self._label == value then return false end
        self._label = value
        return setText(self.label, value)
    end
    function component:SetShown(shown) setShown(self.frame, shown) end
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
        rounded=getTheme():CreateRoundedSurface(frame,"transparent",options.radius)
    end
    local label = frame:CreateFontString(nil, "OVERLAY", options.font or "GameFontNormal")
    label:SetAllPoints()
    if label.SetJustifyH then label:SetJustifyH("CENTER") end
    local component = { frame = frame, bg = bg, label = label, _state = nil, _text = nil }
    local function applyState(self, state)
        state = state or "normal"
        if self.enabled == false then state = "disabled" end
        if self._state == state then return false end
        self._state = state
        if Lychee.UI.Motion then Lychee.UI.Motion:Alpha(self.label,state=="pressed" and 0.70 or 1,Lychee.UI.Motion.durations.feedback) end
        local token = options.colors and options.colors[state]
        if not token then token = options.colors and options.colors.normal end
        if token then
            if rounded then rounded:SetColor(token) else setColorTexture(self.bg, token) end
        end
        local textToken = options.textColors and options.textColors[state]
        if not textToken then textToken = options.textColors and options.textColors.normal end
        if textToken then setTextColor(self.label, textToken) end
        if self.strokes and textToken then
            for index = 1, #self.strokes do setColorTexture(self.strokes[index], textToken) end
        end
        return true
    end
    function component:SetState(state) return applyState(self, state) end
    function component:RefreshPointerState()
        local hovered = self._hovered == true
        if frame.IsMouseOver then hovered = frame:IsMouseOver() end
        return self:SetState(frame:IsShown() and hovered and "hover" or "normal")
    end
    function component:SetText(value)
        if self._text == value then return false end
        self._text = value
        return setText(self.label, value)
    end
    function component:SetEnabled(enabled)
        enabled = enabled ~= false
        if self.enabled ~= enabled then
            self.enabled = enabled
            if enabled and type(frame.Enable) == "function" then frame:Enable()
            elseif not enabled and type(frame.Disable) == "function" then frame:Disable() end
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
    elseif options.underline then
        local line=component.frame:CreateTexture(nil,"ARTWORK");component.strokes={line}
        line:SetHeight(1);line:SetPoint("BOTTOMRIGHT",component.label,"BOTTOMRIGHT",0,4)
        local set=component.SetText
        function component:SetText(value)
            local changed=set(self,value)
            local measured=self.label.GetStringWidth and self.label:GetStringWidth() or 32
            line:SetWidth(measured);return changed
        end
        component:SetText(options.text)
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
    local theme=getTheme()
    theme:CreateSurface(input,"field","fieldBorder")
    local style={focused=false,invalid=false}
    input._lycheeField=style
    function style:Apply()
        theme:ApplySurface(input,"field",self.invalid and "danger" or self.focused and "accentHover" or "fieldBorder")
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
    setColorTexture(thumb, "accent")
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
    setTextColor(label, options.textColor or "textMuted")
    local component = { frame = label, label = label, _text = nil }
    function component:SetText(value)
        if self._text == value then return false end
        self._text = value
        return setText(self.label, value)
    end
    component:SetText(options.text or "")
    return component
end

function Components:CreateEmptyState(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local title = frame:CreateFontString(nil, "OVERLAY", options.titleFont or "GameFontNormalLarge")
    title:SetPoint("CENTER", frame, "CENTER", 0, options.titleY or 12)
    setTextColor(title, options.titleColor or "text")
    local theme = getTheme()
    if theme then theme:SetFont(title, "title") end
    local detail = frame:CreateFontString(nil, "OVERLAY", options.detailFont or "GameFontHighlightSmall")
    detail:SetPoint("TOP", title, "BOTTOM", 0, options.detailGap or -8)
    setTextColor(detail, options.detailColor or "textMuted")
    if theme then theme:SetFont(detail, "body") end
    local component = { frame = frame, title = title, detail = detail, _title = nil, _detail = nil }
    function component:SetTitle(value)
        if self._title == value then return false end
        self._title = value
        return setText(self.title, value)
    end
    function component:SetDetail(value)
        if self._detail == value then return false end
        self._detail = value
        return setText(self.detail, value)
    end
    function component:SetShown(shown) setShown(self.frame, shown) end
    component:SetTitle(options.title or "")
    component:SetDetail(options.detail or "")
    component:SetShown(options.shown == true)
    return component
end

local actionMenuInset = { left = 6, right = 6, top = 6, bottom = 6 }
local actionMenuPadding = { width = 0, height = 0 }
local actionMenuStyle = {}
function actionMenuStyle:GetInset() return actionMenuInset end
function actionMenuStyle:GetChildExtentPadding() return actionMenuPadding end
function actionMenuStyle:Generate()
    local colors = getTheme().Colors
    -- Native menu attachments are pooled and reset by its compositor. Apply
    -- directly here: cached theme stamps must not survive pool reinitialization.
    local border = self:AttachTexture()
    border:SetAllPoints()
    border:SetDrawLayer("BACKGROUND", -1)
    border:SetColorTexture(unpack(colors.border))
    local background = self:AttachTexture()
    background:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
    background:SetDrawLayer("BACKGROUND", 0)
    background:SetColorTexture(unpack(colors.window))
end

local function initializeActionMenuButton(button)
    local theme = getTheme()
    local label = button.fontString
    label:SetFont(STANDARD_TEXT_FONT, theme.FontSizes.body, "")
    label:SetShadowOffset(0, 0)
    label:SetTextColor(unpack(theme.Colors.text))
    local width = math.max(156, math.min(280, label:GetStringWidth() + 24))
    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "LEFT", 12, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -12, 0)
    label:SetHeight(20)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    button.highlight:SetBlendMode("BLEND")
    button.highlight:SetColorTexture(0, 0, 0, 0)
    return width, 32
end

local function enterActionMenu(button)
    button.fontString:SetTextColor(unpack(getTheme().Colors.accentHover))
end

local function leaveActionMenu(button)
    button.fontString:SetTextColor(unpack(getTheme().Colors.text))
end

function Components:StyleActionMenuOwner(owner)
    if owner.menuMixin ~= actionMenuStyle then owner.menuMixin = actionMenuStyle end
end

function Components:StyleActionMenuButton(description)
    description:AddInitializer(initializeActionMenuButton)
    description:SetOnEnter(enterActionMenu)
    description:SetOnLeave(leaveActionMenu)
end

Lychee.UI.Components = Components
