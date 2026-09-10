local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
local C = {}
I.Builtin.CatalogProvider = C
local function combat() return InCombatLockdown and InCombatLockdown() end
local function now() return debugprofilestop and debugprofilestop() or 0 end

-- Only finite, flat scalar signatures survive a successful catalogue commit.
function C:New(id, title, events, build, actions)
    local m = {id=id, title=title, events=events, build=build, actions=actions, epoch=0, signatures={}}
    setmetatable(m, {__index=self})
    return m
end
function C:Cancel()
    self.epoch=self.epoch+1
    if self.timer then self.timer:Cancel(); self.timer=nil end
    self.job=nil
end
function C:Detach(reason)
    self.active=false; self:Cancel()
    if self.frame then self.frame:UnregisterAllEvents(); self.frame:SetScript("OnEvent",nil) end
    self.dirty=nil; self.signatures={}
    if self.onStop then pcall(self.onStop,self) end
    if reason=="unregister" then self.handle=nil end
end
function C:MarkDirty()
    if not self.active then return end
    self.dirty=true
    self:Cancel()
    if combat() then self.frame:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
    self.frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:Queue()
end
function C:Queue()
    if not self.active or self.timer then return end
    local epoch=self.epoch
    self.timer=C_Timer.NewTimer(0.01, function()
        if not self.active or self.epoch~=epoch then return end
        self.timer=nil
        self:Step()
    end)
end
function C:Step()
    if combat() then self:MarkDirty(); return end
    if not self.job then
        self.job=coroutine.create(function()
            local records, signatures, count, started = {}, {}, 0, now()
            local function checkpoint()
                count=count+1
                if count>=32 or now()-started>=1 then
                    coroutine.yield(); count=0; started=now()
                end
            end
            local function put(record, signature)
                if #records>=4096 then error("CATALOG_LIMIT") end
                if signatures[record.id] then error("DUPLICATE_CATALOG_ID") end
                records[#records+1]=record; signatures[record.id]=signature
            end
            self.build(self, put, checkpoint)
            local upsert,remove={},{}
            local epoch=self.epoch
            local function flush()
                if #upsert==0 and #remove==0 then return end
                local committed,err=self.handle:Update({upsert=upsert,remove=remove})
                if not self.active or epoch~=self.epoch then return false end
                if not committed then error(err and err.code or "SOURCE_COMMIT_FAILED") end
                for _,record in ipairs(upsert) do self.signatures[record.id]=signatures[record.id] end
                for _,id in ipairs(remove) do self.signatures[id]=nil end
                upsert,remove={},{}
                coroutine.yield(); count=0; started=now()
                return true
            end
            -- A native/Host call is not preemptible: cap the commit itself,
            -- not only the reads preceding it. Every chunk is atomic.
            coroutine.yield(); count=0; started=now()
            -- Remove obsolete IDs before additions so a full-capacity catalogue
            -- can replace identities without temporarily exceeding the Host cap.
            for id in pairs(self.signatures) do
                if not signatures[id] then
                    remove[#remove+1]=id
                    if #remove>=16 and flush()==false then return end
                end
            end
            if flush()==false then return end
            for index,record in ipairs(records) do
                if self.signatures[record.id]~=signatures[record.id] then
                    upsert[#upsert+1]=record
                    if #upsert>=16 and flush()==false then return end
                end
                records[index]=false
                checkpoint()
            end
            if flush()==false then return end
            self.signatures,self.dirty,self.lastError=signatures,nil,nil
        end)
    end
    local job,epoch=self.job,self.epoch
    local ok, result=coroutine.resume(job)
    if not self.active or epoch~=self.epoch or self.job~=job then return end
    if not ok then self.lastError=tostring(result); self.job=nil; return end
    if coroutine.status(self.job)~="dead" then self:Queue(); return end
    self.job=nil
end
function C:Init()
    if self.handle then
        if self.handle:GetState() then return true end
        self.handle=nil
    end
    LycheeDB.optionalProviderDefaults=type(LycheeDB.optionalProviderDefaults)=="table" and LycheeDB.optionalProviderDefaults or {}
    LycheeDB.disabledProviders=type(LycheeDB.disabledProviders)=="table" and LycheeDB.disabledProviders or {}
    if not LycheeDB.optionalProviderDefaults[self.id] then
        LycheeDB.optionalProviderDefaults[self.id]=true
        LycheeDB.disabledProviders[self.id]=true
    end
    local m=self
    self.handle=self.handle or _G.Lychee:RegisterProvider({
        id=self.id,apiVersion=2,version="1.0.0",title=self.title,scope={product="retail"},entries={},actions=self.actions,query=self.query,
        onEnable=function(handle)
            m.handle, m.active=handle,true
            local entry=I.Providers.entries[m.id]
            for id in pairs(entry and entry.recordMap or {}) do m.signatures[id]=false end
            -- Disabled Host records may remain for history; re-read and replace
            -- every record on enable, including deletion of obsolete identities.
            if not m.frame then m.frame=CreateFrame("Frame") end
            m.frame:SetScript("OnEvent",function(_,event,...)
                if event=="PLAYER_REGEN_DISABLED" then m:MarkDirty()
                elseif m.onEvent then m:onEvent(event,...)
                else m:MarkDirty() end
            end)
            for _,event in ipairs(m.events) do m.frame:RegisterEvent(event) end
            m.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
            local ok,why=true,nil
            if m.onStart then ok,why=pcall(m.onStart,m) end
            if ok then m:MarkDirty()
            else m.lastError=tostring(why); m:Detach("start-failed") end
            return function(reason) m:Detach(reason) end
        end,
    })
    return self.handle~=nil
end
