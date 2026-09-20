# Retained UI library

[Contents](README.md) · [简体中文](../zh-CN/UI_LIBRARY.md)

UI Runtime **1** lives at `Lychee.UI`, independently from Provider API **1.0.0**. Check `Lychee.UI and Lychee.UI.RuntimeVersion == 1`. Definitions are static, created once and treated as read-only. Create allocates no Frames; first Update creates the tree and subsequent updates reuse it. There is no VirtualDOM, background renderer or implicit full GC. See [resources](MANAGED_RESOURCES.md) and [performance](PERFORMANCE.md).

```lua
local definition = {
    type = "Fragment",
    children = {
        { type = "Text", key = "title", props = { role = "heading" },
          bind = { text = "title" } },
        { type = "Button", key = "apply", props = { text = "应用", width = 100 },
          bind = { enabled = "enabled" },
          on = { click = function(props, state, view, button)
              props.onApply(props.id)
          end } },
    },
}
local view, err = Lychee.UI:Create(parent, definition)
assert(view, err)
assert(view:Update({ title = "显示设置", enabled = true, id = "display", onApply = Apply }))
view:Release("close")
```

Supply static point/points anchors for a real layout. Fragment adds no Frame; children attach directly to the parent. Display strings in the example should come from your provider's dictionary.

## Methods and updates

- UI:Create(parent,definition) returns a lazy instance or nil,"UI_DEFINITION".
- view:Update(props) shallow-copies current fields into an owned snapshot, evaluates bindings and applies only changed setters. Reusing/mutating the outer props table is allowed. Nested values remain references: pass scalar identity/version when their content changes. Bind functions must be pure.
- SetState(key,value) commits local state, skipping equal values; inactive instances return UI_INACTIVE.
- Get(key) returns native Frame/FontString/EditBox. GetComponent(key) returns the component/native adapter; Input has a style controller with SetInvalid.
- Release(reason) first invalidates interaction generation, clears props/state/input/focus/tasks, then hides the reusable structure. Repeated release does not repeat cancellation. Later Update rebinds it.
- Own(key,cancel) manages at most 64 mount-owned cancellation functions; replacing a key cancels the old one. It creates no timers and does not replace asynchronous generation checks.
- UI:AsView(definition,stateSchema?) creates a Provider view factory, default schema empty. Supply a matching schema for action state. It follows create/Mount/Update/Unmount/Dispose and caches one instance. One factory binds one contentFrame; changing parent returns UI_PARENT_CHANGED. Use separate factories for separate Hosts.

Update/SetState reentrancy returns false,"UI_BUSY". Release during callbacks requests cancellation and cleans up after the current update, returning UI_CANCELLED. Binding/construction/setter exceptions clean the mount and return false,error; cache applied values only after success. A native factory failure before returning its Frame makes construction terminal for that instance (UI_BUILD_FAILED); do not automatically loop creating replacement views, since native Frames cannot be reclaimed.

## Nodes, properties and events

Types: Fragment, Surface, Text, Icon, Button, Toggle, Input, Native. children is a fixed array; keys unique per tree, maximum depth 32. No cyclic definitions or node table reused in several positions. Use factories or separate views. Unknown static/bound properties and events fail at Create.

Dimensions are finite nonnegative numbers; alpha 0–1; maxLines/maxBytes nonnegative integers. Font role/inherited name are nonempty strings. Anchor positions are valid with finite offsets; textInsets has four finite numbers. Validate all dynamic bindings before committing; invalid values return UI_PROPERTY_VALUE and first-update failure creates no Frames. Bind functions run once per update and use owned scratch cleared on release.

props defines static style; bind maps a property to a props field or pure function(props,state). State changes update properties, not the entire element tree. Common properties are width/height/alpha/visible; supported controls add text/enabled/checked/texture/color/role/justifyH/justifyV/wordWrap/maxLines. Input adds maxBytes/multiline/autoFocus/textInsets/invalid. Ordinary inputs use the theme surface; variant="search" leaves appearance to the search component. Button typography applies to its label.

point is `{point,relativeObjectOrKey,relativePoint,x,y}`; referenced keys must already be created. points allows multiple anchors, allPoints uses the parent. Static styles apply only at creation; changing fields belong in bind. Do not use bindings for per-frame font/layout changes.

Events: click/change/enter/leave/enterPressed/escape, plus supported native OnClick/OnTextChanged/OnEnter/OnLeave/OnEnterPressed/OnEscapePressed/OnMouseDown. Handlers receive `(props,state,view,frame,...)`; bridges install once and read fresh props. Library SetText during Update/Release does not trigger business change. Click nodes remember press-time binding identity; rebind/unmount/reopen invalidates old presses. Overwriting scripts through Get transfers event and identity responsibility to your code.

## Native adapters and combat

```lua
local node = {
    type = "Native", key = "results",
    create = function(parent)
        local list = ExistingResultList:Create(parent, controller)
        return {
            frame = list.frame,
            Update = function(self, props) list:SetItems(props.items) end,
            Release = function(self, reason) list:Clear() end,
        }
    end,
}
```

Native returns a table with frame; Update/Release are optional. Reuse bounded existing pools instead of allocating one control per record or a second generic tree reconciler. Keep partially created objects reachable. Definition functions are long-lived and must not capture one query/Entry/context; receive those via props and release references.

In combat Update/SetState returns UI_COMBAT without native mutations. Release invalidates Lua interaction immediately but skips library focus/text/hide calls. Native Release must likewise clear business references without mutating protected Frames. The Host's secure hiding remains responsible for the main window. A later safe mount restores binding; no extra permanent recovery event is added.

## Cost and evidence

Tree size bounds object count: zero native Frames before mount, no new Frames/scripts on warm updates, zero active work after release. The fixed 1000 unchanged-update allocation comparison is 64 KiB; an offline substitute measured 0.00 KiB, not native texture/font/Frame memory. Run `lua tests/ui/ui_runtime.lua` and `lua tests/performance/performance_ui.lua --check` in the repository. Tests cover props mutation/state/rebinding/reopen/failure/reentrancy/combat/Native/AsView; actual rendering and protected behavior require client tests.

Historical native evidence: wow-ui-source/retail, requestedRef=latest, resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`. SimpleScriptRegionAPIDocumentation.lua:640 describes SetScript and script binding restrictions; SimpleEditBoxAPIDocumentation.lua:20 describes ClearFocus with ScriptedInput forbidden-aspect checks. Stable bridges do not bypass these restrictions.
