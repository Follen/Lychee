local I = _G.LycheeInternal
local M = {}
I.ProviderManagement = M
local EMPTY = {} -- Host-private read-only configuration fallback.

local function current(id, token)
    local entry = I.Providers.entries[id]
    local state = entry and I.Registry.entries[id]
    if not entry or not state or state.state == "removed" or state.state == "retiring"
        or token ~= nil and entry.instanceToken ~= token then return nil end
    return entry, state
end

local function failure(code, id)
    return nil, {code=code, providerID=id, retryable=code=="UPDATE_IN_PROGRESS"}
end

local function writable(id, token)
    if token == nil then return failure("STALE_HANDLE", id) end
    local entry, state = current(id, token)
    if not entry then return failure("STALE_HANDLE", id) end
    if InCombatLockdown and InCombatLockdown() then return failure("COMBAT_LOCKED", id) end
    if entry.updating then return failure("UPDATE_IN_PROGRESS", id) end
    return entry, state
end

local function summary(out, id, entry, state)
    local definition = entry.definition
    out.id, out.instanceToken = id, entry.instanceToken
    out.title = I.Locale and I.Locale:Resolve(definition.title, id) or definition.title or id
    out.version = definition.version
    out.description,out.icon,out.order=definition.description,definition.icon,definition.order or 100
    local source=definition.source
    out.sourceID=source and source.id or id
    out.sourceTitle=source and (source.title or source.id) or out.title
    out.userEnabled, out.ownerEnabled = state.userEnabled, state.ownerEnabled
    out.lifecycle, out.effectiveEnabled = state.state, state.state == "enabled"
    out.status = state.incompatible and "incompatible" or state.state == "pending" and "pending"
        or state.userEnabled == false and "user-disabled" or state.ownerEnabled == false and "owner-disabled" or nil
    out.statusReason=state.ownerEnabled==false and entry.unavailableReason or nil
    return out
end

-- The visible management page owns this bounded-by-provider-count list. Reuse
-- its records; never retain another list or expose live runtime entries to UI.
function M:FillList(out)
    local count = 0
    for id, entry in pairs(I.Providers.entries) do
        local state = I.Registry.entries[id]
        if state and state.state ~= "removed" and state.state ~= "retiring" then
            count = count + 1
            local row = out[count] or {}; out[count] = row
            row.pin, row.pinIndex, row.item = nil, nil, nil
            summary(row, id, entry, state)
        end
    end
    for index = #out, count + 1, -1 do out[index] = nil end
    return out
end

function M:IsCurrent(id, token)
    return token ~= nil and current(id, token) ~= nil
end

function M:GetInstance(id)
    local entry = current(id)
    return entry and entry.instanceToken
end

-- Detail snapshots are caller-owned and reused by the single detail page.
function M:Read(id, token, out)
    local entry, state = current(id, token)
    if not entry then return failure("STALE_HANDLE", id) end
    out = summary(out or {}, id, entry, state)
    out.sample=nil
    local scope = entry.definition.scope or EMPTY
    local products = out.products or {}; out.products = products
    if scope.products then
        for index = 1, #scope.products do products[index] = scope.products[index] end
        for index = #products, #scope.products + 1, -1 do products[index] = nil end
    else
        products[1] = scope.product or "retail"
        for index = #products, 2, -1 do products[index] = nil end
    end
    return out
end

function M:GetConfiguration(id, token)
    if not self:IsCurrent(id, token) then return nil end
    local entry = I.Providers.entries[id]
    local policy = I.Search.ProviderPolicy
    if not policy then return true, EMPTY, EMPTY end
    -- Validated arrays are read-only to Host views. Writes always pass through
    -- ProviderPolicy, which owns role persistence and routing invalidation.
    return policy:Configuration(id, entry.definition)
end

function M:SetUserEnabled(id, token, enabled)
    local entry, err = writable(id, token)
    if not entry then return nil, err end
    local ok, why = I.Registry:SetUserEnabled(id, enabled)
    if not ok then return nil, why end
    -- Enable/disable callbacks can unregister and replace a Provider.
    if not self:IsCurrent(id, token) then return failure("STALE_HANDLE", id) end
    return true
end

function M:ToggleUserEnabled(id, token)
    local entry, state = writable(id, token)
    if not entry then return nil, state end
    return self:SetUserEnabled(id, token, not state.userEnabled)
end

function M:SetConfiguration(id, token, global, prefixes, keywords)
    local entry, err = writable(id, token)
    if not entry then return nil, err end
    local ok, why = I.Search.ProviderPolicy:SetConfiguration(id, global, prefixes, keywords)
    if not ok then return nil, why end
    if not self:IsCurrent(id, token) then return failure("STALE_HANDLE", id) end
    return true
end

function M:ResetConfiguration(id, token)
    local entry, err = writable(id, token)
    if not entry then return nil, err end
    local ok, why = I.Search.ProviderPolicy:Reset(id)
    if not ok then return nil, why end
    if not self:IsCurrent(id, token) then return failure("STALE_HANDLE", id) end
    return true
end
