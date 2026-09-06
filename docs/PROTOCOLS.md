# Lychee 公共协议

> 状态：Public Protocol v1
>
> 本文是 Lychee Host、内置模块和第三方 AddOn 共享的字段与运行时行为合同。
> [ARCHITECTURE.md](ARCHITECTURE.md) 解释系统分层，[SDK.md](SDK.md) 提供接入教程；发生冲突时以本文为准。

## 1. 权威性与版本

运行时公共 facade 为 `_G.Lychee`，SDK 不是独立 AddOn。当前版本：

```lua
Lychee.API_VERSION  = 1 -- major
Lychee.API_REVISION = 1 -- compatible additions
Lychee:Supports(apiVersion, minApiRevision) -> boolean
```

- `apiVersion` 必须精确匹配 major；未知 major 不以“大于等于”方式兼容。
- 增加可选字段、动作种类或方法时提升 `API_REVISION`。
- 删除字段、改变类型或改变已有语义时提升 `API_VERSION`。
- Extension 声明 `apiVersion` 和可选的 `minApiRevision`；不支持时返回 `UNSUPPORTED_API`。
- 兼容适配只在注册/attach 阶段进行，不进入每次按键的查询热路径。

## 2. Extension 与注册事务

第三方通过 `_G.Lychee:RegisterExtension(descriptor)` 获得草稿句柄。典型流程：

```lua
local extension, err = Lychee:RegisterExtension({
    id = "sample-extension",
    apiVersion = 1,
    minApiRevision = 1,
    title = { default = "Sample", zhCN = "示例" },
    version = "1.0.0",
})
if not extension then return end

extension:RegisterCommand(command)
extension:RegisterSearchSource(source)
extension:RegisterCapabilityProvider(provider)
extension:RegisterIntentHandler(handler)
extension:RegisterPanelFactory(panel)

local committed, commitErr = extension:Commit()
```

Extension descriptor 的稳定字段：

| 字段 | 约束 |
| --- | --- |
| `id` | `[a-z0-9][a-z0-9.-]{0,63}`，全局稳定且不可复用旧句柄 |
| `apiVersion` | 必填 integer，当前为 `1` |
| `minApiRevision` | 可选 integer，默认 `1` |
| `title` | 必填 string 或 locale table；locale table 必须有 `default` |
| `version` | 必填 string，插件自己的显示版本 |
| `icon` | 可选 texture path 或 fileID |
| `invalidationKeys` | 可选稳定 key 白名单 |
| `onHostAttached/onHostDetached` | 可选生命周期回调 |
| `onEnabled/onDisabled` | 可选启停回调 |

状态与事务规则：

```text
draft -> pending/registered -> enabled <-> disabled -> retiring -> removed
```

- `Register*` 只写草稿；草稿不可搜索、不可调度、不可绘制 UI。
- 同一 Extension 内的子声明 ID 必须唯一；重复 Extension ID 不能覆盖已提交对象。
- 任一暂存校验失败会使草稿 `invalid`，只能 `Abort()`；不得发布部分声明。
- `Commit()` 一次校验版本、交叉引用、schema 和数量上限。失败释放预留 ID，成功后注册面关闭。
- Host 尚未 ready 时，成功提交进入 `pending`，ready 后 attach；已 ready 时直接进入 `registered`。
- `SetEnabled` 只改变 owner 位；实际可用状态还取决于用户设置、Host 兼容性和健康状态。
- `Unregister()` 按句柄身份幂等执行清理，移除搜索索引、Command、Provider、Handler、Panel 和待处理任务。
- `Commit`/`Abort` 后继续 `Register*` 返回 `REGISTRATION_CLOSED`；`removed` 句柄不能重新启用。

第三方不得保存或修改 registry、Palette 根 frame、SavedVariables、SecureButton 或 Host 可变表。Lychee 缺席时只跳过集成；`## OptionalDeps: Lychee` 不替代运行时检查。

## 3. Plain data 与边界

进入 Host 的 payload、request、result、SearchRecord、动态 item、Panel state 和诊断值必须是 plain data：

- 允许 `nil`、boolean、有限 number、string 和无环 table；禁止 function、thread、userdata、Frame、纹理对象、metatable 和循环引用。
- 默认最大嵌套深度为 8，单表最多 128 个字段；具体 schema 可以更严格。
- 值先检查 `issecretvalue`，再检查 `canaccessvalue`，table 再检查 `canaccesstable`；失败立即停止。
- secret 或 inaccessible 值及其后代不得进入规范化、索引、缓存、排序、日志、SavedVariables 或错误文本。
- 失败只返回稳定 code、静态 field 标识和 `retryable`，不格式化被拒绝值或动态 key。

