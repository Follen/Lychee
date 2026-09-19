local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
local C = {}
I.Builtin.CatalogProvider = C
local function combat() return InCombatLockdown and InCombatLockdown() end
local function now() return debugprofilestop and debugprofilestop() or 0 end

-- Only finite, flat scalar signatures survive a successful catalogue commit.
function C:New(id, title, events, build, actions)
    local ledger=I.Builtin.CatalogLedger:New()
    local m = {id=id, locale=I.ProviderLocales:Builtin(id), title=title, events=events, build=build, actions=actions,
        epoch=0,ledger=ledger,signatures=ledger.values}
    setmetatable(m, {__index=self})
    return m
end
function C:Cancel()
    self.epoch=self.epoch+1
    self.ledger:Invalidate()
    if self.timer then self.timer:Cancel(); self.timer=nil end
    self.job=nil
end
function C:Detach(reason)
    local wasActive=self.active
    self.active=false; self:Cancel()
    if self.frame then self.frame:UnregisterAllEvents(); self.frame:SetScript("OnEvent",nil) end
    self.dirty=nil
    -- Keep only committed identities while disabled: Host retains its records.
    -- Their scalar signatures are invalidated, so re-enable revalidates all rows.
    self.ledger:Invalidate(reason=="unregister",true)
    self.signatures=self.ledger.values
    if wasActive and self.onStop then pcall(self.onStop,self) end
    if reason=="unregister" then self.handle=nil end
end
function C:MarkDirty()
    if not self.active then return end
    if combat() and self.onPause then self:onPause() end
    if not self.active or (self.hasWork and not self:hasWork()) then return end
    self.dirty=true
    self:Cancel()
    if combat() then self.frame:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
    self.frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:Queue()
end
function C:NotifyReady()
    if not self.active or not self.onReady then return end
    local epoch=self.epoch
    local handled=self:onReady()
    if not self.active or self.epoch~=epoch or handled then return end
    if I.Search and I.Search.Session then I.Search.Session:SourceChanged(self.id) end
end
function C:Queue()
    if not self.active or self.timer then return end
    local epoch=self.epoch
    self.timer=C_Timer.NewTimer(self.batchDelay or 0.01, function()
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
                if count>=(self.batchSize or 32) or now()-started>=1 then
                    coroutine.yield(); count=0; started=now()
                end
            end
            local function put(record, signature)
                if #records>=4096 then error("CATALOG_LIMIT") end
                if signatures[record.id] then error("DUPLICATE_CATALOG_ID") end
                records[#records+1]=record; signatures[record.id]=signature
            end
            self.build(self, put, checkpoint)
            local epoch=self.epoch
            local function current() return self.active and epoch==self.epoch end
            local function changedRecords(changed)
                local result={}
                for index,record in ipairs(records) do
                    if changed[record.id] then result[#result+1]=record end
                    records[index]=false
                end
                return result
            end
            -- A native/Host call is not preemptible: cap the commit itself,
            -- not only the reads preceding it. Every chunk is atomic.
            coroutine.yield(); count=0; started=now()
            local committed,err=self.ledger:Reconcile(self.handle,signatures,changedRecords,{
                full=true,batchSize=16,current=current,checkpoint=checkpoint,
                afterCommit=function() coroutine.yield();count=0;started=now() end,
            })
            if not current() then return end
            if not committed then error(err and err.code or "SOURCE_COMMIT_FAILED") end
            self.dirty,self.lastError=nil,nil
        end)
    end
    local job,epoch=self.job,self.epoch
    local ok, result=coroutine.resume(job)
    if not self.active or epoch~=self.epoch or self.job~=job then return end
    if not ok then self.lastError=tostring(result); self.job=nil; return end
    if coroutine.status(self.job)~="dead" then self:Queue(); return end
    self.job=nil
    self:NotifyReady()
end
function C:Init()
    if self.handle then
        if self.handle:GetState() then return true end
        self.handle=nil
    end
    local m=self
    self.handle=self.handle or _G.Lychee:RegisterProvider({
        id=self.id,apiVersion="1.0.0",version="1.0.0",title=self.title,
        searchable=self.searchable,searchGlobal=self.searchGlobal,searchMode=self.searchMode,searchPrefixes=self.searchPrefixes,searchKeywords=self.searchKeywords,
        i18n=self.locale.resources,scope=I.Builtin.Support:Scope(self.id),entries={},entryMode=self.entryMode,readEntry=self.readEntry,actions=self.actions,query=self.query,resolve=self.resolve,
        views=self.views,resolveTarget=self.resolveTarget,describe=self.describe,observe=self.observe,
        onEnable=function(handle)
            m.handle, m.active=handle,true
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
