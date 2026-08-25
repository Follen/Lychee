local I = _G.LycheeInternal
local Router={handlers={},byExt={}}
I.Router=Router
local function failure(code, field, ext) return nil,{code=code,field=field,extensionID=ext,retryable=false} end
local function integer(value) return type(value)=="number" and value==math.floor(value) end
function Router:Add(extensionID, descriptor)
    if type(extensionID)~="string" or type(descriptor)~="table" or type(descriptor.type)~="string" or descriptor.type=="" or not integer(descriptor.version or 1) or (type(descriptor.handle)~="function" and type(descriptor.execute)~="function") then return nil,{code="INVALID_SCHEMA",field="handler",retryable=false} end
    local list=self.handlers[descriptor.type] or {}
    for i=1,#list do if list[i].ext==extensionID then return nil,{code="DUPLICATE_ID",field="type",extensionID=extensionID,retryable=false} end end
    list[#list+1]={ext=extensionID,handler=descriptor}; self.handlers[descriptor.type]=list
    self.byExt[extensionID]=self.byExt[extensionID] or {}; self.byExt[extensionID][#self.byExt[extensionID]+1]=descriptor.type
    return true
end
function Router:RemoveExtension(extensionID)
    local types=self.byExt[extensionID]; if not types then return end
    for i=1,#types do local list=self.handlers[types[i]]; if list then for j=#list,1,-1 do if list[j].ext==extensionID then table.remove(list,j) end end; if #list==0 then self.handlers[types[i]]=nil end end end
    self.byExt[extensionID]=nil
end
local function validateTransition(extensionID, transition)
    if type(transition)~="table" then return failure("INTENT_INVALID","transition",extensionID) end
    if transition.type=="builtin-panel" and extensionID:sub(1,7)=="builtin" then
        if type(transition.panelID)~="string" then return failure("INTENT_INVALID","panelID",extensionID) end
        local panel=I.Registry:GetPanel(extensionID,transition.panelID); if not panel then return failure("COMMAND_NOT_FOUND","panelID",extensionID) end
        if transition.state~=nil then local ok,why=I.Boundary:Validate(transition.state,"transition.state"); if not ok then return nil,why end end
        return true
    end
    if transition.type~="custom-panel" or type(transition.panelFactoryID)~="string" then return failure("INTENT_INVALID","transition",extensionID) end
    local panel=I.Registry:GetPanel(extensionID,transition.panelFactoryID); if not panel then return failure("COMMAND_NOT_FOUND","panelFactoryID",extensionID) end
    if transition.state==nil then transition.state={} end
    local ok,why=I.Registry:ValidateSchema(transition.state,panel.stateSchema,"transition.state"); if not ok then return nil,why end
    return true
end
function Router:Execute(intent, context)
    if type(intent)~="table" or type(intent.type)~="string" or not integer(intent.version or 1) then return nil,{code="INTENT_INVALID",retryable=false} end
    local valid,why=I.Boundary:Validate(intent,"intent"); if not valid then return nil,why end
    local list=self.handlers[intent.type]; if not list or #list==0 then return nil,{code="HANDLER_UNAVAILABLE",retryable=false} end
    local record; for i=1,#list do if I.Registry:IsEnabled(list[i].ext) then record=list[i]; break end end
    if not record then return nil,{code="EXTENSION_DISABLED",retryable=false} end
    local handler=record.handler; if handler.version~=intent.version then return failure("INTENT_INVALID","version",record.ext) end
    if handler.schema then valid,why=I.Registry:ValidateSchema(intent.payload or {},handler.schema,"payload"); if not valid then return nil,why end end
    local ok,result
    if type(handler.execute)=="function" then ok,result=xpcall(function() return handler.execute(intent,context) end,function() return nil end) else ok,result=xpcall(function() return handler.handle(intent.payload or {},context) end,function() return nil end) end
    if not ok then return failure("CALLBACK_ERROR",nil,record.ext) end
    if type(result)~="table" then return failure("INTENT_INVALID","result",record.ext) end
    valid,why=I.Boundary:Validate(result,"result"); if not valid then return nil,why end
    if result.ok~=true and result.ok~=false then return failure("INTENT_INVALID","ok",record.ext) end
    if result.transition then valid,why=validateTransition(record.ext,result.transition); if not valid then return nil,why end end
    return result
end
function Router:ResolvePanel(extensionID,panelID) return I.Registry:GetPanel(extensionID,panelID) end
