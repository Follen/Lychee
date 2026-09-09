local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
function I.Builtin:Init()
    if self._initialized then return end
    self._initialized=true
    if self.PlayerSpells and self.PlayerSpells.Init then self.PlayerSpells:Init() end
    if self.Mounts then self.Mounts:Init() end
    if self.Crests then self.Crests:Init() end
    if self.GameMenus then self.GameMenus:Init() end
    if self.Bosses then self.Bosses:Init() end
    if self.GreatVault then self.GreatVault:Init() end
end
