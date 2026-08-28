# LycheeSDK 集成协议

## 本 change 的交付形式

本规格通过 `docs/SDK.md` 交付第三方接入设计，不创建独立 SDK AddOn 文件。文档必须给出可直接照写的 TOC、注册 API、返回值、下拉结果交互、生命周期、版本兼容、性能要求和完整示例。

## 目标

Lychee 只发布一个 Host AddOn；SDK 是 Lychee 暴露的公共 API，公共 facade 为 `_G.Lychee`。它提供进程内 Lua API 和生命周期句柄，不模拟桌面应用的 IPC，不使用聊天频道传输注册信息。

接入动作必须由第三方主动发起：第三方在自己的 AddOn 集成代码中通过 `_G.Lychee` 注册 Extension，以及按需注册 SearchSource、Command、Provider、Handler 和可选 Panel，再调用 `Commit()`。Lychee 不扫描目录来自动生成接入。稳定实体通过同一 Extension 的 SearchSource 发布；Provider 本身不会产生搜索结果，只有需要按输入即时组合能力时才由 `ambient` `dynamic-list` Command 调用。

## AddOn 加载契约

第三方插件的 TOC 至少声明：

```toc
## OptionalDeps: Lychee
```

可选的诊断元数据：

```toc
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Commands: 2
## X-Lychee-Keywords: sample,search
```

`OptionalDeps` 用于请求优先加载 Lychee，但不能单独证明 Lychee 已存在、已加载或注册成功，也不要求用户必须安装 Lychee。插件主 chunk 必须检查 `_G.Lychee` 并兼容两种结果：

1. `_G.Lychee` 已加载且 ready：立即注册 Extension。
2. `_G.Lychee` 未安装或未能加载：记录一次诊断信息并等待 `ADDON_LOADED`；已存在但尚未 ready 时仍可创建 draft/Commit 进入 pending，`RegisterReady` 只用于 ready 通知，插件自身功能继续工作。

Lychee PublicAPI 只建立稳定 facade 和轻量 registry，不把 Palette、全局快捷键、Host SavedVariables 或 SecureButton 暴露给第三方。

## 运行时发现顺序

```text
Lychee 本体加载
  -> 创建 _G.Lychee 公共 facade 和 ExtensionRegistry
第三方 TOC OptionalDeps
  -> 第三方创建 Extension draft 并注册子声明
  -> 第三方调用 Commit() 原子发布
  -> Lychee PublicAPI 校验并写入 registry/pending
  -> Lychee ready 时消费 pending registry
  -> Extension 进入 registered/enabled
```

Lychee Host 的唯一事实源是 ExtensionRegistry，而不是每次输入时重新扫描 AddOn 列表。Lychee 可以在登录或诊断页缓存以下官方信息用于展示：

- `C_AddOns.GetNumAddOns`：AddOn 数量；
- `C_AddOns.GetAddOnInfo`：名称、标题、可加载状态、失败原因和安全级别；
- `C_AddOns.GetAddOnMetadata`：`X-Lychee-*` 等 TOC 元数据；
- `C_AddOns.GetAddOnDependencies`：依赖关系；
- `C_AddOns.IsAddOnLoaded`：返回 `(loadedOrLoading, loaded)`；诊断页只有第二返回值为 true 才显示 `loaded`，仅第一返回值为 true 时显示 `loading`；
- `C_AddOns.LoadAddOn`：用户明确命中或打开诊断页时按需加载 LoD AddOn。

枚举结果不能直接当作已接入：只有成功 `Commit()` 的 Extension 句柄才算接入。`LoadAddOn` 返回成功但没有 committed registry 注册时，诊断状态为 `loaded-without-registration`。LoD AddOn 只有声明 `X-Lychee-Keywords` 才能在加载前进入搜索候选。

## API 版本与注册

SDK 暴露只读 API 版本和注册入口，推荐形态如下（名称可在 Build 阶段按最终 Lua 命名规范落地）：

