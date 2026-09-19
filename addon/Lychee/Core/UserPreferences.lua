local I = _G.LycheeInternal
local Preferences = {}
I.UserPreferences = Preferences

local LIMIT, BYTES = 64, 65536
local fields = {providerID=1024,entryID=1024,sourceID=1024,title=4096,sourceTitle=4096,icon=1024,actionID=64}
local owner, original, active, size, recovery
local EMPTY = {}
local recentOwner,recentOriginal,recentActive,recentRecovery
local function matches(left, right)
    if type(left)=="table" and type(right)=="table" and (left.kind or right.kind) then
        if left.kind=="legacy-entry" and not right.kind or right.kind=="legacy-entry" and not left.kind then
            return left.providerID==right.providerID and left.entryID==right.entryID and left.actionID==right.actionID
        end
        return I.Invocations and I.Invocations:Equal(left,right) or false
    end
    return type(left) == "table" and type(right) == "table"
        and left.providerID == right.providerID and left.entryID == right.entryID and left.actionID == right.actionID
end
local function pinBytes(pin)
    if type(pin) ~= "table" or getmetatable(pin) ~= nil then return end
    if pin.kind~=nil then
        if not I.Invocations or not I.Invocations:NormalizeStoredRef(pin) then return end
        local _,err,bytes=I.Boundary:Copy(pin,"reference",{maxDepth=6,maxFields=32,maxNodes=256,maxBytes=16384,scalarKeys=true})
        if not err then return bytes end
        return
    end
    if type(pin.providerID) ~= "string" or pin.providerID == "" or type(pin.entryID) ~= "string" or pin.entryID == "" then return end
    local bytes, count = 16, 0
    for key,value in next,pin do
        count = count + 1
        local limit = fields[key]
        if count > 7 or not limit then return end
        if key=="actionID" and (type(value)~="string" or value=="") then return end
        if key == "icon" and type(value) == "number" then
            if value ~= value or value < 0 or value == math.huge or value % 1 ~= 0 then return end
            bytes = bytes + 16
        elseif type(value) == "string" and #value <= limit then bytes = bytes + #value + 16
        else return end
    end
    return bytes
end
local function validate(pins)
    if type(pins) ~= "table" or getmetatable(pins) ~= nil then return end
    if not I.Boundary.Array(pins,LIMIT) then return end
    local bytes = 0
    for index=1,#pins do
        local pin = rawget(pins,index)
        local cost = pinBytes(pin)
        if not cost then return end
        bytes = bytes + cost
        if bytes > BYTES then return end
        for prior=1,index-1 do if matches(pins[prior],pin) then return end end
    end
    return bytes
end
local function pins()
    local saved = I.CharacterStore:Data()
    if saved.pinned == nil then saved.pinned = {} end
    if saved ~= owner or saved.pinned ~= original then
        owner, original = saved, saved.pinned
        size = validate(original)
        recovery = size == nil and "PIN_DATA_INVALID" or nil
        active = not recovery and original or EMPTY
    end
    return active
end
function Preferences:Initialize() pins() end
function Preferences:GetPins() return pins() end
function Preferences:GetRecent()
    local saved=I.CharacterStore:Palette()
    if saved.recent==nil then saved.recent={} end
    if saved~=recentOwner or saved.recent~=recentOriginal then
        recentOwner,recentOriginal=saved,saved.recent
        local valid=validate(recentOriginal)
        recentRecovery=not valid or #recentOriginal>8
        recentActive=not recentRecovery and recentOriginal or EMPTY
    end
    return recentActive
