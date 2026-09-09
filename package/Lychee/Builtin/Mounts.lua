local I = _G.LycheeInternal
local M = { items={}, dirtyIDs={}, epoch=0 }
I.Builtin.Mounts = M

local function hasAPI()
    return C_MountJournal and type(C_MountJournal.GetMountIDs) == "function"
        and type(C_MountJournal.GetMountInfoByID) == "function"
end

local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function readMount(mountID)
    local name, spellID, icon, _, _, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(mountID)
    if name == nil then return nil, "MOUNT_DATA_UNAVAILABLE" end
    if not collected or hidden then return false end
    if type(name) ~= "string" or name == "" or type(spellID) ~= "number" or spellID <= 0 then
        return nil, "MOUNT_DATA_UNAVAILABLE"
    end
    -- Temporary usability (indoors, movement, zone) is checked by the game on
    -- the hardware click, not baked into the index or action-bar drag support.
    return {
        id="mount:" .. tostring(mountID), title=name, kind="mount", kindTitle="坐骑", icon=icon,
        subtitle="点击召唤 · 可拖到动作条", payload={mountID=mountID, spellID=spellID},
        primaryActionID="summon", actions={{id="summon", title="召唤", kind="secure-spell", spellID=spellID}},
        drag={type="spell", spellID=spellID},
    }
end

local function sameMount(left, right)
    return left and right and left.title == right.title and left.icon == right.icon
        and left.spellID == right.payload.spellID
end

function M:Refresh()
    if not self.active or not self.handle then return false end
    if inCombat() then return false, "COMBAT_LOCKED" end
    if not hasAPI() then self.lastError="MOUNT_API_UNAVAILABLE"; return false, self.lastError end
    local ids
    if self.fullDirty then
        local ok, result = pcall(C_MountJournal.GetMountIDs)
        if not ok or type(result) ~= "table" then
            self.lastError="MOUNT_LIST_UNAVAILABLE"; return false, self.lastError
        end
        ids = result
    else
        ids = {}
        for mountID in pairs(self.dirtyIDs) do ids[#ids+1]=mountID end
    end
    if #ids == 0 and not self.fullDirty then return true end

    local nextItems, upsert, remove = {}, {}, {}
    for index = 1, #ids do
        local mountID = ids[index]
        local ok, record, err = pcall(readMount, mountID)
        if not ok or record == nil then
            self.lastError=err or "MOUNT_DATA_UNAVAILABLE"; return false, self.lastError
        end
        nextItems[mountID] = record
        local old = self.items[mountID]
        if record then
            if not sameMount(old, record) then upsert[#upsert+1]=record end
        elseif old then remove[#remove+1]="mount:" .. tostring(mountID) end
    end
    if self.fullDirty then
        for mountID in pairs(self.items) do
            if nextItems[mountID] == nil then remove[#remove+1]="mount:" .. tostring(mountID) end
        end
    end
    if #upsert > 0 or #remove > 0 then
        local committed, err = self.handle:Update({upsert=upsert, remove=remove})
        if not committed then self.lastError=err and err.code or "SOURCE_COMMIT_FAILED"; return false, self.lastError end
    end
    -- Publish the local cache and clear dirty flags only after a successful
    -- source commit. Transient API failures retain the last complete index.
    if self.fullDirty then
        for mountID in pairs(self.items) do if nextItems[mountID] == nil then self.items[mountID]=nil end end
    end
    for mountID, record in pairs(nextItems) do
        if not record then self.items[mountID]=nil
        elseif not sameMount(self.items[mountID], record) then
            -- Only change detection lives here; the Provider owns action/drag
            -- descriptors. Do not retain another full record per mount.
            self.items[mountID]={title=record.title, icon=record.icon, spellID=record.payload.spellID}
        end
    end
    self.fullDirty, self.lastError = nil, nil
    for mountID in pairs(self.dirtyIDs) do self.dirtyIDs[mountID]=nil end
    return true
end

function M:Schedule(full, mountID)
    if not self.active then return end
    if full then self.fullDirty=true
    elseif type(mountID) == "number" then self.dirtyIDs[mountID]=true end
    if self.pending or inCombat() or (not self.fullDirty and next(self.dirtyIDs) == nil) then return end
    self.pending=true
    local epoch=self.epoch
    local function flush()
        if not self.active or self.epoch ~= epoch then return end
        self.pending=nil
        self:Refresh()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, flush) else flush() end
end

local function onEvent(_, event, mountID)
    if event == "NEW_MOUNT_ADDED" then M:Schedule(false, mountID)
    elseif event == "PLAYER_REGEN_ENABLED" then M:Schedule(false)
    else M:Schedule(true) end
end

function M:Detach(reason)
    self.active, self.pending = false, nil
    self.epoch=self.epoch+1
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    self.fullDirty=nil
    for mountID in pairs(self.dirtyIDs) do self.dirtyIDs[mountID]=nil end
    if reason == "unregister" then self.handle=nil; self.items={} end
end

function M:Init()
    if self.handle then return true end
    if not hasAPI() then return false, "MOUNT_API_UNAVAILABLE" end
    local handle, err = _G.Lychee:RegisterProvider({
        id="builtin.mounts", apiVersion=2, version="1.0.0", title="坐骑", scope={product="retail"}, entries={},
        onEnable=function(providerHandle)
            M.handle, M.active = providerHandle, true
            if not M.eventFrame then M.eventFrame=CreateFrame("Frame") end
            M.eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
            M.eventFrame:RegisterEvent("COMPANION_LEARNED")
            M.eventFrame:RegisterEvent("COMPANION_UNLEARNED")
            M.eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
            M.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            M.eventFrame:SetScript("OnEvent", onEvent)
            M:Schedule(true)
            return function(reason) M:Detach(reason) end
        end,
    })
    self.handle=handle
    return handle ~= nil, err
end
