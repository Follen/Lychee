local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:BuildCommand()
    return {id="player-spells",title="技能",aliases={"spell","法术"},priority=80,entitySearch=false,match={type="ambient",minLength=1,maxLength=64},presentation="dynamic-list",resolve=function(q) return M.Provider:Query(q) end,itemIntent=function(item,actionID) return {type="builtin.player-spells.open",version=1,payload={spellID=item.payload.spellID,actionID=actionID}} end}
end
