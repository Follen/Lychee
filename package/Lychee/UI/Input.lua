local L = _G.LycheeInternal.Locale
local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local Input = {}
Input.__index = Input
local EMPTY_UI_PROPS = {}

local function setShown(region, shown)
    shown = shown == true
    if region and region:IsShown() ~= shown then region:SetShown(shown) end
end

local function localizedPlaceholder() return L["搜索技能、插件、命令…"] end

function Input:_ApplyVisualState()
    if self.visualFrozen then return false end
    local theme = Lychee.UI.Theme
    if not theme or not self.container then return false end
    local background, border, text
    if not self.enabled then
        background, border, text = "input", "border", "disabled"
    elseif self.focused then
        background, border, text = "inputFocus", "inputFocus", "text"
    elseif self.hovered then
        background, border, text = "inputHover", "inputHover", "text"
    else
        background, border, text = "input", "input", "text"
    end
    local stateKey = background .. ":" .. border .. ":" .. text
    if self._visualState == stateKey then return false end
    theme:ApplySurface(self.container, background, border)
    theme:SetTextColor(self.frame, text)
    theme:SetTextColor(self.placeholder, self.enabled and "textDim" or "disabled")
    theme:SetVertexColor(self.searchIcon, self.focused and "text" or (self.enabled and "textDim" or "disabled"))
    self._visualState = stateKey
    return true
end

function Input:Create(parent, focusController)
    local theme = Lychee.UI.Theme
    local height = theme and theme.Metrics.inputHeight or 44
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(height)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 64, -8)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -64, -8)
    container:EnableMouse(true)
    if theme then theme:CreateSurface(container, "input", "border") end

    local elements=Lychee.UI:Create(container,{type="Fragment",children={
        {type="Input",key="edit",props={variant="search",role="input",autoFocus=false,allPoints=true,textInsets={40,20,0,0},justifyV="MIDDLE"}},
        {type="Icon",key="icon",props={width=16,height=16,texture="Interface\\AddOns\\Lychee\\Media\\MenuIcons\\search.tga",point={"LEFT",container,"LEFT",14,0}}},
        {type="Text",key="placeholder",props={role="input",text=localizedPlaceholder(),height=height,justifyH="LEFT",justifyV="MIDDLE",points={{"LEFT",container,"LEFT",40,0},{"RIGHT",container,"RIGHT",-20,0}}}},
        {type="Text",key="hint",props={role="meta",visible=false}},
    }})
    assert(elements:Update(EMPTY_UI_PROPS))
    local edit,searchIcon,placeholder,hint=elements:Get("edit"),elements:Get("icon"),elements:Get("placeholder"),elements:Get("hint")

    local self = setmetatable({
        frame = edit,
        container = container,
        searchIcon = searchIcon,
        placeholder = placeholder,
        hint = hint,
        elements = elements,
        focus = focusController,
        enabled = true,
        focused = false,
        hovered = false,
        onChanged = nil,
        onSubmit = nil,
        onMove = nil,
    }, Input)
    edit:SetScript("OnTextChanged", function(box, userInput)
        if not elements.active then return end
        setShown(placeholder, (box:GetText() or "") == "")
        if self.onChanged then self.onChanged(box:GetText() or "", userInput == true) end
    end)
    edit:SetScript("OnEnterPressed", function()
        if self.onSubmit then self.onSubmit() end
    end)
    edit:SetScript("OnArrowPressed", function(_, key)
        if self.onMove and (key == "UP" or key == "DOWN") then self.onMove(key == "UP" and -1 or 1) end
    end)
    edit:SetScript("OnEscapePressed", function()
        local host = _G.LycheeInternal and _G.LycheeInternal.Host
        if host and host.PaletteController then host.PaletteController:Hide("escape") end
    end)
    edit:SetScript("OnEditFocusGained", function()
        self.focused = true
        self:_ApplyVisualState()
    end)
    edit:SetScript("OnEditFocusLost", function()
        self.focused = false
        self:_ApplyVisualState()
    end)
    container:SetScript("OnEnter", function()
        self.hovered = true
        self:_ApplyVisualState()
    end)
    container:SetScript("OnLeave", function()
        self.hovered = false
        self:_ApplyVisualState()
    end)
    container:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and self.enabled then self:Focus() end
    end)
    self:_ApplyVisualState()
    return self
end

function Input:SetChangedCallback(callback) self.onChanged = callback end
function Input:SetSubmitCallback(callback) self.onSubmit = callback end
function Input:SetMoveCallback(callback) self.onMove = callback end
function Input:SetText(text)
    text = text or ""
    if self.frame:GetText() ~= text then self.frame:SetText(text) end
    setShown(self.placeholder, text == "")
end
function Input:GetText() return self.frame:GetText() or "" end
function Input:Focus() return self.focus and self.focus:Set(self.frame) end
function Input:ClearFocus() if self.frame.ClearFocus then self.frame:ClearFocus() end end
function Input:SetEnabled(enabled)
    enabled = enabled ~= false
    if self.enabled == enabled then return false end
    self.enabled = enabled
    if enabled and self.frame.Enable then self.frame:Enable()
    elseif not enabled and self.frame.Disable then self.frame:Disable() end
    if not enabled then self:ClearFocus() end
    self:_ApplyVisualState()
    return true
end
function Input:IsEnabled() return self.enabled end
-- Release keyboard ownership immediately while keeping the exit's appearance.
function Input:SetVisualFrozen(frozen)
    self.visualFrozen=frozen==true
    if not self.visualFrozen then self:_ApplyVisualState() end
end
function Input:Show() self.elements:Update(EMPTY_UI_PROPS);setShown(self.placeholder,self:GetText()=="");self.container:Show() end
function Input:Hide() self.elements:Release("hide");self.container:Hide();self:SetVisualFrozen(false) end

Lychee.UI.Input = Input
