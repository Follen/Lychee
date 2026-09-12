# 保留式 UI 库

当前 SDK 为 API 2 / revision 7，UI Runtime 仍为 1。新增公共资源生命周期、角色设置和有界缓存，见 [托管资源协议](MANAGED_RESOURCES.md)；旧 revision 1–6 的 Provider 保持兼容。

UI Runtime 1 位于 `Lychee.UI`，与 Provider API 2.6 的注册协议独立。先检查
`Lychee.UI and Lychee.UI.RuntimeVersion == 1`。声明结构只创建一次并视为只读；
`Create` 不创建 Frame，首次 `Update` 才创建，后续复用固定树。没有 VirtualDOM、
后台渲染循环或隐式完整 GC。

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

示例省略实际页面锚点；字段和按钮需要由静态 `props.point/points` 定位。
`Fragment` 不新增 Frame，子节点直接挂在传入父级。

## Interface

- `UI:Create(parent, definition)` 返回懒创建实例，错误为 `nil, "UI_DEFINITION"`。
- `view:Update(props)` 同步浅拷贝当前 props 字段到实例自有快照，读取 bind，
  仅变化值调用 setter。输入 props 表可重复使用或修改；嵌套值按引用对待，
  它们的内容变化需另传标量版本/身份。绑定函数必须无副作用。
- `view:SetState(key, value)` 更新实例状态并提交，同值不刷新。未挂载返回 `UI_INACTIVE`。
- `view:Get(key)` 返回原生 Frame/FontString/EditBox，`GetComponent(key)` 返回现有
  Components 控制器或 Native adapter；普通 Input 返回带 `SetInvalid` 的样式控制器。
- `view:Release(reason)` 先失效交互代次，清 props/state、输入文本与焦点、活动任务，
  再隐藏固定结构。重复释放不重复取消任务。下次 Update 重新绑定。
- `view:Own(key, cancel)` 挂载期间托管取消函数；同 key 替换并取消旧函数，至多64个。
  不创建 timer，不代替业务异步任务的结果代次检查。
- `UI:AsView(definition, stateSchema?)` 返回包含 stateSchema 的 Provider/ViewHost 工厂（默认空表；动作传入状态时须提供对应规范），兼容 create→Mount→Update→
  Unmount→Dispose 顺序，并缓存一个实例。一个工厂绑定一个 contentFrame；更换父级
  返回 `UI_PARENT_CHANGED`，应给新宿主使用独立工厂，不能共享活动实例。

Update/SetState 重入返回 `false, "UI_BUSY"`；回调内 Release 先请求取消，当前更新结束
清理并返回 `UI_CANCELLED`。绑定、创建或 setter 抛错将清理本次挂载，返回 `false, error`；
缓存只在 setter 成功后更新。调用方需处理错误，不能把失败当成已显示。
内置控件工厂若在返回 frame 前发生原生构造错误，该实例终止构造，后续 Update 返回
`UI_BUILD_FAILED`；不要自动创建新 view 循环重试，避免累积不可销毁的原生 Frame。

## 节点与绑定

节点类型为 Fragment、Surface、Text、Icon、Button、Toggle、Input、Native。
`children` 是固定数组；同树 key 唯一、最大结构深度32，禁止循环定义或同一节点表
出现在多个树位置。复用结构时使用工厂生成不同节点表，或创建独立 view。
未知静态属性、绑定属性和事件名在 Create 时拒绝，避免拼写错误悄悄失效。
尺寸必须为非负有限数，alpha 在0到1之间，maxLines/maxBytes 为非负整数；字体角色及
继承字体名使用非空字符串，锚点为合法位置及有限偏移，textInsets 是四个有限数。
动态 bind 的所有值在提交前统一校验；非法值返回 UI_PROPERTY_VALUE，首次提交不会
创建 Frame。绑定函数每轮只调用一次，结果保存在实例自有 scratch 中并在释放时清掉。
`props` 是静态样式；`bind = { text = "title" }` 从最新 props 取值；
`bind = { text = function(props, state) return state.status end }` 支持局部状态。
局部状态并不意味着每次重建元素；函数只计算对应属性。

共同属性包括 width、height、alpha、visible；具体控件支持 text、enabled、checked、
texture、color、role、justifyH/justifyV、wordWrap、maxLines。Input 另支持 maxBytes、
multiline、autoFocus、textInsets、invalid；普通输入自动应用主题表面，
`variant="search"` 由搜索组件自己管理外观。Button 的字体与排版应用到其 label。
静态 point 为 `{point, relativeObjectOrKey, relativePoint, x, y}`；relative key 必须
先于当前节点创建。points 可放多组；allPoints 使用父级。静态样式只在创建时应用，
需要变化的字段放在 bind。不能使用绑定表按帧改变字体/布局。

事件支持 click/change/enter/leave/enterPressed/escape，也接受对应原生 OnClick、
OnTextChanged、OnEnter、OnLeave、OnEnterPressed、OnEscapePressed、OnMouseDown。
handler 参数为 `(props, state, view, frame, ...)`；脚本桥接首次创建时安装一次，
调用时读取最新 props。Update/Release 引发的 SetText 不回调业务 change。
有 click 的节点记录鼠标按下时的绑定代次；重绑、卸载、重开后的旧按下不触发新动作。
直接用 Get 后覆写这些脚本，表示调用方接管相应事件及身份保护。

## Native 与生命周期

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

Native 必须返回含 frame 的 table。Update/Release 可选；列表复用原有有界池，
不另建全量行或泛型树协调器。create 若会分步创建原生对象，adapter 应先保留控制器，
不要创建一半 Frame 后抛错并丢失引用。宿主无法回收已创建的 WoW Frame。
定义函数保持长期有效，不捕获本次条目/context；这些值从 props 接收并在 Release 断开。

战斗中 Update/SetState 返回 UI_COMBAT，不修改原生对象；Release 立即使 Lua 交互无效，
但跳过本库的焦点/文本/隐藏等原生修改。Native Release 必须同样自行区分战斗约束，
只清业务引用，不修改受保护 Frame。主面板的安全隐藏仍由既有安全状态处理。
退出战斗后的重新挂载会恢复正常绑定；库不建立额外常驻恢复事件。

## 成本与验证

创建结构数等于声明树大小；未挂载零 Frame，热更新无新增 Frame/script，关闭零活动任务。
1000次无变化 Update 的新增累计分配预算64 KiB；`lua tests/ui_runtime.lua` 当前离线替身
结果为0.00 KiB。该结果不代表游戏引擎的纹理、字体或 Frame 原生内存。
既有虚拟列表预算继续由 `lua tests/performance_ui.lua --check` 验证。
测试覆盖 props 原表修改、状态、按下后重绑/重开、部分失败、重入、战斗、Native 清理及
AsView。真实客户端像素表现、战斗安全和插件内存统计仍需实机验证。

版本查档：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，
resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。
SetScript 依据 `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:640`，
签名包含 `scriptTypeName`、可空 `LuaFunctionReference`，并检查 ScriptBindings 禁止状态。
运行时使用稳定脚本桥接，不尝试绕过受限操作；ClearFocus 依据
`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:20`，
excerpt 为 `Name = "ClearFocus"` 与 `ChecksForbiddenAspects ... ScriptedInput`。