```lua
local sdk = _G.Lychee
if not sdk or sdk.API_VERSION < 1 then return end

local extension, err = sdk:RegisterExtension({
    id = "sample-extension",
    apiVersion = 1,
    title = "Sample",
    version = "1.0.0",
    capabilities = { "sample.data" },
})
if not extension then
    -- 只记录诊断；第三方自身功能继续运行
    return
end

extension:RegisterCommand({
    id = "sample.search",
    title = "Search sample data",
    keywords = { "sample", "search" },
    presentation = "dynamic-list",
    match = { type = "ambient", minLength = 2, maxLength = 64 },
    resolve = function(query, context) end,
    itemIntent = function(item, actionID, context) end,
})

local committed, commitErr = extension:Commit()
```

`RegisterExtension` 返回 draft；各 `Register*` 只写入 draft，`Commit()` 一次性校验交叉引用、版本、schema 和声明数量。注册校验必须拒绝并报告：空 ID、非法字符、重复 Extension/Command/Capability ID、未支持的 API 版本、presentation 与 resolver/factory 不匹配、缺少稳定标题或超出声明数量上限。失败不发布部分对象，重复注册不能静默覆盖已启用的 Extension。

`Commit()` 成功后返回同一个稳定 Extension 句柄；第三方用该句柄读取只读状态、设置 owner-enabled 位和调用幂等 `Unregister()`。第三方不得直接修改 Lychee ExtensionRegistry，也不需要因 Lychee 尚未 ready 而自行轮询或重复注册。

## pending registry 与 Lychee ready

Lychee ExtensionRegistry 在 facade 尚未 ready 时保留 `pending` 集合，ready 后转为 `registered`：

- 第三方先加载、Lychee 后 ready：committed 句柄进入 `pending`；ready 时按 Extension ID 稳定排序、逐项校验并转为 `registered`。
- Lychee 已 ready、第三方后加载：Commit 后立即注册；失败返回稳定错误，不要求第三方轮询。
- 同一 Extension 重载：旧句柄先进入 `retiring`，其索引和驱动清理完成后才接受新句柄。
- Lychee facade detach 或关闭：调用每个句柄的 `onHostDetached`，停止查询、Panel、ticker、timer 和事件引用，但不删除第三方自己的数据。

SDK 不把可变 registry、Host frame、SavedVariables 根表或 SecureButton 返回给第三方；句柄只暴露窄接口和只读状态。

## Command、Provider 与两种交互

### 统一动态列表

Command 默认使用 `match = { type = "catalog" }`，只按标题、别名和关键词进入静态候选。需要让用户直接输入怪物、物品等实体名称时，`dynamic-list` Command 可以显式声明：

```lua
match = {
    type = "ambient",
    minLength = 2,
    maxLength = 64,
    priority = 0,
}
```

`ambient` 只允许 `dynamic-list` 使用。Host 还会检查 Extension/Command 用户启用状态、availability、全局主动 resolver 数量预算和稳定优先级；声明不表示每次按键都必定调用。`row` 或 `custom-panel` 使用 ambient、缺少长度边界、`minLength < 1` 或 `maxLength < minLength` 时，整个注册事务失败。

用户可见 title 支持 string 或带 `default` 的 locale table。Command 的 aliases/keywords 和 Provider 实体别名支持 string 简写，或 `{ text = string, locale = "zhCN" | "enUS" | ... | "default" }`。Host 在加载期读取一次 `GetLocale()`，只索引当前 locale 与 `default`；别名必须通过同一 plain-data/secret/inaccessible 校验。Provider 在注册或数据更新时把别名映射到 canonical stable item ID，例如“翅膀”映射到“复仇之怒”、“红玉”映射到对应已知传送法术；命中别名不复制实体、结果或动作协议，按键热路径不做临时翻译或全表扫描。

第三方 `dynamic-list` resolver 接收规范化 query 和只读 `ContextSnapshot`，返回结构化 item 数组。Context、payload 和返回值必须先经过递归边界检查：`issecretvalue(value)` 为 true、`canaccessvalue(value)` 为 false，或 table 的 `canaccesstable(value)` 为 false 时，SDK 拒绝该值并返回稳定错误码；这些值不得进入索引、Intent、日志或 SavedVariables。

