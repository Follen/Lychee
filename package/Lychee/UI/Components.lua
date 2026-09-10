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
    local label = frame:CreateFontString(nil, "OVERLAY", options.font or "GameFontNormal")
    label:SetAllPoints()
    if label.SetJustifyH then label:SetJustifyH("CENTER") end
    local component = { frame = frame, bg = bg, label = label, _state = nil, _text = nil }
    local function applyState(self, state)
        state = state or "normal"
        if self.enabled == false then state = "disabled" end
        if self._state == state then return false end
        self._state = state
        local token = options.colors and options.colors[state]
        if not token then token = options.colors and options.colors.normal end
        if token then setColorTexture(self.bg, token) end
        local textToken = options.textColors and options.textColors[state]
        if not textToken then textToken = options.textColors and options.textColors.normal end
        if textToken then setTextColor(self.label, textToken) end
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

local actionMenuInset = { left = 4, right = 4, top = 4, bottom = 4 }
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
    background:SetColorTexture(unpack(colors.tooltip))
end

local function initializeActionMenuButton(button)
    local theme = getTheme()
    local label = button.fontString
    label:SetFont(STANDARD_TEXT_FONT, theme.FontSizes.body, "")
    label:SetShadowOffset(0, 0)
    label:SetTextColor(unpack(theme.Colors.text))
    local width = math.max(132, math.min(280, label:GetStringWidth() + 20))
    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "LEFT", 12, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -12, 0)
    label:SetHeight(20)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    button.highlight:SetBlendMode("BLEND")
    button.highlight:SetColorTexture(unpack(theme.Colors.surfaceSelected))
    return width, 28
end

function Components:StyleActionMenuOwner(owner)
    if owner.menuMixin ~= actionMenuStyle then owner.menuMixin = actionMenuStyle end
end

function Components:StyleActionMenuButton(description)
    description:AddInitializer(initializeActionMenuButton)
end

Lychee.UI.Components = Components
