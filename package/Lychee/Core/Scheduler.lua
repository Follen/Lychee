local I = _G.LycheeInternal
local S={active={}, keys={}, index={}, versions={}, sequence=0, limit=256, frame=nil,
    tickKeys={}, tickVersions={}}
I.Scheduler=S

local function ensureFrame(self)
    if self.frame or not CreateFrame then return self.frame end
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed) self:_Tick(elapsed) end)
    self.frame = frame
    return frame
end

function S:_Tick(elapsed)
    if self.ticking then return false end
    self.ticking = true
    local count = #self.keys
    local keys, versions = self.tickKeys, self.tickVersions
    for i = 1, count do
        local key = self.keys[i]
        keys[i], versions[i] = key, self.versions[key]
    end
    for i = 1, count do
        local key, version = keys[i], versions[i]
        keys[i], versions[i] = nil, nil
        -- Adds/replacements run next tick; swap-remove cannot skip a survivor.
        if self.versions[key] == version then
            local ok, keep = pcall(self.active[key], elapsed)
            if not ok then
                for remaining = i + 1, count do keys[remaining], versions[remaining] = nil, nil end
                if self.versions[key] == version then self:Remove(key) end
                self.ticking = nil
                error(keep, 0)
            end
            if keep == false and self.versions[key] == version then self:Remove(key) end
        end
    end
    self.ticking = nil
    if #self.keys == 0 and self.frame then self.frame:Hide() end
end

function S:Add(key, fn)
    if key == nil or type(fn) ~= "function" then return false end
    if not self.index[key] and #self.keys >= self.limit then return false, "TASK_LIMIT" end
    ensureFrame(self)
    self.sequence = self.sequence + 1
    self.versions[key] = self.sequence
    if self.index[key] then
        self.active[key] = fn
        return true
    end
    self.active[key] = fn
    self.keys[#self.keys + 1] = key
    self.index[key] = #self.keys
    if self.frame then self.frame:Show() end
    return true
end

function S:Remove(key)
    local index = self.index[key]
    if not index then return false end
    local last = #self.keys
    local lastKey = self.keys[last]
    self.keys[index] = lastKey
    self.index[lastKey] = index
    self.keys[last] = nil
    self.index[key], self.active[key], self.versions[key] = nil, nil, nil
    if #self.keys == 0 and self.frame then self.frame:Hide() end
    return true
end

S.Stop = S.Remove

function S:Clear()
    for i = #self.keys, 1, -1 do
        local key = self.keys[i]
        self.active[key], self.index[key], self.versions[key], self.keys[i] = nil, nil, nil, nil
    end
    if self.frame then self.frame:Hide() end
end