```lua
{
    id = "item-1", text = "...", subtext = "...", icon = "...", enabled = true, payload = opaque,
    interaction = {
        primaryActionID = "open-detail",
        actions = {
            { id = "open-detail", title = "查看详情", kind = "intent" },
        },
        -- 仅适用于玩家已知、非被动 spell；没有则不显示拖拽区域。
        drag = { type = "spell", spellID = 12345 },
    },
}
```

Lychee 的 SearchSession 负责单一输入 debounce、session/query generation、取消和过期结果丢弃；Palette 只负责行池、键盘上下、鼠标点击、滚动和选中态。ResultActionExecutor 统一校验并委托 Intent、同 Extension Panel、spell drag 和 secure-spell。第三方只处理 payload 对应的 Intent，不创建 Palette 行 frame。稳定实体索引由所属模块在数据加载或事件刷新时构建为 SearchRecord，并通过 SearchSource 提交；只有动态组合 resolver 才通过 CapabilityBroker 查询 Provider。Provider 不会自动成为搜索入口，也不向 Palette 推送 frame。

`interaction.actions` 最多四项，action ID 必须稳定、唯一且只含有限 plain-data。用户左键/Enter 触发 `primaryActionID`，行内其他 action 由 Host 绘制的明确按钮触发；Command 通过 `itemIntent(item, actionID, context)` 将普通 action 转为 Intent。第三方不能在 item 中放函数、Frame、宏文本、任意 secure 属性或鼠标脚本，也不能让 Host 从文字或图标推断动作。

只有 Host 解释 `drag = { type = "spell", spellID = number }`：在行仍属于当前 Extension/session/generation、Palette 可见且脱战时，用户必须从 Host 的专用拖拽区域真实发起 `OnDragStart`；Host 验证该 spell 为当前玩家可用且非被动后调用 `C_Spell.PickupSpell`。`itemIntent`、resolver、Enter 和普通点击永远不取起 spell。未知 drag type、无效 spell、战斗、旧 generation 和 disabled/retiring Extension 都被拒绝，不改变鼠标光标。

可施放 spell 只能由 `kind = "secure-spell"` 的 Host-owned 安全行/按钮承载。它使用已验证的声明式 spell ID，在脱战绑定，并只接受真实鼠标左键点击；Enter、普通 Handler、`dispatchIntent` 与 scripted `Button:Click()` 不得模拟施放。第三方不能拿到安全 button 或配置其属性。

因此第三方按职责使用三类显式声明：`RegisterSearchSource(...)` 发布稳定可搜索实体，`RegisterCommand(...)` 发布固定入口或真实动态组合查询，`RegisterCapabilityProvider(...)` 让能力可被其他模块或 ambient resolver 复用。只声明实际需要的角色；它们在所属 Extension `Commit()` 成功后原子可见，注销 Extension 时作为一个所有权单元退出。

### 动态项进入详情 Panel

点选动态项必须先经过 `itemIntent` 和 IntentRouter。Handler 成功后可以请求 Host 进入本 Extension 已注册的详情 Panel：

```lua
return {
    ok = true,
    closePalette = false,
    transition = {
        type = "custom-panel",
        panelFactoryID = "creature-detail",
        state = { creatureID = intent.payload.creatureID },
    },
}
```

Host 只接受同一 Extension 的 PanelFactory ID。`transition.state` 必须通过 plain-data、secret/inaccessible、深度、字段数和 Panel 声明 schema 校验；校验失败时 Intent 返回稳定错误，不 Mount Panel。Handler 只返回描述符，不直接调用 ViewHost、PanelFactory 或 Palette frame。

大秘境怪物接入的稳定实体链路为：SearchSource 发布怪物 SearchRecord，记录 action 生成打开详情 Intent，IntentHandler 返回上述 transition，PanelFactory 负责详情内容。需要向其他模块复用同一份怪物数据时可额外注册 creature CapabilityProvider；只有依据本次输入或 Context 即时组合结果时才额外使用 ambient `dynamic-list` Command。

