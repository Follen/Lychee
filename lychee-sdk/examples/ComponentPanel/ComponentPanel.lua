-- Optional SDK example. Install this folder separately after Lychee.
local UI=assert(Lychee.UI and Lychee.UI.RuntimeVersion==1 and Lychee.UI,"UI Runtime 1 required")
local definition={type="Fragment",children={
    {type="Text",key="title",props={role="title",text="组件库示例",point={"TOPLEFT",nil,"TOPLEFT",18,-18}}},
    {type="Text",key="status",props={role="body",point={"TOPLEFT","title","BOTTOMLEFT",0,-16}},
        bind={text=function(_,state) return state.enabled and "状态：已开启" or "状态：已关闭" end}},
    {type="Button",key="toggle",props={width=160,height=30,text="切换状态",point={"TOPLEFT","status","BOTTOMLEFT",0,-16}},
        on={click=function(_,state,view) view:SetState("enabled",not state.enabled) end}},
    {type="Input",key="name",props={width=240,height=28,maxBytes=128,text="可编辑文字",point={"TOPLEFT","toggle","BOTTOMLEFT",0,-16}}},
}}
local handle,err=Lychee:RegisterProvider({
    id="example.component-panel",apiVersion="1.0.0",version="1.0.0",title="组件库示例",
    scope={products={"retail"}},i18n={enUS={TITLE="Component library example"},zhCN={TITLE="组件库示例"}},
    entries={{id="panel",title={key="TITLE"},actions={"open"}}},
    actions={open={title="打开",run=function() return {ok=true,view="panel",state={}} end}},
    views={panel=UI:AsView(definition)},
})
assert(handle,err and (err.code..": "..tostring(err.field)) or "example registration failed")
return handle
