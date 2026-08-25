local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
function I.Builtin:Init()
    if self._initialized then return end
    self._initialized=true
    if self.PlayerSpells and self.PlayerSpells.Init then self.PlayerSpells:Init() end
    if self.DungeonGuide and self.DungeonGuide.Init then self.DungeonGuide:Init() end
end