### 法术结果、拖拽和真实点击

当前内置玩家法术 Source 只发布角色已知且可用的 spell。以下 SearchRecord 同时提供拖到动作条和真实点击施放，不经过 Command、CapabilityProvider 或 itemIntent：

```lua
{
    id = "spell:12345",
    kind = "spell",
    category = { id = "spells", title = "技能" },
    title = "红玉新生法池传送门",
    icon = 123456,
    payload = { spellID = 12345 },
    actions = {
        { id = "cast", title = "施放", kind = "secure-spell", spellID = 12345 },
    },
    drag = { type = "spell", spellID = 12345 },
}
```

Host 为 `cast` 绑定安全按钮并等待用户真实点击；Enter 返回 `ACTION_REQUIRES_HARDWARE_CLICK`，不会模拟施放。未来只有在真实详情 UI 存在时才增加 PanelFactory 和详情 action，不注册空 Panel。

### 受控 custom-panel

第三方可声明 `presentation = "custom-panel"` 并提供 `panelFactory`。Lychee 创建自己的 ViewHost 后传入：

```lua
{
    contentFrame = hostOwnedFrame,
    width = readonlyWidth,
    height = readonlyHeight,
    close = function() end,
    invalidate = function() end,
}
```

第三方只能把子 frame 放入 `contentFrame`，不能取得 Palette 根 frame、改动 Host 尺寸/层级、注册全局按键或把焦点移出 Host。Panel 必须支持 `Mount`、可选 `Update`、`Unmount`。Host 隐藏、Esc、进入战斗、超时、Extension 禁用和异常退出都走同一清理路径。关闭后恢复原 EditBox 只作 best-effort：对象和焦点方法仍可访问时才尝试，否则只清除 Lychee 输入焦点。

Panel 实例由 Host 复用，生命周期为 `create once -> (Mount -> Update* -> Unmount)* -> Dispose`。Host 托管的可取消任务必须使用并保存 `C_Timer.NewTimer`/`NewTicker` 返回句柄，统一清理时调用 `Cancel()`；`C_Timer.After` 不返回可取消句柄，只能配合 generation/active guard 丢弃迟到回调。第三方直接创建的事件、timer 和 ticker 由其 `Unmount`/`Dispose` 清理。ViewHost 是所有权边界，不是强安全沙箱。

## 受保护 Intent

第三方只提交声明式 Secure Descriptor。Host 使用 `CreateFrame("Button", ..., ..., "SecureActionButtonTemplate")` 创建自己的安全按钮，并只在脱战时配置 descriptor 对应属性。Lychee 采用更严格的产品策略：战斗中 Palette 不可用，所有 Lychee Intent 返回 `COMBAT_LOCKED`，不保留战斗内真实点击入口；普通回调、Enter、`dispatchIntent` 和 scripted `Button:Click()` 永远不模拟硬件输入。

下拉 result 的 `secure-spell` 是上述约束的专用、有限实例：只能是 Host 验证的 spell ID，不向 SDK 暴露 SecureButton，且无法被普通 Intent 触发。Host 必须在输入 generation/Extension 状态改变、Palette 关闭、进入战斗、disable 或 unregister 时立即取消/失效旧绑定；进入战斗不修改 secure 属性，只标记脱战 dirty cleanup。

## Host 快捷键边界

