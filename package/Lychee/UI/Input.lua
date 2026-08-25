local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local Input = {}
Input.__index = Input

function Input:Create(parent, focusController)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetHeight(28)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
    edit:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -12)
    local self = setmetatable({ frame = edit, focus = focusController, onChanged = nil, onSubmit = nil }, Input)
    edit:SetScript("OnTextChanged", function(box, userInput)
        if self.onChanged then self.onChanged(box:GetText() or "", userInput == true) end
    end)
    edit:SetScript("OnEnterPressed", function()
        if self.onSubmit then self.onSubmit() end
    end)
    edit:SetScript("OnEscapePressed", function()
        if Lychee.UI.PaletteController then Lychee.UI.PaletteController:Hide("escape") end
    end)
    return self
end

function Input:SetChangedCallback(callback) self.onChanged = callback end
function Input:SetSubmitCallback(callback) self.onSubmit = callback end
function Input:SetText(text) self.frame:SetText(text or "") end
function Input:GetText() return self.frame:GetText() or "" end
function Input:Focus() return self.focus and self.focus:Set(self.frame) end
function Input:ClearFocus() if self.frame.ClearFocus then self.frame:ClearFocus() end end
function Input:Show() self.frame:Show() end
function Input:Hide() self.frame:Hide() end
