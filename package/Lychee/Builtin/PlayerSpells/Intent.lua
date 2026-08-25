local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:BuildHandler() return {type="builtin.player-spells.open",version=1,handle=function(payload) return {ok=true,transition={type="builtin-panel",panelID="spell-detail",state={spellID=payload.spellID}}} end} end
