local I = _G.LycheeInternal

local Executor = {}
I.ResultActionExecutor = Executor

local function actionFor(item, actionID)
    local interaction = item and item.interaction
    local actions = interaction and interaction.actions
    if type(actions) ~= "table" then return nil end
    for index = 1, #actions do
        if actions[index].id == actionID then return actions[index], interaction end
    end
end

local function primaryActionFor(item)
    local interaction = item and item.interaction
    local actions = interaction and interaction.actions
    if type(actions) ~= "table" then return nil, interaction end
    local primaryID = interaction.primaryActionID
    if type(primaryID) == "string" then
        local action = actionFor(item, primaryID)
        if action then return action, interaction end
    end
    return actions[1], interaction
end

local function extensionID(row, item)
    return row and row.extensionID or item and (item._ext or (item.command and item.command._ext))
end

local function pickupSpell(spellID)
    local Lychee = _G.Lychee
    if Lychee and Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(spellID) then
        return false, "ACTION_UNAVAILABLE"
    end
    if C_Spell and type(C_Spell.PickupSpell) == "function" then C_Spell.PickupSpell(spellID); return true end
    if type(PickupSpell) == "function" then PickupSpell(spellID); return true end
    return false, "DRAG_UNSUPPORTED"
end

local function succeeded(result)
    return result == true or (type(result) == "table" and result.ok == true)
end

function Executor:BindPalette(palette)
    if not palette then return false end
    self.palette = palette
    return true
end

function Executor:GetDragDescriptor(item)
    local drag = item and item.interaction and item.interaction.drag
    if type(drag) == "table" and drag.type == "spell" and type(drag.spellID) == "number" and drag.spellID > 0 then return drag end
    if type(drag) == "table" and drag.type == "provider" and item.providerID and type(drag.handler) == "string" then return drag end
end

function Executor:ConfigureDragTarget(target, item)
    if not target or type(target.RegisterForDrag) ~= "function" then return end
    local enabled = self:GetDragDescriptor(item) ~= nil
    if target._lycheeDragEnabled == enabled then return end
    if enabled then target:RegisterForDrag("LeftButton") else target:RegisterForDrag() end
    target._lycheeDragEnabled = enabled
end

function Executor:IsRowCurrent(row, session, generation, item, owner)
    local palette = self.palette
    if not palette or not palette.visible or not row or not row.item then return false, "STALE_GENERATION" end
    local searchSession = I.Search and I.Search.Session
    if searchSession then
        local current, err = searchSession:IsCurrent(session or row.session, generation or row.generation)
        if not current then return false, err end
    elseif row.session ~= palette.session or row.generation ~= palette.generation then
        return false, "STALE_GENERATION"
    end
    if row.session ~= palette.session or row.generation ~= palette.generation then return false, "STALE_GENERATION" end
    if item and row.item ~= item then return false, "STALE_GENERATION" end
    owner = owner or extensionID(row, row.item)
    if owner and I.Registry and not I.Registry:IsEnabled(owner) then return false, "EXTENSION_DISABLED" end
    local rowItem = row.item
    if I.Providers and not I.Providers:IsCurrent(rowItem) then return false, "STALE_GENERATION" end
    if rowItem.sourceID and rowItem.sourceGeneration then
        local static = I.Search and I.Search.StaticIndex
        local state = static and static:GetSourceState(rowItem.sourceID)
        if not state or state.enabled == false or state.generation ~= rowItem.sourceGeneration
            or state.revision ~= rowItem.sourceRevision then
            return false, "STALE_GENERATION"
        end
    end
    return true
end

function Executor:IsAvailable(item)
    local command = item and item.command
    if type(command) ~= "table" then command = nil end
    if command and type(command.availability) == "function" then
        local context = I.Context and I.Context:Snapshot() or {}
        local ok, available = xpcall(function()
            return command.availability(context)
        end, function() return "CALLBACK_ERROR" end)
        return ok and available == true
    end
    local availability = item and item.searchRecord and item.searchRecord.availability
    if type(availability) ~= "table" then return true end
    local context = I.Context and I.Context:Snapshot() or {}
    local value = context[availability.contextKey]
    if value == nil and type(context.values) == "table" then value = context.values[availability.contextKey] end
    return value == availability.equals
end

function Executor:Validate(row, session, generation, item, owner, preparing)
    local current, err = self:IsRowCurrent(row, session, generation, item, owner)
    if not current then return false, err end
    if InCombatLockdown and InCombatLockdown() then return false, "COMBAT_LOCKED" end
    if not preparing and row.IsVisible and not row:IsVisible() then return false, "STALE_GENERATION" end
    if not self:IsAvailable(row.item) then return false, "ACTION_UNAVAILABLE" end
    return true
end

