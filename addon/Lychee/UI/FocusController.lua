local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}

local FocusController = {}
FocusController.__index = FocusController

function FocusController:New()
    return setmetatable({ owner = nil, previous = nil }, self)
end

function FocusController:Capture(previous)
    if self.previous == nil then
        self.previous = previous or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
    end
end

function FocusController:Set(editBox)
    if not editBox then return false end
    self:Capture()
    self.owner = editBox
    editBox:SetFocus()
    return true
end

function FocusController:Clear()
    if self.owner and self.owner.ClearFocus then self.owner:ClearFocus() end
    self.owner = nil
end

function FocusController:Restore()
    local previous = self.previous
    self:Clear()
    self.previous = nil
    if previous and previous.SetFocus and (not previous.IsShown or previous:IsShown()) then
        pcall(previous.SetFocus, previous)
    end
end

Lychee.UI.FocusController = FocusController
