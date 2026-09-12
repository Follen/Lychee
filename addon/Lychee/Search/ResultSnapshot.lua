local I = _G.LycheeInternal
local R = {}
I.Search.ResultSnapshot = R
-- Display snapshots own only visible result fields. Provider and query
-- lifetimes are stamped by their owners, never inferred by presentation.

local function displayText(value)
    return I.Search.Normalizer:Display(value)
end

local function displayActions(actions)
    if type(actions) ~= "table" then return actions end
    local localized=false
    for index=1,#actions do
        if type(actions[index])~="table" or type(actions[index].title)=="table" then localized=true;break end
    end
    -- Host result consumers treat descriptors as immutable. SDK execution
    -- still obtains its own record copy at the Provider boundary.
    if not localized then return actions end
    local displayed = {}
    for index = 1, #actions do
        local action = actions[index]
        if type(action) == "table" then
            local copy = {}
            for key, value in pairs(action) do copy[key] = value end
            copy.title = displayText(action.title)
            displayed[index] = copy
        end
    end
    return displayed
end

function R:Materialize(hit,ownedRecord)
    local indexed=hit and hit.entry
    local record = ownedRecord or (indexed and indexed.record or (hit and hit.record))
    local source=indexed and indexed.source
    local sourceID=source and source.id or (hit and hit.sourceID)
    if not record or not sourceID or sourceID == "legacy" then return nil end
    local item = {
        id = record.id,
        text = displayText(record.title),
        kindTitle = displayText(record.kindTitle),
        subtext = displayText(record.subtitle or record.subtext),
        description = displayText(record.description),
        payload = record.payload or record,
        icon = record.icon,
        category = displayText(record.category and record.category.title or record.category),
        categoryColor = record.category and record.category.color,
        searchRecord = record,
        confidence = hit.confidence,
        evidence = hit.evidence,
        categoryOrder = indexed and indexed.categoryOrder or hit.categoryOrder,
        stableID = indexed and indexed.stableID or hit.stableID,
    }
    if ownedRecord then setmetatable(item,hit.metadata)
    else
        item.source,item.sourceID=sourceID,sourceID
        item.sourceTitle=displayText(source and (source.title or source.extensionTitle) or hit.sourceTitle)
        item.sourceGeneration=source and source.generation or hit.sourceGeneration
        item.sourceRevision=source and source.revision or hit.sourceRevision
        item._ext=record._extensionID or (source and source.extensionID) or hit.sourceExtensionID
        item.sourcePriority=indexed and indexed.source.priority or hit.sourcePriority
    end
    if type(record.actions) == "table" then
        item.interaction = {
            primaryActionID = record.primaryActionID or (record.actions[1] and record.actions[1].id),
            actions = displayActions(record.actions),
            drag = record.drag,
        }
    elseif record.interaction then
        local interaction = {}
        for key, value in pairs(record.interaction) do interaction[key] = value end
        interaction.actions = displayActions(record.interaction.actions)
        item.interaction = interaction
    end
    return item
end