Lychee Host 只注册 `TOGGLELYCHEE`：`Bindings.xml` 必须声明 `<Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">`，调用稳定全局 Toggle 函数，并提供 `BINDING_HEADER_LYCHEE` 和 `BINDING_NAME_TOGGLELYCHEE` 本地化文案。默认键是 `Alt + Space`（`ALT-SPACE`），但只在首次初始化、脱战、`TOGGLELYCHEE` 尚无 binding 且 `ALT-SPACE` 未被其他 action 占用时，通过 `SetBinding("ALT-SPACE", "TOGGLELYCHEE")` 和 `SaveBindings(GetCurrentBindingSet())` 写入。任何冲突、已有 binding 或玩家后续修改都保留原状；Lychee 用一次性 `defaultBindingAttempted` 标记避免再次尝试，且绝不使用 `SetOverrideBinding` 或每次登录重写 binding。第三方 Extension 不注册 Lychee 快捷键，也不调用这些 Binding API。Toggle 入口在 `InCombatLockdown()` 为 true 时静默返回，不打开、不关闭、不移动焦点、不启动查询；`PLAYER_REGEN_DISABLED` 会关闭已打开的 Palette 并触发 `Unmount`/任务清理，脱战后原 Binding 自动恢复可用。

## 生命周期、错误与隔离

Extension 状态：`draft -> pending -> registered -> enabled -> slow/disabled -> retiring -> removed`。每个 resolver、Intent、Panel callback 都包在局部错误边界内；错误只禁用对应 Extension 的任务和索引，不得让 Palette 卡死或无法关闭。

- resolver 超时或连续错误：丢弃本次结果，保留 dirty，按退避窗口重试并标记 `slow`；
- Intent 错误：停止当前动作，显示统一错误行，释放 busy 状态；
- Panel 错误：调用 `Unmount`、隐藏 content frame、注销该 Extension 驱动；
- 注销：先标记 `retiring`，等待当前 generation 完成或失效后再移除索引；
- SDK 缺失：第三方不创建 Lychee 相关对象；
- PublicAPI 不支持声明的 API major/minimum revision：`Commit()` 原子失败并返回 `UNSUPPORTED_API`；PublicAPI 支持但 Host revision 不足：`Commit()` 成功并进入 `pending/incompatible`，诊断码为 `INCOMPATIBLE_HOST`，不执行第三方回调。

## 通信边界

`C_ChatInfo.RegisterAddonMessagePrefix` 和 `C_ChatInfo.SendAddonMessage` 面向客户端间 AddOn 消息，需要频道/目标和文本 payload，受通信节流约束。它们不参与 Lychee PublicAPI 注册、命令查询或本机 Intent 调用。Lychee 与第三方的本机通信只经过 Lua PublicAPI 句柄、结构化参数和 Host 回调。

## 结果交互错误码

| Code | 含义 |
| --- | --- |
| `INVALID_INTERACTION` | item interaction、action ID、primary action 或动作组合不符合 schema |
| `DRAG_UNSUPPORTED` | Host 不支持或不允许声明的 drag type |
| `ACTION_UNAVAILABLE` | action 的目标、指南 adapter 或 spell 当前不可用 |
| `ACTION_REQUIRES_HARDWARE_CLICK` | 请求以 Enter/脚本路径触发 secure action，必须真实鼠标点击 |

CapabilityBroker 另稳定区分：`CAPABILITY_NOT_FOUND`（type 未注册）、`PROVIDER_UNAVAILABLE`（Provider 均因生命周期不可调用）、`INVALID_SCHEMA`（请求非法）、`INVALID_RESULT`（结果非法）、`PROVIDER_ERROR`（回调异常）和 `RESULT_LIMIT`（结果超限）。Provider disable、retiring、removed 或 unregister 后不会被调用。

错误对象仍遵守 Host 的公开错误格式，并且不得包含 payload、spell 名称、Frame 或第三方回调内容。

## 性能约束

- 注册和 AddOn 元数据扫描只发生在加载/登录/诊断入口，不发生在每次按键。
- registry、Command Catalog 和 alias 索引使用稳定数组 + ID 索引；重复注册/注销不触发全量 UI 重建。
- ambient dynamic-list 只在用户启用、长度/availability 命中并位于 Host 全局调用预算内时执行；短输入不调度。
- dynamic-list 结果带 generation，旧结果不进入渲染；每 Command 结果数受限，列表行使用池化 frame。
- interaction action 槽按 stable item ID/action ID 复用，最多四个；拖拽和安全绑定只在结果 diff 与可见会话期间处理，不在 resolver、鼠标移动或常驻 `OnUpdate` 中工作。
- Provider/模块在注册或数据变化时维护实体索引，resolver 不在每次输入时全表扫描。
- custom-panel 隐藏时必须清理 ticker、timer、事件和 frame 引用；Palette 隐藏时无常驻 Lua `OnUpdate`。
- Lychee PublicAPI 主 chunk 只做常量和 registry 初始化，不在加载期深扫描第三方代码。

