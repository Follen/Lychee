-- A pooled target's press belongs to its binding, never to its screen position.
-- Scalars only on bind/press; no timers, closures or per-click tables.
local B = {}
_G.LycheeInternal.InteractionBinding = B

function B:Invalidate(owner)
    owner._bindingRevision = (owner._bindingRevision or 0) + 1
end
function B:Bind(owner, identity, session, generation)
    if owner._bindingIdentity ~= identity or owner._bindingSession ~= session or owner._bindingGeneration ~= generation then
        self:Invalidate(owner)
        owner._bindingIdentity, owner._bindingSession, owner._bindingGeneration = identity, session, generation
    end
end
function B:Cancel(target)
    target._pressOwner, target._pressRevision, target._pressButton = nil, nil, nil
end
function B:Press(target, owner, mouseButton)
    self:Cancel(target)
    if not owner or owner._bindingIdentity == nil then return false end
    if target.IsShown and not target:IsShown() then return false end
    if target.IsEnabled and not target:IsEnabled() then return false end
    target._pressOwner, target._pressRevision, target._pressButton = owner, owner._bindingRevision, mouseButton or "LeftButton"
    return true
end
function B:Consume(target, owner, mouseButton)
    local valid = owner and target._pressOwner == owner and owner._bindingIdentity ~= nil
        and target._pressRevision == owner._bindingRevision and target._pressButton == (mouseButton or "LeftButton")
    self:Cancel(target)
    if target.IsShown and not target:IsShown() then return false end
    if target.IsEnabled and not target:IsEnabled() then return false end
    return valid == true
end

local function down(target, button) B:Press(target, target._pressBindingOwner, button) end
local function hidden(target)
    B:Cancel(target)
    if target._pressBindingOwner == target then B:Invalidate(target) end
end
function B:Attach(target, owner)
    target._pressBindingOwner = owner
    target:SetScript("OnMouseDown", down)
    target:SetScript("OnHide", hidden)
end