function Executor:_Transition(result, item, row, session, generation)
    local transition = result and result.transition
    if not transition then return result end
    local owner = extensionID(row, item)
    local panelID = transition.panelID or transition.panelFactoryID
    local factory = owner and I.Registry and I.Registry:GetPanel(owner, panelID)
    if not factory then return false, "COMMAND_NOT_FOUND" end
    local state = transition.state or {}
    local stateOK, stateErr = I.Registry:ValidateSchema(state, factory.stateSchema or {}, "transition.state")
    if not stateOK then return false, stateErr and stateErr.code or "INVALID_SCHEMA" end
    local palette = self.palette
    if not palette or not palette.viewHost then return false, "PANEL_ERROR" end
    local ok, err = palette:OpenView(factory, {
        extensionID = owner,
        panelID = panelID,
        session = session,
        generation = generation,
    }, state)
    if not ok then return false, err or "PANEL_ERROR" end
    return result
end

function Executor:_OpenPanel(item, row, panelID, state, session, generation)
    local owner = extensionID(row, item)
    local factory = owner and I.Registry and I.Registry:GetPanel(owner, panelID)
    if not factory then return false, "COMMAND_NOT_FOUND" end
    state = state or {}
    local stateOK, stateErr = I.Registry:ValidateSchema(state, factory.stateSchema or {}, "action.state")
    if not stateOK then return false, stateErr and stateErr.code or "INVALID_SCHEMA" end
    local palette = self.palette
    if not palette then return false, "PANEL_ERROR" end
    local mounted, mountErr = palette:OpenView(factory, {
        extensionID = owner,
        panelID = panelID,
        session = session,
        generation = generation,
    }, state)
    if not mounted then return false, mountErr or "PANEL_ERROR" end
    return mounted
end

function Executor:_CommandIntent(command, context)
    if type(command.intentFactory) == "function" then
        local ok, intent = xpcall(function()
            return command.intentFactory(context)
        end, function() return "CALLBACK_ERROR" end)
        if not ok then return nil, "CALLBACK_ERROR" end
        return intent
    end
    if type(command.intent) == "table" then return command.intent end
    if type(command.intent) == "string" and command.intent ~= "" then
        return {
            type = command.intent,
            version = command.intentVersion or 1,
            payload = command.payload or {},
        }
    end
end

function Executor:_Intent(item, actionID, row, session, generation)
    local command = item and item.command
    local owner = extensionID(row, item)
    local context = I.Context and I.Context:Snapshot() or {}
    local intent
    if command and type(command.itemIntent) == "function" then
        local ok, value = xpcall(function()
            return command.itemIntent(item, actionID, context)
        end, function() return "CALLBACK_ERROR" end)
        if not ok then return false, "CALLBACK_ERROR" end
        intent = value
    else
        local action = actionFor(item, actionID)
        if action and type(action.intent) == "table" then intent = action.intent end
    end
    if type(intent) ~= "table" then return false, "ACTION_UNAVAILABLE" end
    local result, err = I.Router and I.Router:Execute(intent, context, owner)
    if not result then return false, type(err) == "table" and err.code or err or "HANDLER_UNAVAILABLE" end
    local transitioned, transitionErr = self:_Transition(result, item, row, session, generation)
    if transitioned == false then return false, transitionErr end
    if result.closePalette and self.palette then self.palette:Hide("intent") end
    return result
end

function Executor:Execute(row, actionID)
    local palette = self.palette
    if not palette or not palette.visible then return false, "INVALID_STATE" end
    local valid, err = self:Validate(row)
    if not valid then return palette:RejectRow(row, err) end
    local item = row.item
    local command = item and item.command
    if type(command) ~= "table" then command = nil end
    local result, actionErr, handled

    if command and command.presentation == "row" and actionID == "default" then
        handled = true
        local context = I.Context and I.Context:Snapshot() or {}
        local intent, intentErr = self:_CommandIntent(command, context)
        if not intent then return false, intentErr or "ACTION_UNAVAILABLE" end
        result, actionErr = I.Router and I.Router:Execute(intent, context, extensionID(row, item))
        if not result then
            actionErr = type(actionErr) == "table" and actionErr.code or actionErr or "HANDLER_UNAVAILABLE"
        else
            result, actionErr = self:_Transition(result, item, row, palette.session, palette.generation)
        end
    elseif command and command.presentation == "custom-panel" and actionID == "default" then
        handled = true
        result, actionErr = self:_OpenPanel(item, row, command.panel, command.state or command.payload or {}, palette.session, palette.generation)
    end
    if handled then
        if succeeded(result) and palette.TouchRecent then palette:TouchRecent(item) end
        if succeeded(result) and type(result) == "table" and result.closePalette then palette:Hide("intent") end
        return result, actionErr
    end

    local action, interaction = actionFor(item, actionID)

    if action and action.kind == "provider" then
        result, actionErr = I.Providers:Execute(item, actionID, I.Context and I.Context:Snapshot() or {})
        if result then
            result, actionErr = self:_Transition(result, item, row, palette.session, palette.generation)
            if result and result.closePalette then palette:Hide("provider-action") end
        end
    elseif action and action.kind == "open-panel" then
        result, actionErr = self:_OpenPanel(item, row, action.panel, action.state or item.payload or {}, palette.session, palette.generation)
    elseif action and action.kind == "drag-spell" then
        result, actionErr = pickupSpell(action.spellID)
    elseif action and action.kind == "secure-spell" then
        local Lychee = _G.Lychee
        if Lychee and Lychee.Secure and Lychee.Secure.Policy and not Lychee.Secure.Policy:IsSpellAvailable(action.spellID) then
            return false, "ACTION_UNAVAILABLE"
        end
        if actionID == (interaction and interaction.primaryActionID or "") then return false, "ACTION_REQUIRES_HARDWARE_CLICK" end
        result, actionErr = palette.secureBroker and palette.secureBroker:ShowFor(row, action, palette.session, palette.generation, item, row.extensionID) or false
        if result then result = { ok=true, awaitingHardwareClick=true, actionTitle=action.title } end
    else
        result, actionErr = self:_Intent(item, actionID, row, palette.session, palette.generation)
    end
    if succeeded(result) and not (type(result) == "table" and result.awaitingHardwareClick) and palette.TouchRecent then palette:TouchRecent(item) end
    return result, actionErr
