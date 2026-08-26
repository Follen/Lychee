local I = _G.LycheeInternal
I.Search = I.Search or {}

local R = { schema = "search-schema-2", sourceRevision = 0, product = "retail", locale = "enUS", version = "", build = "", interface = 0, signature = "" }
I.Search.RuntimeIdentity = R

local function number(value)
    return tonumber(value) or 0
end

function R:Refresh()
    local previousSignature = self.signature
    self.locale = (type(GetLocale) == "function" and GetLocale()) or self.locale or "enUS"
    self.product = "retail"
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
        self.product = tostring(WOW_PROJECT_ID)
    end
    if type(GetBuildInfo) == "function" then
        local version, build, _, tocVersion = GetBuildInfo()
        self.version, self.build = tostring(version or ""), tostring(build or "")
        self.interface = number(tocVersion)
    end
    if self.interface == 0 and select and type(select(4, GetBuildInfo and GetBuildInfo() or "")) == "number" then
        self.interface = select(4, GetBuildInfo())
    end
    self.signature = table.concat({ self.schema, "identity-v1", self.product, self.interface, self.build, self.locale, self.sourceRevision }, "|")
    if previousSignature and previousSignature ~= self.signature and I.Search.StaticIndex and type(I.Search.StaticIndex.Rebuild) == "function" then
        I.Search.StaticIndex:Rebuild()
    end
    return self
end

function R:SetSourceRevision(revision)
    revision = number(revision)
    if revision <= self.sourceRevision then return self.sourceRevision end
    self.sourceRevision = revision
    self.signature = table.concat({ self.schema, "identity-v1", self.product, self.interface, self.build, self.locale, self.sourceRevision }, "|")
    return self.sourceRevision
end

function R:BuildSignature(sourceSignature)
    return table.concat({ self.signature, tostring(sourceSignature or "") }, "|")
end

function R:Current()
    if not self.signature then self:Refresh() end
    return self
end

function R:MatchesScope(scope, textEntry)
    scope = scope or {}
    textEntry = textEntry or {}
    local identity = self:Current()
    local locale = textEntry.locale or scope.locale
    if locale and locale ~= "default" and locale ~= identity.locale then return false end
    if scope.product and scope.product ~= identity.product then return false end
    if scope.minInterface and identity.interface < number(scope.minInterface) then return false end
    if scope.maxInterface and identity.interface > number(scope.maxInterface) then return false end
    if scope.minBuild and tonumber(identity.build) and tonumber(identity.build) < number(scope.minBuild) then return false end
    if scope.maxBuild and tonumber(identity.build) and tonumber(identity.build) > number(scope.maxBuild) then return false end
    if textEntry.scope and not self:MatchesScope(textEntry.scope) then return false end
    return true
end

R:Refresh()
