-- Copy this file and the TOC into a third-party AddOn to exercise the SDK.
-- Lychee is optional: the AddOn remains usable when the facade is absent.
local addonName = ...
local state = {
    committed = nil,
    waiting = false,
    diagnostics = {},
}

local function record(code)
    if not state.diagnostics[code] then
        state.diagnostics[code] = true
    end
end

local function stopWaiting(frame)
    if frame then
        frame:UnregisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", nil)
    end
    state.waiting = false
end

local function buildExtension(SDK)
    if state.committed then
        return state.committed
    end
    if type(SDK) ~= "table" or type(SDK.Supports) ~= "function" then
        record("SDK_UNAVAILABLE")
        return nil
    end
    local supported = SDK:Supports(1, 1)
    if not supported then
        record("UNSUPPORTED_API")
        return nil
    end

    local extension, err = SDK:RegisterExtension({
        id = "third-party-fixture",
        apiVersion = 1,
        minApiRevision = 1,
        title = { default = "Third-party fixture", zhCN = "第三方示例" },
        version = "1.0.0",
        invalidationKeys = { "fixture-items" },
        onHostAttached = function(hostInfo)
            state.hostInfo = hostInfo
        end,
        onHostDetached = function()
            state.hostInfo = nil
        end,
        onEnabled = function()
            state.enabled = true
        end,
        onDisabled = function()
            state.enabled = false
        end,
    })
    if not extension then
        record(err and err.code or "INVALID_EXTENSION")
        return nil
    end

    local function requireDeclaration(token, declarationErr)
        if token then
            return true
        end
        record(declarationErr and declarationErr.code or "INVALID_SCHEMA")
        extension:Abort()
        return false
    end

    if not requireDeclaration(extension:RegisterCapabilityProvider({
        id = "fixture-items",
        type = "third-party-fixture.items",
        version = 1,
        requestSchema = { text = "string", limit = "integer?" },
        resultSchema = { kind = "array", items = { itemID = "integer", name = "string" }, maxItems = 20 },
        query = function(request)
            local needle = string.lower(request.text or "")
            local out = {}
            if string.find("复仇之怒", needle, 1, true) or string.find("翅膀", needle, 1, true) or string.find("wings", needle, 1, true) then
                out[1] = { itemID = 12345, name = "复仇之怒" }
            end
            return out
        end,
    })) then return nil end

    if not requireDeclaration(extension:RegisterPanelFactory({
        id = "fixture-detail",
        stateSchema = { itemID = "integer" },
        create = function()
            local panel = {}
            function panel:Mount(context)
                self.context = context
                if not self.frame and CreateFrame then
                    self.frame = CreateFrame("Frame", nil, context.contentFrame)
                    self.frame:SetAllPoints(context.contentFrame)
                    self.text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                    self.text:SetPoint("TOPLEFT", 16, -16)
                end
                if self.frame then self.frame:Show() end
            end
            function panel:Update(update)
                if self.text and update and update.state then
                    self.text:SetText("Item " .. tostring(update.state.itemID))
                end
            end
            function panel:Unmount()
                if self.frame then self.frame:Hide() end
                self.context = nil
            end
            function panel:Dispose()
                self:Unmount()
                self.frame = nil
                self.text = nil
            end
            return panel
        end,
    })) then return nil end

    if not requireDeclaration(extension:RegisterIntentHandler({
        type = "third-party-fixture.open-detail",
        version = 1,
        schema = { itemID = "integer" },
        execute = function(intent)
            return {
                ok = true,
                closePalette = false,
                transition = { type = "custom-panel", panelFactoryID = "fixture-detail", state = { itemID = intent.payload.itemID } },
            }
        end,
    })) then return nil end

    if not requireDeclaration(extension:RegisterSearchSource({
        id = "fixture-records",
        version = 1,
        revision = 1,
        priority = 40,
        scope = { product = "retail" },
        records = {
            {
                id = "fixture-item-12345",
                kind = "spell",
                kindTitle = { default = "Spell", zhCN = "技能" },
                category = { id = "spells", title = { default = "Spell", zhCN = "技能" } },
                title = { default = "Avenging Wrath", zhCN = "复仇之怒" },
                aliases = {
                    { text = "翅膀", locale = "zhCN" },
                    { text = "wings", locale = "enUS" },
                },
                description = { { text = "第三方示例技能。", locale = "zhCN" } },
                actions = {
                    {
                        id = "open-detail",
                        title = "查看详情",
                        kind = "intent",
                        intent = {
                            type = "third-party-fixture.open-detail",
                            version = 1,
                            payload = { itemID = 12345 },
                        },
                    },
                },
            },
        },
    })) then return nil end

    local committed, commitErr = extension:Commit()
    if not committed then
        record(commitErr and commitErr.code or "INVALID_SCHEMA")
        return nil
    end
    extension = committed
    state.committed = committed
    state.searchSource = committed:GetSearchSource("fixture-records")
    return committed
end

local function tryRegister()
    local SDK = _G.Lychee
    if not SDK then
        return false
    end
    stopWaiting(state.frame)
    return buildExtension(SDK) ~= nil
end

if not tryRegister() and CreateFrame then
    local frame = CreateFrame("Frame")
    state.frame = frame
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, event, loadedName)
        if event == "ADDON_LOADED" and loadedName == "Lychee" then
            tryRegister()
        end
    end)
    state.waiting = true
end

_G.ThirdPartyFixture = {
    GetExtension = function() return state.committed end,
    GetSearchSource = function() return state.searchSource end,
    GetDiagnostics = function() return state.diagnostics end,
    SetEnabled = function(enabled)
        if not state.committed then return nil end
        return state.committed:SetEnabled(enabled)
    end,
    Unregister = function()
        if not state.committed then return true end
        return state.committed:Unregister()
    end,
}
