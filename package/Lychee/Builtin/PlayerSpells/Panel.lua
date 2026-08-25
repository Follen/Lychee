local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:BuildPanel() return {id="spell-detail",create=function(state) return {spellID=state.spellID} end} end
