local I = _G.LycheeInternal
local C = {}
I.ClientSupport = C
local bounds = {"Interface", "Build"}
local matchBounds = {{"minInterface","maxInterface","interface","UNSUPPORTED_INTERFACE"},
    {"minBuild","maxBuild","build","UNSUPPORTED_BUILD"}}
local rangeFields = {product=true,minInterface=true,maxInterface=true,minBuild=true,maxBuild=true}

function C:IsProduct(product) return I.ClientProfiles[product] ~= nil end

-- Product identity and declared compatibility are separate. A project's name
-- or TOC suffix cannot override the interface observed from the running game.
function C:Identify(interface)
    if type(interface) ~= "number" then return "unknown" end
    for product, profile in pairs(I.ClientProfiles) do
        if interface >= profile.minInterface and interface <= profile.maxInterface then return product end
    end
    return "unknown"
end

-- Trusted normalized scopes; also used by discovery and the search hot path.
-- No tables, callbacks, global API probes or retained state per match.
function C:Matches(scope, client)
    if scope.product and scope.product ~= client.product then return false, "UNSUPPORTED_PRODUCT" end
    if scope.products then
        local found = false
        for _, product in ipairs(scope.products) do if product == client.product then found = true; break end end
        if not found then return false, "UNSUPPORTED_PRODUCT" end
    end
    for _, fields in ipairs(matchBounds) do
        local minimum, maximum = scope[fields[1]], scope[fields[2]]
        if minimum or maximum then
            local value = tonumber(client[fields[3]])
            if not value or value ~= value then return false, "CLIENT_IDENTITY_UNAVAILABLE" end
            if minimum and value < minimum or maximum and value > maximum then
                return false, fields[4]
            end
        end
    end
    return true
end

function C:Overlaps(a, b)
    return a.product == b.product and a.minInterface <= b.maxInterface and b.minInterface <= a.maxInterface
        and a.minBuild <= b.maxBuild and b.minBuild <= a.maxBuild
end

function C:ValidateRanges(ranges)
    if type(ranges) ~= "table" or #ranges == 0 or #ranges > 8 then return false, "INVALID_CLIENT_RANGES" end
    local count = 0
    for key, row in pairs(ranges) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #ranges or type(row) ~= "table" then
            return false, "INVALID_CLIENT_RANGES"
        end
        count = count + 1
        for field in pairs(row) do if not rangeFields[field] then return false, "INVALID_CLIENT_RANGES" end end
        if not self:IsProduct(row.product) then return false, "INVALID_CLIENT_RANGES" end
        for _, suffix in ipairs(bounds) do
            local minimum, maximum = row["min"..suffix], row["max"..suffix]
            if type(minimum) ~= "number" or type(maximum) ~= "number" or minimum % 1 ~= 0 or maximum % 1 ~= 0
                or minimum < 0 or maximum > 9999999 or minimum > maximum then return false, "INVALID_CLIENT_RANGES" end
        end
        for at = 1, key - 1 do
            if type(ranges[at]) ~= "table" then return false, "INVALID_CLIENT_RANGES" end
        end
    end
    if count ~= #ranges then return false, "INVALID_CLIENT_RANGES" end
    for at, row in ipairs(ranges) do
        for previous = 1, at - 1 do
            if self:Overlaps(row, ranges[previous]) then return false, "AMBIGUOUS_CLIENT_IMPLEMENTATION" end
        end
    end
    return true
end

function C:SelectRange(ranges, client)
    local selected
    for _, row in ipairs(ranges) do
        if self:Matches(row, client) then
            if selected then return nil, "AMBIGUOUS_CLIENT_IMPLEMENTATION" end
            selected = row
        end
    end
    return selected, not selected and "UNSUPPORTED_CLIENT" or nil
end

function C:Scope(row)
    return {products={row.product},minInterface=row.minInterface,maxInterface=row.maxInterface,
        minBuild=row.minBuild,maxBuild=row.maxBuild}
end

-- SDK callers supply data, never factories. Validate the entire declaration,
-- including overlaps outside this client, before selecting a single key.
function C:SelectImplementation(implementations, client)
    if type(implementations) ~= "table" or #implementations == 0 or #implementations > 16 then
        return nil, {code="INVALID_CLIENT_IMPLEMENTATIONS"}
    end
    local ids, rows, count = {}, {}, 0
    for key, entry in pairs(implementations) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #implementations or type(entry) ~= "table" then
            return nil, {code="INVALID_CLIENT_IMPLEMENTATIONS"}
        end
        count = count + 1
        for field in pairs(entry) do if field ~= "id" and field ~= "ranges" then return nil, {code="INVALID_CLIENT_IMPLEMENTATIONS"} end end
        if type(entry.id) ~= "string" or #entry.id == 0 or #entry.id > 64 or ids[entry.id] then
            return nil, {code="INVALID_CLIENT_IMPLEMENTATIONS"}
        end
        ids[entry.id] = true
        local valid, reason = self:ValidateRanges(entry.ranges)
        if not valid then return nil, {code=reason} end
        for _, range in ipairs(entry.ranges) do
            if range.minInterface < 1 or range.minBuild < 1 then return nil, {code="INVALID_CLIENT_RANGES"} end
            if #rows >= 32 then return nil, {code="CLIENT_IMPLEMENTATION_LIMIT"} end
            for _, previous in ipairs(rows) do
                if self:Overlaps(range, previous.range) then return nil, {code="AMBIGUOUS_CLIENT_IMPLEMENTATION"} end
            end
            rows[#rows+1] = {id=entry.id,range=range}
        end
    end
    if count ~= #implementations then return nil, {code="INVALID_CLIENT_IMPLEMENTATIONS"} end
    for _, row in ipairs(rows) do
        if self:Matches(row.range, client) then return row.id, self:Scope(row.range) end
    end
    return nil, {code="UNSUPPORTED_CLIENT",retryable=false}
end
