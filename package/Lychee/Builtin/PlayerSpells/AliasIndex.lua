local I = _G.LycheeInternal
local A={bySpell={}}
I.Builtin=I.Builtin or {}; I.Builtin.PlayerSpells=I.Builtin.PlayerSpells or {}; I.Builtin.PlayerSpells.AliasIndex=A
function A:Add(spellID,aliases) self.bySpell[spellID]=self.bySpell[spellID] or {}; local a=self.bySpell[spellID]; for i=1,#aliases do a[#a+1]=aliases[i] end end
function A:Get(spellID) return self.bySpell[spellID] or {} end
