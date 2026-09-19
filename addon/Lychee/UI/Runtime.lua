local Lychee = _G.Lychee or {}
_G.Lychee = Lychee
Lychee.UI = Lychee.UI or {}
local UI = Lychee.UI
local View = {}; View.__index = View
local EMPTY = {}
local TYPES = { Fragment=true, Surface=true, Text=true, Icon=true, Button=true, Toggle=true, Input=true, Native=true }
local EVENTS = { click="OnClick", change="OnTextChanged", enter="OnEnter", leave="OnLeave", enterPressed="OnEnterPressed", escape="OnEscapePressed" }
for _,name in ipairs({"OnClick","OnTextChanged","OnEnter","OnLeave","OnEnterPressed","OnEscapePressed","OnMouseDown"}) do EVENTS[name]=name end
local PROPERTIES={text=true,visible=true,enabled=true,checked=true,texture=true,color=true,role=true,width=true,height=true,alpha=true,justifyH=true,justifyV=true,wordWrap=true,nonSpaceWrap=true,maxLines=true,maxBytes=true,multiline=true,autoFocus=true,invalid=true,selected=true}
local STATIC={point=true,points=true,allPoints=true,textInsets=true,create=true,font=true,primary=true,direction=true,radius=true,colors=true,textColors=true,variant=true}
local POINTS={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function finite(value) return type(value)=="number" and value==value and value>-math.huge and value<math.huge end
local function validPoint(value)
    if type(value)~="table" or not POINTS[value[1]] or (value[3]~=nil and not POINTS[value[3]]) then return false end
    local relative=type(value[2])
    return (value[2]==nil or relative=="string" or relative=="table" or relative=="userdata")
        and (value[4]==nil or finite(value[4])) and (value[5]==nil or finite(value[5]))
end
local function validValue(key,value)
    if key=="width" or key=="height" or key=="radius" then return finite(value) and value>=0 end
    if key=="alpha" then return finite(value) and value>=0 and value<=1 end
    if key=="maxLines" or key=="maxBytes" then return finite(value) and value>=0 and value==math.floor(value) end
    if key=="text" then return value==nil or type(value)=="string" or finite(value) end
    if key=="texture" then return value==nil or type(value)=="string" or (finite(value) and value>=0) end
    if key=="role" or key=="font" then return type(value)=="string" and value~="" end
    if key=="color" then return value==nil or type(value)=="string" end
    if key=="justifyH" then return value=="LEFT" or value=="CENTER" or value=="RIGHT" end
    if key=="justifyV" then return value=="TOP" or value=="MIDDLE" or value=="BOTTOM" end
    if key=="direction" then return value=="up" or value=="down" or value=="left" or value=="right" end
    if key=="variant" then return value=="search" or value=="default" end
    if key=="point" then return validPoint(value) end
    if key=="points" then
        if type(value)~="table" then return false end
        for _,p in ipairs(value) do if not validPoint(p) then return false end end
        return true
    end
    if key=="textInsets" then
        if type(value)~="table" or #value~=4 then return false end
        for index=1,4 do if not finite(value[index]) then return false end end
        return true
    end
    if key=="colors" or key=="textColors" then
        if type(value)~="table" then return false end
        for _,token in pairs(value) do if type(token)~="string" then return false end end
        return true
    end
    if key=="create" then return type(value)=="function" end
    return value==nil or type(value)=="boolean"
end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function clear(t) for key in pairs(t) do t[key]=nil end end
local function validate(def, keys, visiting, depth)
    if type(def)~="table" or not TYPES[def.type] or depth>32 or visiting[def] then return false end
    if def.key~=nil then
        if type(def.key)~="string" or keys[def.key] then return false end
        keys[def.key]=true
    end
    if def.props~=nil and type(def.props)~="table" then return false end
    if def.bind~=nil and type(def.bind)~="table" then return false end
    if def.on~=nil and type(def.on)~="table" then return false end
    for key,value in pairs(def.props or EMPTY) do if (not PROPERTIES[key] and not STATIC[key]) or not validValue(key,value) then return false end end
    for key,value in pairs(def.bind or EMPTY) do if not PROPERTIES[key] or (type(value)~="string" and type(value)~="function") then return false end end
    for key,value in pairs(def.on or EMPTY) do if not EVENTS[key] or type(value)~="function" then return false end end
    if def.children~=nil and type(def.children)~="table" then return false end
    if def.update~=nil and type(def.update)~="function" then return false end
    if def.release~=nil and type(def.release)~="function" then return false end
    if def.type=="Native" and type(def.create or (def.props and def.props.create))~="function" then return false end
    visiting[def]=true
    for _,child in ipairs(def.children or EMPTY) do if not validate(child,keys,visiting,depth+1) then return false end end
    -- A definition node has one position/parent. Reusing an anonymous table in
    -- two positions would otherwise alias its retained native object.
    return true
end

local function compile(view,def)
    local node={def=def,applied={},has={},pending={}}
    view.byDefinition[def]=node;view.nodes[#view.nodes+1]=node
    if def.key then view.keys[def.key]=node end
    for _,child in ipairs(def.children or EMPTY) do compile(view,child) end
end

-- Definitions are immutable structure, never a render-time virtual tree.
function UI:Create(parent, definition)
    if not parent or not validate(definition,{}, {},1) then return nil,"UI_DEFINITION" end
    local view=setmetatable({parent=parent,definition=definition,nodes={},byDefinition={},keys={},props={},state={},tasks={},generation=0},View)
    compile(view,definition)
    return view
end
function View:Get(key) local node=self.keys[key]; return node and node.frame end
function View:GetComponent(key) local node=self.keys[key]; return node and node.component end

local function set(node,key,value)
    local frame,component=node.frame,node.component
    local label=component and component.label or frame
    if node.applied[key]==value and node.has[key] then
        -- EditBox text is also mutable through typing. Props remain the source
        -- of truth for a controlled field even when the binding is unchanged.
        if key~="text" or node.def.type~="Input" or frame:GetText()==(value or "") then return end
    end
    if key=="text" then
        if component and component.SetText then component:SetText(value or "") else frame:SetText(value or "") end
    elseif key=="visible" then if value==false then frame:Hide() else frame:Show() end
    elseif key=="enabled" then
        if component and component.SetEnabled then component:SetEnabled(value)
        elseif frame.SetEnabled then frame:SetEnabled(value~=false)
        elseif value==false then frame:Disable() else frame:Enable() end
    elseif key=="checked" then frame:SetChecked(value,true)
    elseif key=="texture" then frame:SetTexture(value)
    elseif key=="color" then
        if component and component.SetColor then component:SetColor(value)
        elseif node.def.type=="Icon" then UI.Theme:SetColorTexture(frame,value)
        else UI.Theme:SetTextColor(label,value) end
    elseif key=="role" then UI.Theme:SetFont(label,value)
    elseif key=="width" then frame:SetWidth(value)
    elseif key=="height" then frame:SetHeight(value)
    elseif key=="alpha" then frame:SetAlpha(value)
    elseif key=="justifyH" then label:SetJustifyH(value)
    elseif key=="justifyV" then label:SetJustifyV(value)
    elseif key=="wordWrap" then label:SetWordWrap(value)
    elseif key=="nonSpaceWrap" then label:SetNonSpaceWrap(value)
    elseif key=="maxLines" then label:SetMaxLines(value)
    elseif key=="maxBytes" then frame:SetMaxBytes(value)
    elseif key=="multiline" then frame:SetMultiLine(value)
    elseif key=="autoFocus" then frame:SetAutoFocus(value)
    elseif key=="invalid" then component:SetInvalid(value)
    elseif key=="selected" then component:SetSelected(value)
    else error("UI_PROPERTY: "..tostring(key)) end
    node.applied[key],node.has[key]=value,true
end

local function point(view,frame,parent,p)
    local relative=p[2]
    if type(relative)=="string" then relative=view:Get(relative) end
    frame:SetPoint(p[1],relative or parent,p[3] or p[1],p[4] or 0,p[5] or 0)
end
local function configure(view,node,parent)
    local def,frame=node.def,node.frame
    local props=def.props or EMPTY
    if def.type=="Fragment" then return end
    if props.allPoints then frame:SetAllPoints(parent) end
    if props.point then point(view,frame,parent,props.point) end
    for _,p in ipairs(props.points or EMPTY) do point(view,frame,parent,p) end
    if props.textInsets then frame:SetTextInsets(unpack(props.textInsets)) end
    for key,value in pairs(props) do
        if key~="point" and key~="points" and key~="allPoints" and key~="textInsets" and key~="create"
            and key~="font" and key~="primary" and key~="direction" and key~="radius" and key~="colors" and key~="textColors" and key~="variant" then set(node,key,value) end
    end
    for event,fn in pairs(def.on or EMPTY) do
        local script=EVENTS[event]
        local previous=frame:GetScript(script)
        frame:SetScript(script,function(object,...)
            local generation=view.generation
            local valid=view.active and not view.busy and not combat()
            if script=="OnClick" then
                local pressed=node.pressed
                node.pressed=nil
                if pressed and pressed~=generation then valid=false end
                if node.applied.enabled==false then valid=false end
            end
            -- Preserve intrinsic pointer/focus bookkeeping while inactive.
            -- A previous click can itself be an action, so reject stale clicks
            -- before invoking it. External code may release/rebind this view.
            if previous and (script~="OnClick" or valid) then previous(object,...) end
            if valid and view.active and not view.busy and not combat() and view.generation==generation then
                return fn(view.props,view.state,view,object,...)
            end
        end)
    end
    if def.on and (def.on.click or def.on.OnClick) then
        local previous=frame:GetScript("OnMouseDown")
        frame:SetScript("OnMouseDown",function(object,...)
            node.pressed=view.generation
            if previous then previous(object,...) end
        end)
    end
end
local function build(view,def,parent)
    local node=view.byDefinition[def]
    if node.buildFailed then error("UI_BUILD_FAILED") end
    if not node.frame then
        node.constructing=true
        local props=def.props or EMPTY
        if def.type=="Fragment" then node.frame=parent
        elseif def.type=="Text" then node.frame=parent:CreateFontString(nil,"OVERLAY",props.font or "GameFontNormal");node.frame:SetJustifyH("LEFT")
        elseif def.type=="Icon" then node.frame=parent:CreateTexture(nil,"ARTWORK")
        elseif def.type=="Surface" then node.component=UI.Components:CreateSurface(parent,{allPoints=props.allPoints~=false});node.frame=node.component.frame
        elseif def.type=="Button" then
            node.component=UI.Components:CreateNavigationButton(parent,{width=props.width,height=props.height,text=props.text,primary=props.primary,direction=props.direction})
            node.frame=node.component.frame
        elseif def.type=="Toggle" then node.frame=UI.Components:CreateToggle(parent)
        elseif def.type=="Input" then
            node.frame=CreateFrame("EditBox",nil,parent)
            node.frame:SetAutoFocus(false)
            if props.variant~="search" then node.component=UI.Components:StyleEditBox(node.frame) end
        elseif def.type=="Native" then
            node.component=(def.create or props.create)(parent)
            if type(node.component)~="table" or not node.component.frame then error("UI_NATIVE") end
            node.frame=node.component.frame
        end
        node.constructing=false
    end
    node.needsRelease=true
    if not node.configured then configure(view,node,parent);node.configured=true end
    for _,child in ipairs(def.children or EMPTY) do build(view,child,node.frame) end
end

local function copyProps(view,props)
    local changed=false
    for key in pairs(view.props) do if props[key]==nil then view.props[key]=nil;changed=true end end
    for key,value in pairs(props) do if view.props[key]~=value then view.props[key]=value;changed=true end end
    if changed then view.generation=view.generation+1 end
end
local function update(view,props)
    copyProps(view,props)
    -- Resolve and validate every binding before creating or changing any native
    -- object. Scratch values are per view/node and never cross async callbacks.
    for _,node in ipairs(view.nodes) do
        for key,binding in pairs(node.def.bind or EMPTY) do
            local value
            if type(binding)=="function" then value=binding(view.props,view.state) else value=view.props[binding] end
            if not validValue(key,value) then error("UI_PROPERTY_VALUE: "..key) end
            node.pending[key]=value
        end
    end
    build(view,view.definition,view.parent)
    view.active=true
    for _,node in ipairs(view.nodes) do
        if node.def.type~="Fragment" then
            if node.def.type=="Input" and not node.mounted and node.def.props and node.def.props.text~=nil
                and not (node.def.bind and node.def.bind.text) then set(node,"text",node.def.props.text) end
            for key,binding in pairs(node.def.bind or EMPTY) do
                set(node,key,node.pending[key])
            end
            if node.def.type=="Native" and node.component.Update then node.component:Update(view.props,view.state,view) end
            if not node.mounted then
                if node.applied.visible~=false then node.frame:Show() end
                node.mounted=true
            end
        end
    end
    if view.definition.update then view.definition.update(view.props,view.state,view) end
end
function View:Update(props)
    if self.busy then return false,"UI_BUSY" end
    if combat() then return false,"UI_COMBAT" end
    if type(props)~="table" then return false,"UI_PROPS" end
    self.needsCleanup=true
    self.busy=true
    local ok,err=pcall(update,self,props)
    self.busy=false
    if not ok or self.cancelReason then
        for _,node in ipairs(self.nodes) do
            if node.constructing then
                if node.def.type~="Native" and not node.frame then node.buildFailed=true end
                node.constructing=false
            end
        end
        local reason=self.cancelReason or "error";self.cancelReason=nil
        self:Release(reason)
        return false,ok and "UI_CANCELLED" or err
    end
    return true
end
function View:SetState(key,value)
    if self.busy then return false,"UI_BUSY" end
    if type(key)~="string" then return false,"UI_STATE" end
    if not self.active then return false,"UI_INACTIVE" end
    if combat() then return false,"UI_COMBAT" end
    if self.state[key]==value then return true end
    self.state[key]=value;self.generation=self.generation+1
    return self:Update(self.props)
end
-- Optional cancellation ownership. Stable keys replace, never accumulate callbacks.
function View:Own(key,cancel)
    if type(key)~="string" or type(cancel)~="function" or not self.active then return false,"UI_TASK" end
    if not self.tasks[key] then
        local count=0;for _ in pairs(self.tasks) do count=count+1 end
        if count>=64 then return false,"UI_TASK_LIMIT" end
    end
    local old=self.tasks[key];self.tasks[key]=cancel
    local generation=self.generation
    if old then pcall(old,"replace") end
    if not self.active or self.generation~=generation or self.tasks[key]~=cancel then
        if self.tasks[key]==cancel then self.tasks[key]=nil;pcall(cancel,"cancelled") end
        return false,"UI_CANCELLED"
    end
    return true
end
function View:Release(reason)
    if self.busy then
        if not self.releasing then self.active=false;self.cancelReason=reason or "release" end
        return false,"UI_BUSY"
    end
    if not self.active and not self.needsCleanup then return true end
    self.busy=true;self.releasing=true;self.active=false;self.generation=self.generation+1
    clear(self.props);clear(self.state)
    for key,cancel in pairs(self.tasks) do self.tasks[key]=nil;pcall(cancel,reason or "release") end
    local restricted=combat()
    for _,node in ipairs(self.nodes) do
        if node.pressed then node.pressed=-1 end
        if node.needsRelease then
            node.needsRelease=false
            node.mounted=false
            if node.component and node.component.Release then pcall(node.component.Release,node.component,reason or "release") end
            if UI.Motion and node.def.type~="Fragment" and node.frame then
                pcall(UI.Motion.Cancel,UI.Motion,node.frame,true)
                if node.component and node.component.label and node.component.label~=node.frame then
                    pcall(UI.Motion.Cancel,UI.Motion,node.component.label,true)
                end
                if node.def.type=="Toggle" and node.frame.FinishMotion then pcall(node.frame.FinishMotion,node.frame) end
            end
            if not restricted and node.def.type~="Fragment" and node.frame then
                if node.frame.ClearFocus then pcall(node.frame.ClearFocus,node.frame) end
                if node.def.type=="Input" then pcall(node.frame.SetText,node.frame,"") end
                pcall(node.frame.Hide,node.frame)
            end
        end
        for key in pairs(node.def.bind or EMPTY) do node.applied[key],node.has[key]=nil,nil end
        clear(node.pending)
    end
    if self.definition.release then pcall(self.definition.release,reason or "release",self) end
    self.cancelReason=nil
    self.busy=false;self.releasing=false;self.needsCleanup=false
    return true
end
function UI:AsView(definition,stateSchema)
    local cached
    return {stateSchema=stateSchema or {},create=function(context)
        if not cached then
            local view,err=UI:Create(context.contentFrame,definition)
            if not view then error(err) end
            cached={view=view}
            function cached:Mount(ctx,state)
                if self.view.parent~=ctx.contentFrame then error("UI_PARENT_CHANGED") end
                local ok,why=self.view:Update(state or EMPTY);if not ok then error(why) end
            end
            function cached:Update(state) local ok,why=self.view:Update(state or EMPTY);if not ok then error(why) end end
            function cached:Unmount(reason) self.view:Release(reason) end
            function cached:Dispose(reason) if self.view.active then self.view:Release(reason) end end
        end
        return cached
    end}
end
UI.RuntimeVersion=1
