local I = _G.LycheeInternal
local M = {}
I.ProviderManagement = M
local EMPTY = {} -- Host-private read-only configuration fallback.

-- At most one small view wrapper per validated declaration (discovery caps 256).
local coldEntries = {}
local function cold(id)
    local row = I.AddonDiscovery and I.AddonDiscovery:Get(id)
    if not row or row.reason or not row.selected then coldEntries[id]=nil;return end
    local entry = coldEntries[id]
    if not entry or entry.definition ~= row then
        entry={definition=row,instanceToken=row,cold=true,state={state="pending",ownerEnabled=true}}
        coldEntries[id]=entry
    end
    entry.state.userEnabled=I.CharacterStore:ProviderSearchEnabled(id)
    return entry,entry.state
end
local function current(id, token)
    local entry = I.Providers:BorrowInstance(id)
    local state = entry and I.Registry.entries[id]
    if not entry then entry,state=cold(id) end
    if not entry or not state or state.state == "removed" or state.state == "retiring"
        or token ~= nil and entry.instanceToken ~= token then return nil end
    if not I.Search.RuntimeIdentity:MatchesScope(entry.definition.scope) then return nil end
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

local L = I.Locale

local function summary(out, id, entry, state)
    local definition = entry.definition
    out.id, out.instanceToken = id, entry.instanceToken
    out.title = I.Locale and I.Locale:Resolve(definition.title, id) or definition.title or id
    out.version, out.searchable = definition.version, definition.searchable ~= false
    local order,description,icon
    if I.ProjectProviders then order,description,icon=I.ProjectProviders:Presentation(id) end
    out.builtin = order ~= nil
    out.order = order or 100
    out.description = definition.description or description
    out.icon = definition.icon or icon
    out.sourceID = out.builtin and "builtin" or "external"
    out.sourceTitle = L[out.builtin and "内置功能" or "第三方"]
    out.statusReason = state.ownerEnabled == false and entry.unavailableReason or nil
    out.userEnabled, out.ownerEnabled = state.userEnabled, state.ownerEnabled
    out.lifecycle, out.effectiveEnabled = state.state, state.state == "enabled"
    out.status = state.incompatible and "incompatible" or state.state == "pending" and "pending"
        or state.userEnabled == false and "user-disabled" or state.ownerEnabled == false and "owner-disabled" or nil
    return out
end

-- The visible management page owns this bounded-by-provider-count list. Reuse
-- its records; never retain another list or expose live runtime entries to UI.
function M:FillList(out)
    local count = 0
    for id, entry in I.Providers:Instances() do
        local state = I.Registry.entries[id]
        if not (I.ProjectProviders and I.ProjectProviders:IsRequired(id)) and state and state.state ~= "removed" and state.state ~= "retiring"
            and I.Search.RuntimeIdentity:MatchesScope(entry.definition.scope) then
            count = count + 1
            local row = out[count] or {}; out[count] = row
            row.pin, row.pinIndex, row.item = nil, nil, nil
            summary(row, id, entry, state)
        end
    end
    for _, definition in ipairs(I.AddonDiscovery and I.AddonDiscovery:Definitions() or EMPTY) do
        if not I.Providers:BorrowInstance(definition.id) then
            local entry,state=cold(definition.id)
            if entry and I.Search.RuntimeIdentity:MatchesScope(entry.definition.scope) then
                count=count+1
                local row=out[count] or {};out[count]=row
                row.pin,row.pinIndex,row.item=nil,nil,nil
                summary(row,definition.id,entry,state)
            end
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
    local first = entry.records and entry.records[1]
    out.sample = first and type(first.title) == "string" and #first.title <= 42
        and not first.title:find("|", 1, true) and first.title or nil
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
    local entry = current(id, token)
    local policy = I.Search.ProviderPolicy
    if not policy then return true, EMPTY, EMPTY end
    -- Validated arrays are read-only to Host views. Writes always pass through
    -- ProviderPolicy, which owns role persistence and routing invalidation.
    return policy:Configuration(id, entry.definition)
end

function M:SetUserEnabled(id, token, enabled)
    local entry, err = writable(id, token)
    if not entry then return nil, err end
    if type(enabled)~="boolean" then return failure("INVALID_SCHEMA",id) end
    if entry.cold then
        I.CharacterStore:DisabledProviders()[id]=not enabled
        if I.Search.ProviderPolicy then I.Search.ProviderPolicy:Invalidate() end
        if I.Search.Session then I.Search.Session:SourceChanged("search-preference") end
        return true
    end
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
    local ok, why = I.Search.ProviderPolicy:Set(id, nil, nil, nil)
    if not ok then return nil, why end
    if not self:IsCurrent(id, token) then return failure("STALE_HANDLE", id) end
    return true
end