## 验证夹具

必须覆盖：

1. 第三方先加载、Lychee 尚未 ready 时，committed pending registry 被 ready 流程完整消费；
2. Lychee 先 ready、第三方后 Commit，Extension 立即注册；
3. 未 Commit draft 不可见，重复 ID 和声明数量超限时原子失败；
4. PublicAPI 不支持声明的 API major/minimum revision 时，`Commit()` 原子失败并返回 `UNSUPPORTED_API`；
5. PublicAPI 支持声明、但当前 Host revision 不足时，`Commit()` 成功并进入 `pending/incompatible`，诊断码为 `INCOMPATIBLE_HOST`，不执行第三方回调；
6. LoD 插件由关键词候选显式加载，加载但未 Commit 时显示诊断状态；
7. dynamic-list 旧 generation 不覆盖新输入；
8. custom-panel 的实例复用、Mount/Update/Unmount/Dispose、Esc 和托管资源清理；
9. 一个第三方回调报错时，其他 Extension 和 Palette 仍可用；
10. 代码路径没有使用 `SendAddonMessage` 作为本机 SDK RPC；
11. `SecureActionButtonTemplate` 创建、脱战 descriptor 配置，以及所有战斗中 Lychee Intent、scripted click/Enter 的 `COMBAT_LOCKED` 行为；
12. 战斗中 `TOGGLELYCHEE` 静默失效且不启动查询，进战关闭已打开 Palette，脱战后同一 Binding 恢复；
13. secret/inaccessible Context、payload 和返回值被递归拒绝，且不进入索引、Intent、日志或 SavedVariables；
14. `IsAddOnLoaded` 的 loading/loaded 双状态、Panel 可取消 timer/ticker 与 `After` generation guard；
15. 直接输入稳定实体名时由 SearchSource 返回结果；运行时组合项可由 ambient Command 返回且不需要先输入命令标题，短于 `minLength` 时不调用 resolver；
16. 多个 ambient Command 按启用状态和稳定预算调度，快速连续输入的旧结果不覆盖新结果；
17. Provider 不可用、索引未就绪或 resolver 超预算时只影响所属结果组；
18. item Intent 的合法 transition 挂载同 Extension Panel，跨 Extension、非法 state 或过期 session 转换被拒绝；
19. Palette 关闭、进入战斗、Extension disable/unregister 后 ambient 查询与待处理 transition 均无效果；
20. 单一普通 primary action 可由左键/Enter 触发；多 action 行只调用声明的 primary，次级 action 由 Host 可见按钮触发；action ID 不靠文本推断；
21. spell item 仅从专用区域真实 `OnDragStart` 调用 `C_Spell.PickupSpell` 并可被标准动作条接收；普通点击、Enter、resolver 与 itemIntent 不触发 PickupSpell；
22. secure-spell 行/按钮只在脱战绑定，真实鼠标点击才可施放；Enter、IntentRouter 和 scripted `Button:Click()` 返回拒绝且不能模拟点击；
23. MRT/指南适配器缺席、旧 generation、关闭、进战、disable 和 unregister 分别不会留下普通动作、拖拽或 secure 绑定；
24. 怪物/怪物技能、玩家技能、Boss/赛季别名和已知副本传送技能四类内置搜索场景都通过同一 interaction 合同工作；副本传送与玩家技能共用 `PlayerSpells` Extension。
25. 首次脱战初始化仅在 `TOGGLELYCHEE` 无绑定且 `ALT-SPACE` 空闲时写入默认 binding；已有 action、按键冲突、战斗中初始化、已设置 `defaultBindingAttempted` 以及玩家之后改键或解绑时，都不覆盖或回写。