end
function Preferences:GetRecentRecoveryError() self:GetRecent();return recentRecovery and "RECENT_DATA_INVALID" or nil end
local function trimRecent(refs)
    while #refs>8 or not validate(refs) do
        if #refs==0 then return end
        refs[#refs]=nil
    end
end
function Preferences:TouchRecent(item,actionID,outcome)
    if not self:CanPin(item) then return false end
    local refs,ref=self:GetRecent(),item.ref
    if recentRecovery then return false end
    local saved=ref.kind and I.Invocations:NormalizeStoredRef(ref) or {providerID=ref.providerID,entryID=ref.entryID,sourceID=ref.sourceID,actionID=ref.actionID}
    if not saved then return false end
    if actionID then
        local record=item.searchRecord or {}
        local actions=record.actions or record.interaction and record.interaction.actions or {}
        local primary=record.primaryActionID or record.interaction and record.interaction.primaryActionID or actions[1] and actions[1].id
        local selected
        for _,action in ipairs(actions) do if action.id==actionID then selected=action;break end end
        if not selected then return false end
        local provider=I.Providers.entries[ref.providerID]
        local invocationAction=ref.kind=="invocation" and provider and provider.definition.actions[ref.actionID]
        local panel=invocationAction and invocationAction.panel
        local opensArguments=panel and (selected.kind=="open-panel" and selected.panel==panel
            or type(outcome)=="table" and outcome.transition and outcome.transition.panelID==panel)
        -- Ordinary panel/provider actions on a parameterized search result are
        -- entry actions, not execution of that result's default Invocation.
        if opensArguments then saved.kind,saved.args="command",nil
        elseif not ((ref.kind=="target" or ref.kind=="command") and actionID==primary) then
            saved={providerID=ref.providerID,entryID=item.id,sourceID=ref.sourceID,
                actionID=(record.invocation or record.command or record.targetRef or actionID~=primary) and actionID or nil}
        end
    end
    saved.title=type(item.text)=="string" and #item.text<=4096 and item.text or nil
    saved.sourceTitle=type(item.sourceTitle)=="string" and #item.sourceTitle<=4096 and item.sourceTitle or nil
    saved.icon=(type(item.icon)=="number" or type(item.icon)=="string" and #item.icon<=1024) and item.icon or nil
    if not pinBytes(saved) then return false end
    for index=#refs,1,-1 do if matches(refs[index],saved) then table.remove(refs,index) end end
    table.insert(refs,1,saved)
    trimRecent(refs)
    return true,saved
end
function Preferences:TouchInvocation(ref,display)
    local normalized=I.Invocations and I.Invocations:NormalizeStoredRef(ref)
    if not normalized or normalized.kind~="invocation" or normalized.product~=I.Search.RuntimeIdentity:Current().product then return false end
    if display then
        normalized.entryID=display.entryID or normalized.entryID
        normalized.title,normalized.icon,normalized.sourceTitle=display.title,display.icon,display.sourceTitle
    end
    if not pinBytes(normalized) then return false end
    local refs=self:GetRecent()
    if recentRecovery then return false end
    if not validate(refs) then return false end
    for index=#refs,1,-1 do if matches(refs[index],normalized) then table.remove(refs,index) end end
    table.insert(refs,1,normalized);trimRecent(refs)
    return true
end
function Preferences:GetRecoveryError() pins(); return recovery end
function Preferences:CanPin(item)
    return item and item.ref and item.ref.providerID ~= "lychee.settings"
        and I.Providers and I.Providers:CanRemember(item) == true
end
function Preferences:PinIndex(ref)
    for index,pin in ipairs(pins()) do if matches(pin,ref) then return index end end
end
local function insert(pin,index)
    local list = pins()
    if recovery then return false,recovery end
    local cost = pinBytes(pin)
    if not cost then return false,"PIN_DATA_INVALID" end
    if #list >= LIMIT or size + cost > BYTES then return false,"PIN_LIMIT" end
    table.insert(list,index or #list+1,pin); size = size + cost
    return true
end
function Preferences:Pin(item)
    if not self:CanPin(item) then return false,"PIN_UNAVAILABLE" end
    if self:GetRecoveryError() then return false,recovery end
    local ref = item.ref
    if self:PinIndex(ref) then return true end
    if ref.kind then
        local saved=I.Invocations:NormalizeStoredRef(ref)
        if not saved then return false,"PIN_DATA_INVALID" end
        saved.title,saved.icon,saved.sourceTitle=item.text,item.icon,item.sourceTitle
        return insert(saved)
    end
    return insert({providerID=ref.providerID,entryID=ref.entryID,sourceID=ref.sourceID,actionID=ref.actionID,
        title=item.text,icon=item.icon,sourceTitle=item.sourceTitle})
end
local function indexValid(index)
    return type(index) == "number" and index == index and index % 1 == 0
end
function Preferences:Remove(index)
    local list = pins()
    if recovery or not indexValid(index) or index < 1 or index > #list then return false end
    local pin = table.remove(list,index); size = size - pinBytes(pin)
    return pin
end
function Preferences:Restore(pin,index)
    local list = pins()
    if self:PinIndex(pin) or (index ~= nil and not indexValid(index)) then return false end
    return insert(pin,math.max(1,math.min(index or #list+1,#list+1)))
end
function Preferences:Move(from,to)
    local list = pins()
    if recovery or not indexValid(from) or not indexValid(to) or from < 1 or from > #list then return false end
    to = math.max(1,math.min(#list,to))
    if from == to then return true end
    table.insert(list,to,table.remove(list,from))
    return true
end
function Preferences:Resolve(pin,reply)
    if type(pin) ~= "table" then return nil end
    if I.Providers then return I.Providers:Resolve(pin,I.Context and I.Context:Snapshot() or {},reply) end
end
