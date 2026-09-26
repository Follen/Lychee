local I = _G.LycheeInternal
I.Search = I.Search or {}

local R = { schema = "search-schema-2", sourceRevision = 0, product = "retail", locale = "enUS", version = "", build = "", interface = 0, signature = "" }
local EMPTY = {} -- read-only defaults; scope checks never mutate inputs
I.Search.RuntimeIdentity = R

local function number(value)
    return tonumber(value) or 0
end

function R:Refresh()
    local previousSignature = self.signature
    self.locale = (type(GetLocale) == "function" and GetLocale()) or self.locale or "enUS"
    if type(GetBuildInfo) == "function" then
        local version, build, _, tocVersion = GetBuildInfo()
        self.version, self.build = tostring(version or ""), tostring(build or "")
        self.interface = number(tocVersion)
    end
    self.product=I.ClientSupport:Identify(self.interface)
    self.signature = table.concat({ self.schema, "identity-v2", self.product, self.interface, self.build, self.locale, self.sourceRevision }, "|")
    if previousSignature and previousSignature ~= self.signature and I.Search.StaticIndex and type(I.Search.StaticIndex.Rebuild) == "function" then
        I.Search.StaticIndex:Rebuild()
    end
    return self
end

function R:Current()
    if self.signature == "" then self:Refresh() end
    return self
end

function R:MatchesScope(scope, textEntry)
    scope = scope or EMPTY
    textEntry = textEntry or EMPTY
    local identity = self:Current()
    -- Scope is an explicit data restriction; translation language is ranked separately.
    if scope.locale and scope.locale~="default" and scope.locale~=identity.locale then return false end
    local normalizer=I.Search.Normalizer
    if textEntry.locale and normalizer and not normalizer:LocaleRank(textEntry.locale) then return false end
    if not I.ClientSupport:Matches(scope,identity) then return false end
    if textEntry.scope and not self:MatchesScope(textEntry.scope) then return false end
    return true
end

local function referenceKeyLess(left,right)
    local a,b=type(left),type(right)
    if a~=b then return a<b end
    if a=="boolean" then return left==false and right==true end
    return left<right
end
local function encodeReference(value,parts,root)
    local kind=type(value)
    if kind=="string" then
        parts[#parts+1]="s"..#value..":"..value
    elseif kind=="number" then
        parts[#parts+1]="n"..(value==0 and "0" or string.format("%.17g",value))..";"
    elseif kind=="boolean" then
        parts[#parts+1]=value and "b1" or "b0"
    elseif kind=="table" then
        local keys={}
        for key in pairs(value) do
            if not root or key~="title" and key~="icon" and key~="sourceTitle" and (key~="entryID" or value.kind=="legacy-entry") then
                keys[#keys+1]=key
            end
        end
        table.sort(keys,referenceKeyLess)
        parts[#parts+1]="t"..#keys..":"
        for _,key in ipairs(keys) do encodeReference(key,parts);encodeReference(value[key],parts) end
    end
end
-- Internal presentation/lookup identity, never an Entry ID or a persisted ref.
-- The read-only validator supplies the same depth/node/byte limits and plain
-- data boundary; omission rules exactly match Invocations:Equal.
function R:ReferenceKey(ref)
    if type(ref)~="table" then return nil,{code="INVALID_REFERENCE"} end
    if ref.kind==nil then
        if type(ref.providerID)~="string" or type(ref.entryID)~="string" then return nil,{code="INVALID_REFERENCE"} end
        if ref.actionID~=nil then
            if type(ref.actionID)~="string" or #ref.actionID==0 or #ref.actionID>64 then return nil,{code="INVALID_REFERENCE"} end
            return "\0entry-action:"..#ref.providerID..":"..ref.providerID..#ref.entryID..":"..ref.entryID..#ref.actionID..":"..ref.actionID
        end
        return ref.providerID..":"..ref.entryID
    end
    if not I.Invocations then return nil,{code="UNSUPPORTED_API"} end
    local value,err=I.Invocations:_ValidateStoredRef(ref)
    if not value then return nil,err end
    -- Legal ordinary Provider/Entry IDs cannot start with this separator.
    local parts={"\0"}
    encodeReference(value,parts,true)
    return table.concat(parts)
end

R:Refresh()