注册描述符可以在规定字段使用回调；回调不属于运行时结果数据，仍须由 Host 做错误隔离。

## 4. SearchSource 与 SearchRecord

`SearchSource` 是所有稳定实体的统一数据入口，适用于技能、任务、Boss、小怪、副本、成就、传送和第三方实体。固定功能入口使用 `Command`，可复用能力使用 `CapabilityProvider`。

```lua
extension:RegisterSearchSource({
    id = "creatures",
    version = 1,
    revision = 7,
    priority = 80,
    scope = { product = "retail", minInterface = 120000, maxInterface = 120999 },
    records = records, -- 或 snapshot = function(context) ... end
})
```

Source 约束：

- `id` 在 Extension 内唯一；Host 使用 `<extensionID>:<sourceID>` 作为全局 ID。
- 必须声明 `version`、`revision`、`priority`、`scope`，并提供 `records` 或 `snapshot`。
- 使用 `BeginSnapshot`/`Upsert`/`Remove`/`CommitSnapshot` 做批量更新；同帧散更新由 Host 合并。
- 每次提交推进 `revision` 和 `generation`；Source 禁用或注销只删除自己的索引成员。
- 查询只读取活动索引，不调用 Provider 扫描原始数据库。数据变化使用 `Invalidate(key)` 或 Source 更新通知。

SearchRecord 的核心字段：

| 字段 | 类型与语义 |
| --- | --- |
| `id` | 必填稳定全局 ID，如 `spell:393256`、`quest:12345` |
| `kind` | 必填实体类型，如 `spell`、`quest`、`creature` |
| `kindTitle` | 可选类型显示名，由 Source/Provider 提供的 string 或 locale table；Host 不维护 `kind` 到文案的字典 |
| `category` | 可选类别 ID 或带本地化标题的类别对象 |
| `title` | 可选主标题，string 或 locale table |
| `subtitle`/`description` | 可选副标题和描述 |
| `aliases` | 可选本地化别名数组 |
| `keywords` | 可选本地化关键词数组 |
| `icon` | 可选 fileID 或纹理路径 |
| `payload` | 可选 plain-data 业务数据 |
| `availability` | 可选声明式当前可用条件 |
| `interaction` | 可选 `primaryActionID`、`actions`、`drag` |
| `sourceID/sourceRevision/sourceGeneration` | Host 生成或复核的来源戳 |

`id` 不能使用随机数、显示名称、本地化文本或数组索引。自定义类别使用 `<extension-id>:<category>`；Host 保留 `spells`、`achievements`、`quests`、`dungeons`、`extensions`。

## 5. Locale、别名与版本范围

用户可见文本和别名可以是字符串或 locale table：

```lua
aliases = {
    "fallback-alias",
    { text = "翅膀", locale = "zhCN" },
    { text = "Avenging Wrath", locale = "enUS" },
}
```

`locale` 必须是 WoW locale token 或 `default`。Host 按“当前 locale -> `default`”选择显示和索引文本；其他 locale 保留在 Source 数据中但不进入当前活动索引。`kindTitle` 与其他用户可见文本遵循相同的 locale 选择规则。版本、赛季简称和玩家俗称放入 `aliases` 或 `keywords`，不创建重复实体。规范化后的同名实体仍作为不同 stable ID 候选交给排序器。

文本还可以声明 product/interface/build scope。当前客户端不匹配的投影不索引。加载期读取 locale 与运行时身份；按键查询不做翻译、网络请求或全量扫描。

## 6. 匹配、置信度、证据与排序

Host 为 canonical title、alias、keyword、description 和 category title 建立 exact、prefix、substring、n-gram 索引；在长度和预算允许时执行有限 fuzzy 匹配。每个结果带有：

```lua
{
    confidence = 0.98,
    matchedField = "alias",
    matchedText = "翅膀",
    matchType = "exact",
}
```

匹配优先级为 exact title/alias、prefix、keyword、description、fuzzy；实际分数由 Host 版本固定。相同实体多字段命中只显示一次。最终排序依次使用 confidence、Source priority、category order 和 stable ID，确保相同输入得到稳定顺序。结果超过 `query.limit` 时截断并记录 `RESULT_LIMIT` 诊断，不改变记录身份。

## 7. 通用动作与主操作

结果交互是 plain-data `interaction`，最多四个 action。每个 action 的 `id` 在 item 内稳定且唯一；`primaryActionID` 必须引用已有 action。未声明 interaction 时，Host 提供隐式 `{ id = "default", kind = "intent" }`。

### Tooltip 合同

