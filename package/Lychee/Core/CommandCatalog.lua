local I = _G.LycheeInternal
local commandIndex = I.Search.StaticIndex:New()
function commandIndex:Persist() return false end
local commands, byExtension, ambientView = {}, {}, {}
local Catalog = { version = 0 }
I.Catalog = Catalog

local function copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[copyValue(key, seen)] = copyValue(child, seen)
    end
    return copy
end

local function display(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return "" end
    if value.text then return value.text end
    local locale = I.Search.Normalizer.locale
    return value[locale] or value.default or value.enUS or ""
end

local function isCatalogCommand(command)
    local match = command.match
    return not (match and match.type == "ambient")
end

local function sourceID(key)
    return "command:" .. key
end

local function textLength(value)
    local count = 0
    for index = 1, #value do
        local byte = value:byte(index)
        if byte < 128 or byte >= 192 then count = count + 1 end
    end
    return count
end

local function resultLess(left, right)
    if (left.confidence or 0) ~= (right.confidence or 0) then
        return (left.confidence or 0) > (right.confidence or 0)
    end
    if (left.sourcePriority or 0) ~= (right.sourcePriority or 0) then
        return (left.sourcePriority or 0) > (right.sourcePriority or 0)
    end
    if (left.categoryOrder or 0) ~= (right.categoryOrder or 0) then
        return (left.categoryOrder or 0) < (right.categoryOrder or 0)
    end
    return tostring(left.stableID or left.id) < tostring(right.stableID or right.id)
end

local function ambientLess(left, right)
    return left.priority > right.priority or (left.priority == right.priority and left.key < right.key)
end

function Catalog:Add(extensionID, command, extensionTitle)
    if type(extensionID) ~= "string" or extensionID == "" or type(command) ~= "table" or type(command.id) ~= "string" then
        return nil, { code = "INVALID_COMMAND" }
    end

    local stored = copyValue(command)
    local key = extensionID .. ":" .. stored.id
    if commands[key] then return nil, { code = "DUPLICATE_COMMAND" } end

    stored._ext, stored._key = extensionID, key
    stored.sourceTitle = stored.sourceTitle or extensionTitle
    stored._enabled = stored._enabled ~= false
    commands[key] = stored
    local extensionCommands = byExtension[extensionID]
    if not extensionCommands then
        extensionCommands = {}
        byExtension[extensionID] = extensionCommands
    end
    extensionCommands[#extensionCommands + 1] = key

    if isCatalogCommand(stored) then
        local privateSourceID = sourceID(key)
        local registered, registerErr = commandIndex:RegisterSource({
            id = privateSourceID,
            priority = tonumber(stored.priority) or 0,
            _enabled = stored._enabled,
        })
        if not registered then
            commands[key] = nil
            extensionCommands[#extensionCommands] = nil
            if #extensionCommands == 0 then byExtension[extensionID] = nil end
            return nil, { code = registerErr or "INVALID_COMMAND" }
        end
        local added, addErr = commandIndex:AddRecord(privateSourceID, {
            id = key,
            kind = "command",
            kindTitle = stored.kindTitle,
            title = stored.title,
            aliases = stored.aliases,
            keywords = stored.keywords,
            description = stored.description,
            category = stored.category,
            payload = stored,
        })
        if not added then
            commandIndex:UnregisterSource(privateSourceID)
            commands[key] = nil
            extensionCommands[#extensionCommands] = nil
            if #extensionCommands == 0 then byExtension[extensionID] = nil end
            return nil, { code = addErr or "INVALID_COMMAND" }
        end
    end

    local match = stored.match
    if match and match.type == "ambient" and type(stored.resolve) == "function" then
        ambientView[#ambientView + 1] = {
            key = key,
            priority = tonumber(stored.priority) or 0,
            resolve = stored.resolve,
            command = stored,
        }
        table.sort(ambientView, ambientLess)
    end

    self.version = self.version + 1
    return true
end

function Catalog:Get(key)
    local command = commands[key]
    return command and copyValue(command) or nil
end

function Catalog:RemoveExtension(extensionID)
    local extensionCommands = byExtension[extensionID]
    if not extensionCommands then return true end
    for index = 1, #extensionCommands do
        local key = extensionCommands[index]
        local command = commands[key]
        if command and isCatalogCommand(command) then commandIndex:UnregisterSource(sourceID(key)) end
        for ambientIndex = #ambientView, 1, -1 do
            if ambientView[ambientIndex].key == key then table.remove(ambientView, ambientIndex) end
        end
        commands[key] = nil
    end
    byExtension[extensionID] = nil
    self.version = self.version + 1
    return true
end

function Catalog:SetExtensionEnabled(extensionID, enabled)
    local extensionCommands = byExtension[extensionID]
    if not extensionCommands then return true end
    enabled = not not enabled
    local changed = false
    for index = 1, #extensionCommands do
        local key = extensionCommands[index]
        local command = commands[key]
        if command and command._enabled ~= enabled then
            command._enabled = enabled
            changed = true
            if isCatalogCommand(command) then commandIndex:TouchSource(sourceID(key), enabled) end
        end
    end
    if changed then self.version = self.version + 1 end
    return true
end

function Catalog:Query(request, limit)
    local maximum = math.max(0, tonumber(limit) or 20)
    if maximum == 0 then return {} end
    local normalized = type(request) == "table" and request.normalized or request
    local hits = commandIndex:Search(normalized or "", maximum)
    local out = {}
    for index = 1, #hits do
        local hit, command = hits[index], hits[index].item
        if command and command._enabled ~= false then
            local category = command.category
            local exposedCommand = copyValue(command)
            out[#out + 1] = {
                id = command.id,
                text = display(command.title),
                kindTitle = display(command.kindTitle),
                subtext = display(command.subtitle or command.subtext),
                description = display(command.description),
                icon = command.icon,
                sourceTitle = display(command.sourceTitle),
                category = display(category and category.title or category),
                categoryColor = category and category.color,
                command = exposedCommand,
                payload = copyValue(command.payload or {}),
                confidence = hit.confidence,
                evidence = hit.evidence,
                sourcePriority = tonumber(command.priority) or 0,
                categoryOrder = hit.categoryOrder,
                stableID = command._key,
            }
        end
    end
    table.sort(out, resultLess)
    return out
end

function Catalog:GetAmbientView(normalized, enabledByKey)
    local out = {}
    if type(normalized) ~= "string" or normalized == "" then return out end
    local length = textLength(normalized)
    for index = 1, #ambientView do
        local schedulable = ambientView[index]
        local key, command = schedulable.key, schedulable.command
        local match = command.match
        local minimum = match and tonumber(match.minLength) or 0
        local maximum = match and tonumber(match.maxLength) or math.huge
        if command._enabled ~= false and command.entitySearch ~= false
            and match and match.type == "ambient"
            and (not enabledByKey or enabledByKey[key] ~= false)
            and length >= minimum and length <= maximum
            and type(command.resolve) == "function" then
            out[#out + 1] = {
                key = schedulable.key,
                priority = schedulable.priority,
                resolve = schedulable.resolve,
                command = copyValue(command),
            }
        end
    end
    return out
end