end

function Executor:ExecutePrimary(row)
    local item = row and row.item
    local action = primaryActionFor(item)
    if item and item.providerID and not action then return false, "NO_ACTION" end
    -- A protected spell must receive the physical click on its prepared secure
    -- button.  Keyboard submission and scripted row activation stay honest.
    if action and action.kind == "secure-spell" then return false, "ACTION_REQUIRES_HARDWARE_CLICK" end
    return self:Execute(row, action and action.id or "default")
end

function Executor:BeginDrag(row)
    local valid, err = self:Validate(row)
    if not valid then return self.palette:RejectRow(row, err) end
    local drag = self:GetDragDescriptor(row.item)
    if not drag then return false, "DRAG_UNSUPPORTED" end
    if drag.type == "provider" then return I.Providers:Execute(row.item, drag.handler, I.Context and I.Context:Snapshot() or {}, true) end
    return pickupSpell(drag.spellID)
end

function Executor:ShowActions(row)
    local valid, err = self:Validate(row)
    if not valid then return false, err end
    if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return false, "MENU_UNAVAILABLE" end
    local item, session, generation = row.item, row.session, row.generation
    local actions = item.interaction and item.interaction.actions or {}
    if #actions == 0 then return false, "NO_ACTION" end
    local menu
    menu = MenuUtil.CreateContextMenu(row, function(_, root)
        for index = 1, #actions do
            local actionID, title = actions[index].id, actions[index].title
            root:CreateButton(title or actionID, function()
                if self.palette and self.palette.actionMenu == menu then self.palette.actionMenu = nil end
                local current, reason = self:Validate(row, session, generation, item)
                if not current then return false, reason end
                local result, actionError = self:Execute(row, actionID)
                if self.palette then self.palette:ReportActionResult(result, actionError) end
                return result
            end)
        end
    end)
    if self.palette then self.palette.actionMenu = menu end
    return true
end

function Executor:PrepareVisibleRows(rows)
    local palette = self.palette
    local broker = palette and palette.secureBroker
    if not broker or type(broker.Prepare) ~= "function" then return true end
    for rowIndex = 1, #(rows or {}) do
        local row = rows[rowIndex]
        local current = self:IsRowCurrent(row)
        if not current then
            palette:InvalidateRow(row)
        elseif row:IsShown() then
            self:ConfigureDragTarget(row.dragger or row, row.item)
            local action = primaryActionFor(row.item)
            if action and action.kind == "secure-spell" then
                local button = broker:Prepare(action, {
                    controller = palette,
                    row = row,
                    item = row.item,
                    extensionID = row.extensionID,
                    session = palette.session,
                    generation = palette.generation,
                })
                if button then
                    -- The target is declared by the generic list renderer.  Older
                    -- renderers retain the action-slot fallback during migration.
                    local target = row.primaryTarget or (row.actions and row.actions[1]) or row
                    if button._target ~= target then
                        button:SetParent(row)
                        button:ClearAllPoints()
                        if type(button.SetAllPoints) == "function" then button:SetAllPoints(target) else button:SetPoint("CENTER", target, "CENTER") end
                        button._target = target
                    end
                    if target and type(target.GetFrameLevel) == "function" and type(button.SetFrameLevel) == "function" then
                        local targetLevel = target:GetFrameLevel()
                        if type(targetLevel) == "number" and button:GetFrameLevel() ~= targetLevel + 1 then button:SetFrameLevel(targetLevel + 1) end
                    end
                    if row.secondary and row.secondary.SetFrameLevel and row.secondary:GetFrameLevel() ~= button:GetFrameLevel() + 1 then
                        row.secondary:SetFrameLevel(button:GetFrameLevel() + 1)
                    end
                    if row.dragger and row.dragger:IsShown() then row.dragger:Hide() end
                    if row.primaryTarget and type(row.primaryTarget.EnableMouse) == "function" then
                        row.primaryTarget:EnableMouse(false)
                    end
                end
            end
        end
    end
    return true
end
