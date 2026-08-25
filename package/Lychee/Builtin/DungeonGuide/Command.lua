local I = _G.LycheeInternal
local P=I.Builtin.DungeonGuide
function P:BuildCommand() return {id="dungeon-guide",title="大秘境怪物",aliases={"怪物","小怪","boss"},priority=70,match={type="ambient",minLength=1,maxLength=64},presentation="dynamic-list",resolve=function(q) return P:Query(q) end,itemIntent=function(item) return {type="builtin.dungeon-guide.open",version=1,payload={creatureID=item.payload.creatureID}} end} end
function P:BuildHandler() return {type="builtin.dungeon-guide.open",version=1,handle=function(payload) return {ok=true,transition={type="builtin-panel",panelID="creature-detail",state={creatureID=payload.creatureID}}} end} end
function P:BuildPanel() return {id="creature-detail",create=function(state) return {creatureID=state.creatureID} end} end
