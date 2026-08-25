local I = _G.LycheeInternal
local M=I.Builtin.PlayerSpells
function M:BuildPanel()
    return {
        id = "spell-detail",
        create = function()
            local panel = {}
            function panel:Mount(context, state)
                self.context, self.spellID = context, state and state.spellID
                return true
            end
            function panel:Update(state) self.spellID = state and state.spellID or self.spellID end
            function panel:Unmount() self.context = nil end
            function panel:Dispose() self:Unmount(); self.spellID = nil end
            return panel
        end,
    }
end