结果行和默认网格只显示图标、类别和标题；描述性信息由 Host 统一放入 tooltip。tooltip 依次展示 canonical `title`、Source/Provider 提供的 `kindTitle`（缺省时显示稳定的 `kind` 标识）、`description`/`subtitle`、来源、可选匹配证据（字段、匹配类型、置信度）以及已声明动作。Host 不维护实体类型到本地化文案的映射。空字段省略。第三方只提供这些 plain-data 字段，不创建或接管 `GameTooltip`。不得显示 Enter、方向键、Esc 等教学文字、异常堆栈、secret/inaccessible 值或未声明动作。

```lua
interaction = {
    primaryActionID = "cast",
    actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 393256 },
        { id = "detail", title = "详情", kind = "open-panel", panel = "spell-detail", state = {} },
    },
    drag = { type = "spell", spellID = 393256 },
}
```

允许的 action kind：

| kind | 必填/行为 |
| --- | --- |
| `intent` | `intent = { type, version, payload? }`；由 IntentRouter 执行 |
| `open-panel` | `panel` 为同一 Extension 的 PanelFactory ID，`state` 可选 |
| `secure-spell` | 正整数 `spellID`；绑定 Host 的安全按钮 |
| `drag-spell` | 正整数 `spellID`；仅用于声明拖拽动作 |

Host 拒绝未知 kind、重复 ID、函数、Frame、宏文本、任意 secure 属性和鼠标脚本。动作不从文本、图标或 payload 猜测。

- 左键结果行和 Enter 只请求 `primaryActionID`。
- 普通 `intent` 绑定 Extension、item、action、session、generation 和 Context token，再进入 IntentRouter。
- `open-panel` 只接受同一 Extension 拥有且已启用的 PanelFactory，并校验 state schema。
- action 或 item 失效、Source revision/generation 变化、Extension 停用或 Palette 关闭时，Host 丢弃旧 token。

## 8. 安全施法与技能拖拽

安全动作只使用声明式 descriptor，不让第三方取得按钮或 protected attributes：

```lua
{ kind = "spell", spellID = 393256, unit = "target" }
```

Host 只在脱战时创建或准备 `SecureActionButtonTemplate`、注册点击和写入 attributes。真实鼠标左键点击由该按钮承接；Enter、普通 Lua 回调、IntentRouter 和 scripted `Button:Click()` 不得伪造施法，返回 `ACTION_REQUIRES_HARDWARE_CLICK`。战斗中不写 protected attributes；Palette 进入战斗时关闭并取消当前 session。

拖拽只接受：

```lua
drag = { type = "spell", spellID = 393256 }
```

Host 必须复核 Palette 可见、脱战、玩家已知且可用、item 仍属于当前 Extension/session/generation，随后由结果行专用真实 `OnDragStart` 调用 `C_Spell.PickupSpell`（必要时使用兼容 API）。点击、Enter、移动和非专用区域不能取起 spell。未知类型返回 `DRAG_UNSUPPORTED`；目标不可用返回 `ACTION_UNAVAILABLE`。

## 9. CapabilityProvider、Command 与 Intent

`CapabilityProvider` 提供可复用的 typed request/result，不进入搜索结果、不绘制 UI、不注册快捷键、不返回 Frame。实体直接搜索必须使用 SearchSource。只有需要按用户输入组合查询能力时，才额外注册 `ambient` `dynamic-list` Command。

Command 是固定可搜索入口：

- `row` 使用静态 `intent` 或 `intentFactory(context)`；
- `dynamic-list` 的 resolver 只读取 query、ContextSnapshot 和 Provider 的有界预索引；
- `ambient` 必须声明合法 `minLength`/`maxLength`，共享单一 debounce、generation 和全局调用预算；
- `custom-panel` 只返回 PanelFactory 引用，不直接创建或操作面板。

Intent 必须包含 `type`、`version` 和 schema 约束的 plain-data `payload`。第三方 type 以 `<extensionID>.` 开头，`lychee.*` 保留给 Host。Handler 返回 `{ ok = true, closePalette? }` 或稳定业务错误，也可以返回声明式：

```lua
transition = { type = "custom-panel", panelFactoryID = "details", state = plainData }
```

Handler 不直接调用 Palette、ViewHost 或 SecureButton；Host 在当前 session、generation、Context 和 Extension 状态仍有效时才执行。

## 10. PanelFactory 与 ViewHost

PanelFactory 是复杂交互的受控工厂，最小形状为：

```lua
{
    id = "details",
    stateSchema = { itemID = "integer" },
    create = function(context, state) return instance end,
    Mount = function(instance, context, state) end,
    Update = function(instance, state, context) end,
    Unmount = function(instance, reason) end,
    Dispose = function(instance, reason) end,
}
```

