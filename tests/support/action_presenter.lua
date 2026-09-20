-- Minimal presenter contract for tests that intentionally do not load the UI.
return function(p)
    function p:GetActionIdentity() return self.session,self.generation end
    function p:IsActionContextCurrent(session,generation)
        return self.visible and not self.settingsOpen and (session==nil or self.session==session)
            and (generation==nil or self.generation==generation)
    end
    function p:GetSecureBroker() return self.secureBroker end
    function p:SetActionMenu(menu) self.actionMenu=menu end
    function p:ClearActionMenu(menu) if self.actionMenu==menu then self.actionMenu=nil end end
    return p
end
