local I = _G.LycheeInternal
local S={active={}, keys={}, index={}, frame=nil}
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
    local i = 1
    while i <= #self.keys do
        local key = self.keys[i]
        local fn = self.active[key]
        local keep = fn and fn(elapsed)
        if self.index[key] then
            if keep == false then self:Remove(key) else i = i + 1 end
        end
    end
    if #self.keys == 0 and self.frame then self.frame:Hide() end
end

function S:Add(key, fn)
    if key == nil or type(fn) ~= "function" then return false end
    ensureFrame(self)
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
    self.index[key], self.active[key] = nil, nil
    if #self.keys == 0 and self.frame then self.frame:Hide() end
    return true
end

S.Stop = S.Remove

function S:Clear()
    self.active, self.keys, self.index = {}, {}, {}
    if self.frame then self.frame:Hide() end
end
