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
    if type(GetBuildInfo) == "function" then
        local version, build, _, tocVersion = GetBuildInfo()
        self.version, self.build = tostring(version or ""), tostring(build or "")
        self.interface = number(tocVersion)
    end
    local project,interface=WOW_PROJECT_ID,self.interface
    self.product="unknown"
    if (project==nil or project==(WOW_PROJECT_MAINLINE or 1)) and interface>=100000 then self.product="retail"
    elseif (project==nil or project==(WOW_PROJECT_MISTS_CLASSIC or 19)) and interface>=50500 and interface<50600 then self.product="classic"
    elseif (project==nil or project==(WOW_PROJECT_WRATH_CLASSIC or 11)) and interface>=38000 and interface<38100 then self.product="titan"
    elseif (project==nil or project==(WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5)) and interface>=20505 and interface<20600 then self.product="anniversary" end
    self.signature = table.concat({ self.schema, "identity-v2", self.product, self.interface, self.build, self.locale, self.sourceRevision }, "|")
    if previousSignature and previousSignature ~= self.signature and I.Search.StaticIndex and type(I.Search.StaticIndex.Rebuild) == "function" then
        I.Search.StaticIndex:Rebuild()
    end
    return self
end

function R:SetSourceRevision(revision)
    revision = number(revision)
    if revision <= self.sourceRevision then return self.sourceRevision end
    self.sourceRevision = revision
    self.signature = table.concat({ self.schema, "identity-v2", self.product, self.interface, self.build, self.locale, self.sourceRevision }, "|")
    return self.sourceRevision
end

function R:BuildSignature(sourceSignature)
    return table.concat({ self.signature, tostring(sourceSignature or "") }, "|")
end

function R:Current()
    if self.signature == "" then self:Refresh() end
    return self
end

function R:MatchesScope(scope, textEntry)
    scope = scope or {}
    textEntry = textEntry or {}
    local identity = self:Current()
    -- Scope is an explicit data restriction; translation language is ranked separately.
    if scope.locale and scope.locale~="default" and scope.locale~=identity.locale then return false end
    local normalizer=I.Search.Normalizer
    if textEntry.locale and normalizer and not normalizer:LocaleRank(textEntry.locale) then return false end
    if scope.product and scope.product ~= identity.product then return false end
    if scope.products then
        local matches=false
        for index=1,#scope.products do if scope.products[index]==identity.product then matches=true;break end end
        if not matches then return false end
    end
    if scope.minInterface and identity.interface < number(scope.minInterface) then return false end
    if scope.maxInterface and identity.interface > number(scope.maxInterface) then return false end
    if scope.minBuild and (not tonumber(identity.build) or tonumber(identity.build) < number(scope.minBuild)) then return false end
    if scope.maxBuild and (not tonumber(identity.build) or tonumber(identity.build) > number(scope.maxBuild)) then return false end
    if textEntry.scope and not self:MatchesScope(textEntry.scope) then return false end
    return true
end

R:Refresh()