ViewHost 生命周期为 `create -> Mount -> Update* -> Unmount -> Dispose`。切换面板、关闭 Palette、战斗、注销或回调错误都会终止当前 generation；失败映射为 `PANEL_ERROR`，不得留下半挂载实例。Panel 只能使用 Host 提供的 `contentFrame` 和窄 `PanelContext`，不能接管 Palette 根 frame、全局焦点、快捷键、SavedVariables 或安全按钮。隐藏面板必须停止事件、ticker、timer 和输入脚本，实例应可复用。

## 11. Session、generation、revision 与失效

- `session` 标识一次 Palette 打开周期；关闭后所有结果和动作 token 失效。
- 每次有效输入和 Context 变化创建新的 `query generation`；迟到 resolver 结果直接丢弃。
- `SearchSource revision/generation` 标识该 Source 的数据快照；结果提交时必须与当前 Source 一致。
- Context slice version 变化使声明依赖该 slice 的动态结果重新计算。
- Source/Extension 禁用、注销、进入战斗、Palette 隐藏时，取消 debounce、deferred resolver、Panel 任务和 secure binding。
- 失效清理必须局部执行：只移除对应 Source、行、任务和 token，不重建整棵 UI。

可接纳结果至少需要当前 `session`、`generation`、`contextToken`、Source state、availability 和 Extension enabled 全部匹配。

## 12. 稳定错误码

公开错误使用 `{ code, field?, extensionID?, retryable }`，不携带异常堆栈或被拒绝值。稳定 code 包括：

`INVALID_SCHEMA`、`SDK_UNAVAILABLE`、`SECRET_VALUE`、`INACCESSIBLE_VALUE`、`DUPLICATE_ID`、`UNSUPPORTED_API`、`INCOMPATIBLE_HOST`、`REGISTRATION_CLOSED`、`INVALID_STATE`、`HOST_UNAVAILABLE`、`EXTENSION_DISABLED`、`COMMAND_NOT_FOUND`、`CAPABILITY_NOT_FOUND`、`PROVIDER_UNAVAILABLE`、`CALL_DEPTH_EXCEEDED`、`PROVIDER_TIMEOUT`、`PROVIDER_ERROR`、`INVALID_RESULT`、`RESULT_LIMIT`、`STALE_GENERATION`、`INTENT_INVALID`、`COMBAT_LOCKED`、`INVALID_SECURE_DESCRIPTOR`、`INVALID_INTERACTION`、`DRAG_UNSUPPORTED`、`ACTION_UNAVAILABLE`、`ACTION_REQUIRES_HARDWARE_CLICK`、`PANEL_ERROR`、`CALLBACK_ERROR`。

同一 major 内 code 的含义不变。`retryable` 描述重新发起是否可能成功，不表示 Host 无限重试。

## 13. 性能合同

- Palette 隐藏且无活动任务时，不保留 Lua 每帧回调、resolver、timer 或 ticker。
- 查询使用预构建索引、有界结果（默认最多 20 项）和单一 debounce；不枚举 AddOn 或扫描全量原始表。
- Source 更新采用事件/显式 invalidation 和同帧合并；不轮询“确保最新”。
- 结果行、Panel frame 和动作对象池化复用；setter 只在 canonical 状态改变时调用。
- availability 快速且无副作用；回调和 Provider 使用局部 `xpcall`，错误不会污染其他 Extension。
- 不在战斗中迁移 SavedVariables、写 protected attributes 或执行延迟 secure 动作。
- Host 记录调用次数、耗时、错误和过期 generation；连续超预算可将 Extension 标记 slow 或停用。

第三方接入前应在空闲、单目标战斗、多目标/团本、姓名板峰值和面板开关场景记录 CPU、帧时间、Lua 内存、对象和池峰值，并确认停用/注销后后台工作归零。

## 14. 接入与协议变更清单

第三方接入检查：

1. TOC 使用 `OptionalDeps: Lychee`，运行时检查 `_G.Lychee` 和 `Supports`。
2. 只创建一个 Extension draft，先注册声明，再一次 `Commit()`；失败处理稳定 error code。
3. 所有实体使用稳定 SearchRecord ID；文本、别名、关键词声明 locale 和 scope。
4. Provider、Command、IntentHandler、PanelFactory 各自遵守职责边界；不返回 Frame、不操作 Host 私有对象。
5. Action ID、primaryActionID、spellID、PanelFactory ID 和 state schema 通过本协议校验。
6. 处理 disabled、retiring、combat、stale generation、secret/inaccessible 和 Host 缺席路径。
7. 用静态检查、smoke 测试和性能采样验证，再提交与发布。

协议变更流程：先更新本文和必要的 SDK 示例，再更新实现与契约测试；运行 `git diff --check`、Lua/XML/TOC 静态检查和相关 smoke；破坏性变更提升 major，兼容增量提升 revision，并在变更说明中记录迁移与回滚方式。
