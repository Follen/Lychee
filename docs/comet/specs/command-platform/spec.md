# Lychee Command Platform

> 历史规格：保留已归档 change 的设计快照，包含当前已移除或调整的接口，不作为 SDK 1.0.0 或当前运行代码的实现要求。现行入口见 [架构](../../../ARCHITECTURE.md)、[设计规范](../../../../DESIGN.md) 和 [SDK](../../../../lychee-sdk/README.md)。

## 本 change 的交付形式

本规格通过 `docs/ARCHITECTURE.md` 交付系统设计，不创建 Lua/XML/TOC 运行时代码。文档必须完整定义下述模型、依赖方向、生命周期、性能门槛、后续实现顺序和验证矩阵；示例 API 属于后续实现 change 的约束。它还定义下拉结果的动作与拖拽合同，后续运行时必须遵守 WoW 硬件事件和战斗保护限制。

## 目标

Lychee 提供一个单入口命令平台。用户输入统一匹配固定 Command 与 SearchSource 发布的 SearchRecord；真实动态组合查询由 ambient Command 调用一个或多个 CapabilityProvider。结果动作通过 IntentHandler 或 Host 声明式动作执行器完成。

## 核心模型

```text
Extension
├─ Command              发布固定入口或真实动态组合查询
├─ SearchSource         发布稳定实体 SearchRecord
├─ CapabilityProvider  提供可复用数据/能力
├─ IntentHandler       执行白名单 Intent
└─ PanelFactory        创建受 ViewHost 管理的复杂面板
```

### Extension

Extension 是内部模块或第三方插件的稳定身份，至少包含稳定 ID、API 版本、显示名称、能力声明和生命周期状态。第三方通过 Lychee Host 暴露的公共 API `_G.Lychee` 创建 draft，注册全部子声明后调用 `Commit()` 原子发布；Lychee facade 尚未 ready 时 committed registration 进入 pending registry，ready 后由 Lychee Host 一次性消费。

第三方数据不会因 AddOn 已加载或 Provider 已注册而自动进入搜索。第三方若要让稳定实体名称参与 Lychee 主输入框搜索，必须在同一 Extension draft 中注册 SearchSource；只有需要在查询时组合参数或动态调用能力时，才注册引用 CapabilityProvider 的 `ambient` `dynamic-list` Command。所有声明通过 `Commit()` 原子发布。Lychee PublicAPI 返回的 Extension 句柄是状态查询、owner 启停和幂等 `Unregister()` 的唯一控制入口；Lychee 不通过扫描 AddOn 目录推断或补造搜索接入。

### Command

Command 是固定命令和真实动态组合查询的可搜索入口，至少包含 stable ID、标题、别名/关键词、match、presentation、参数描述和 Intent factory。Command 不直接暴露任意回调给 UI。稳定实体由 SearchSource 进入全局搜索；Provider 中的数据不会自动进入全局搜索，只有需要运行时组合查询时才由 ambient Command 主动调用 Provider。`dynamic-list` 的 item 可额外声明由 Host 处理的 `interaction`，但 interaction 不改变 SearchSource、Provider 与 Command 的分层。

Command 的匹配模式：

- `catalog`：默认模式。只通过标题、别名、关键词、拼音和显式命令语法进入静态候选。
- `ambient`：主动内容匹配。只允许 `dynamic-list` 使用；当规范化输入满足 `minLength`、`maxLength`、availability、用户启用状态和 Host 预筛选时，QueryOrchestrator 才调用 resolver。注册时必须显式提供长度边界，非法组合原子失败。

用户可见 title 支持 string 或带 `default` 的 locale table。Command 的 aliases/keywords 和 Provider 实体别名支持 string 简写，或 `{ text = string, locale = "zhCN" | "enUS" | ... | "default" }`；Host 只把当前 `GetLocale()` 与 `default` 的值送入统一规范化、拼音和倒排索引。Provider 在注册或数据更新时把“翅膀”“红玉”等别名映射到 canonical stable item ID，命中后不复制实体或动作协议；按键热路径不得临时翻译或全表扫描。

支持的 presentation：

- `row`：Host 统一绘制单行结果，选择后立即路由 Intent。
- `dynamic-list`：Command 命中后请求结构化 items，由 Host 统一绘制、导航、交互和选择。
- `custom-panel`：Command 命中后进入 Lychee 管理的 ViewHost。第三方拿到受限 `PanelContext`，只在 Host 提供的 content frame 中创建和更新自己的子 frame；Lychee 仍拥有输入焦点、Esc/关闭、尺寸、层级、超时和清理。

`custom-panel` 不是把 Palette frame 交给第三方。第三方不能替换根 frame、注册全局快捷键或修改 Host 的 secure 属性。Panel 实例由 Host 复用，必须实现 `Mount(context)`、可选的 `Update(state)`、`Unmount()` 和可选 `Dispose()`；隐藏 Palette 时 Host 调用 `Unmount`。Host 托管 timer/ticker 使用可取消的 `C_Timer.NewTimer`/`NewTicker` 句柄；`C_Timer.After` 没有可取消句柄，只能使用 generation/active guard 丢弃迟到回调。第三方自己创建的事件、ticker 和 timer 由其清理。

### CapabilityProvider

CapabilityProvider 按稳定 capability type 注册输入/输出契约。它不进入搜索结果、不持有 Palette frame、不注册 Lychee 快捷键，也不决定结果行布局。一个 Provider 可服务多个 Command，同一 capability type 可有多个实现并由 Host/用户选择默认实现。

CapabilityBroker 按 priority、Extension ID、Provider ID 确定性选择并在调用前检查 Extension 生命周期。错误稳定区分 `CAPABILITY_NOT_FOUND`、`PROVIDER_UNAVAILABLE`、`INVALID_SCHEMA`、`INVALID_RESULT`、`PROVIDER_ERROR` 和 `RESULT_LIMIT`；本版本不增加跨查询缓存或复杂 fallback。

### IntentHandler

IntentHandler 只处理已注册的 Intent type。普通动作经错误边界执行；受保护动作使用声明式 Secure Descriptor，以及通过 `CreateFrame(..., "SecureActionButtonTemplate")` 创建并在脱战时配置的 Host 安全按钮。Lychee 采用严格的战斗策略：战斗中 Palette 不可用，所有 Lychee Intent 返回 `COMBAT_LOCKED`，不暴露战斗内真实点击入口；Enter、`dispatchIntent` 和 scripted `Button:Click()` 永远不能模拟硬件点击。UI 不按名称直接调用 Provider 函数。

## 快捷键与战斗状态

Lychee 只注册 `TOGGLELYCHEE`。实现必须提供 `Bindings.xml` 中的 `<Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">`、稳定全局 Toggle 函数，以及 `BINDING_HEADER_LYCHEE`/`BINDING_NAME_TOGGLELYCHEE` 本地化全局文案。默认唤起键为 `Alt + Space`（`ALT-SPACE`）：首次初始化时，仅当 `GetBindingKey("TOGGLELYCHEE")` 没有任何结果且 `GetBindingAction("ALT-SPACE")` 为空时，才在脱战调用 `SetBinding("ALT-SPACE", "TOGGLELYCHEE")` 和 `SaveBindings(GetCurrentBindingSet())`。若 action 已有绑定或按键已被其他 action 占用，Lychee 不覆盖也不另选默认键；设置页提示玩家自行设置。用 SavedVariables 的一次性 `defaultBindingAttempted` 标记避免重复尝试；玩家之后在 WoW 按键设置中修改或解绑后，Lychee 永不自动回写。不得使用 `SetOverrideBinding`，不得在战斗中或每次登录写 Binding。Toggle 入口第一步检查 `InCombatLockdown()`：战斗中静默返回，不打开、不关闭、不移动焦点、不启动查询。收到 `PLAYER_REGEN_DISABLED` 时，已打开的 Palette 立即走与 Esc 相同的关闭、`Unmount` 和任务清理路径；`PLAYER_REGEN_ENABLED` 后快捷键无需重新绑定即可恢复。关闭时恢复原 EditBox 只作 best-effort：对象和相关方法仍可访问时才尝试，否则只清除 Lychee 输入焦点。

## 查询链路

```text
输入变化
  -> SearchSession 推进 session/generation 并执行单一 debounce
  -> normalize/tokenize/intent parse
  -> 静态 Command Catalog 候选
  -> 计算满足规则的 ambient dynamic Command
  -> context/availability filter
  -> stable rank
  -> 发布普通结果
  -> 只调用已命中的 catalog/ambient dynamic-list resolver
  -> SearchSession 校验当前 session/generation 并接纳结果
  -> diff render
```

CommandCatalog 独占固定 Command 的私有索引和 ambient schedulable view；固定 Command 不再投影进 SearchSource/SearchIndex。QueryOrchestrator 只调用 Catalog 的查询与调度视图接口，不读取内部表。Palette 不直接推进 generation，输入替换、关闭、进战和 Extension 失效统一由 SearchSession 取消或用 token guard 丢弃迟到结果。

输入合并使用唯一 debounce；新 generation 使旧动态结果失效。ambient Command 必须有全局调用数、每 Command 结果数和协作式耗时预算；Host 使用稳定优先级选择预算内的命令，并允许用户逐项停用主动匹配。短于 `minLength`、长于 `maxLength`、不可用、被停用或超出本次调度预算的 Command 不调用 resolver。Palette 隐藏时取消查询、清空 deferred 队列并停止驱动。

## 动态列表

动态 item 是结构化数据，至少包括 stable item ID、主文本、可选副文本、图标、availability 和 opaque payload。Host 拥有行 frame、选中状态、滚动、鼠标/键盘事件和生命周期。选择 item 后，Host 将 Command ID、item ID、action ID 和 payload 交给对应 Intent factory；Extension 不直接接管全局输入框。Context、payload 和第三方返回值在复制、比较、排序、格式化、记录或持久化前必须递归检查 `issecretvalue`、`canaccessvalue` 和表的 `canaccesstable`；不安全值不得进入索引、Intent、日志或 SavedVariables，并返回稳定错误码。

### 结果交互合同

item 可以有如下有界 `interaction` 描述符：

```lua
interaction = {
    primaryActionID = "open-detail",
    actions = {
        { id = "open-detail", title = "查看详情", kind = "intent" },
        { id = "open-guide", title = "在指南中打开", kind = "intent", enabled = true },
    },
    drag = { type = "spell", spellID = 12345 }, -- 可选；当前只有 spell
}
```

`actions` 最多四项，每项 ID 在同一 item 内稳定且唯一。Host 只接受 `kind = "intent"` 的普通动作和由 Host 自己解释的 `kind = "secure-spell"`；描述符不能携带回调、Frame、宏文本、任意 secure attribute 或无界数据。普通 action 由 Command 的 `itemIntent(item, actionID, context)` 生成结构化 Intent，随后由 IntentRouter 路由；同一 item 的跨 Extension Handler、PanelFactory 或 transition 一律拒绝。

行只有一个普通 primary action 时，用户左键点击行或按 Enter 都调用该 action。多个动作时，左键/Enter 只调用 `primaryActionID`，其余动作由 Host 在行内稳定动作槽中绘制可见按钮；Host 不按标题、图标或 Provider 名称猜测动作。安全 primary action 不可由 Enter 调用，必须由用户真实左键点击 Host 预配置的 secure 行/按钮；Host 对 Enter 返回 `ACTION_REQUIRES_HARDWARE_CLICK`。

`drag` 仅允许 `type = "spell"` 和有限 numeric `spellID`。Host 只在可见、当前 generation、已启用、脱战且该 spell 已验证可用/非被动时，为该行显示专用拖拽区域；真实 `OnDragStart` 调用 `C_Spell.PickupSpell(spellID)`，之后由标准动作条接收鼠标光标内容。点击行、Enter、普通 Lua 调用、resolver 或 `itemIntent` 不得触发 PickupSpell。无效描述符、不支持的类型、不可用 spell、旧行或战斗状态返回 `INVALID_INTERACTION`、`DRAG_UNSUPPORTED`、`ACTION_UNAVAILABLE`、`STALE_GENERATION` 或 `COMBAT_LOCKED`，且不改变鼠标光标。

安全法术动作使用 `kind = "secure-spell"` 和声明式 `spellID`，只由 Host 的 `SecureActionButtonTemplate` 行/按钮在脱战绑定 item 后配置。该 button 的真实鼠标点击是唯一施放路径；IntentRouter、Enter、普通 action callback 和 scripted `Button:Click()` 不得模拟或转发为 secure click。安全按钮、drag 和普通动作均绑定 Extension ID、stable item ID、action ID、session/context token 和 generation；输入改变、关闭、进战、disable、retiring 或 removed 后立即失效。

resolver 可以通过 CapabilityBroker 查询 Provider，但不能持有 Provider 函数引用。大规模实体数据由 Provider 或所属模块在注册/数据更新时维护轻量名称索引；按键热路径只查索引，不全表扫描，不把每个实体注册成 Command。

item Intent 成功后，Handler 可返回声明式视图转换：`transition = { type = "custom-panel", panelFactoryID = string, state = plainData }`。Host 必须确认 PanelFactory 属于同一 Extension、当前会话和 Context 仍有效，并对 state 执行边界/schema 校验，之后才由 ViewHost Mount；resolver、Provider 和 Handler 都不能直接取得 Palette 根 frame或绕过 ViewHost。

普通 item action 可以让 Handler 直接执行普通动作或返回上述 transition。打开外部指南页面同样是 Intent：相应 adapter 必须是同 Extension 的可选能力，只调用目标 AddOn 的稳定公开接口；目标未加载、未接入或不支持该实体时 action 返回 `ACTION_UNAVAILABLE`，不操纵其内部 frame、不影响其他 action，也不阻止打开 Lychee 自己的详情 Panel。

大秘境怪物示例链路：

```text
输入怪物名称
  -> mythic-creature Command 的 ambient match 命中
  -> resolver 通过 creature Provider 查询名称索引
  -> Host 绘制结构化怪物 item
  -> itemIntent 生成 open-creature-detail Intent
  -> Handler 返回 custom-panel transition
  -> ViewHost 挂载详情 Panel
```

四类内置搜索场景都遵循同一链路，其中玩家技能与副本传送共用 `PlayerSpells` Extension：

1. `DungeonGuideProvider` 建立怪物名与怪物技能到怪物记录的反向索引；其 item 的普通动作打开 Lychee 详情或可选 MRT/指南 adapter。
2. `PlayerSpells` Extension 的 `PlayerSpellProvider` 只建立一份当前角色已知的有效法术快照，并通过一个 SearchSource 发布；`PlayerSpellAliases.lua` 只维护 Locale 别名投影，包括“复仇之怒”对应“翅膀”等技能俗称和已知传送法术对应“红玉”等副本简称。当前记录只提供 secure-spell action 和 spell drag，不注册 Command、CapabilityProvider、IntentHandler 或空详情 Panel。
3. `DungeonAliasProvider` 将 Boss 名称、赛季简称（例如 `M1`）和版本别名映射为攻略实体；item action 打开同 Extension 的详情 Panel。
4. 副本传送搜索属于第 2 项 `PlayerSpells` 的别名场景，不新增额外 Provider、独立目录或第二份法术索引；输入副本简称返回 canonical spell item，支持专用区域拖拽和真实点击的 secure-spell action。

PlayerSpells Commit 后保存 `GetSearchSource("records")` 的窄 handle，事件合并刷新只通过该 handle 原子提交；停用时停止事件，重新启用后刷新，注销时释放 handle。业务模块不直接访问 StaticIndex 或维护 source generation。

## 生命周期和隔离

Extension 至少具有 draft、pending、registered、enabled、slow、disabled、retiring 和 removed 状态。`Commit()` 是进入 registry 的唯一时点。错误、超时或禁用只移除本 Extension 的动态任务和索引项。注销时先标记 retiring，当前查询安全结束后再移除。

PublicAPI 不支持 Extension 声明的 API major/minimum revision 时，`Commit()` 原子失败并返回 `UNSUPPORTED_API`。PublicAPI 支持该声明、但当前 Host revision 不足时，`Commit()` 成功且 Extension 进入 `pending/incompatible`，诊断码为 `INCOMPATIBLE_HOST`，不执行第三方回调。

## 第三方接入发现

发现必须分为加载期和运行期两条路径：

1. **加载期顺序：** 第三方 TOC 声明 `## OptionalDeps: Lychee`，请求优先加载 Lychee；这不是 Lychee 存在或注册成功的证明。第三方主 chunk 必须检查 `_G.Lychee`，facade 存在即可创建 draft、注册子声明并 `Commit()`；Host 尚未 ready 时进入 pending，缺失 facade 时监听 `ADDON_LOADED`。`RegisterReady` 只用于 ready 通知，不是 `Commit()` 前置条件。
2. **运行期事实源：** Lychee Host 的 ExtensionRegistry 保存每个 Extension 的注册句柄、API 版本、能力声明和状态。未 Commit draft、TOC 元数据和 AddOn loaded 状态都不算接入。Lychee ready 后消费 pending registry，并通过显式 `onHostAttached`/`onHostDetached` 生命周期通知。
3. **诊断扫描：** Lychee 可在登录或诊断页一次性枚举 `C_AddOns.GetNumAddOns`、`C_AddOns.GetAddOnInfo`、`C_AddOns.GetAddOnMetadata` 和 `C_AddOns.GetAddOnDependencies`，展示 `X-Lychee-*` 元数据、依赖和加载原因；输入变化时禁止重新枚举。`C_AddOns.IsAddOnLoaded` 必须同时读取 `(loadedOrLoading, loaded)`，仅第二返回值为 true 才是加载完成，第一返回值单独为 true 时显示 `loading`。
4. **按需加载：** 声明 `LoadOnDemand` 和 `X-Lychee-Keywords` 的候选可进入登录期轻量索引；用户明确选择后 Host 调用 `C_AddOns.LoadAddOn`，然后等待其 Commit。缺少关键词元数据的 LoD AddOn 只在诊断页或其他已加载入口中出现。加载成功不代表注册成功，必须以 committed registry 为准。
5. **通信边界：** `C_ChatInfo.RegisterAddonMessagePrefix`/`SendAddonMessage` 只用于客户端间消息，不能作为本机插件 SDK RPC。SDK 调用使用同一客户端内的 Lua 表、受限 context 和结构化 payload。

第三方先加载而 Lychee 尚未 ready 时，已 Commit 的句柄留在 pending registry；Lychee 先 ready 而第三方后加载时，`Commit()` 立即注册。两种顺序必须产生相同的 registered Extension，不要求第三方重试注册，也不在输入时重新扫描 AddOn。

## 性能

- Palette 隐藏时无常驻 per-frame Lua 工作。
- 静态 Catalog 在注册/显式失效时更新，不在每次按键时重建。
- ambient Command 只在显式声明、用户启用、长度/availability 规则命中且位于本次稳定调度预算内时调用。
- 动态 resolver 有全局调用数、单 Command 结果数和协作式耗时上限；实体数据使用预索引/缓存，不在每次按键全量扫描。
- 结果行池化并按 stable ID 增量更新。
- 交互行按 `itemID + actionID` 复用有限动作槽和可选拖拽区域；绑定/解绑只在结果 diff 时发生，不在鼠标移动、每帧或 resolver 内创建 frame/闭包。
- secure-spell 行只在脱战、数据绑定或显式 dirty flush 时配置；普通 action、drag 和 secure execution 不做按键全表扫描。
- ContextStore 事件驱动并按 slice version 失效。

## SDK 边界

SDK 提供 Extension 注册、Command 发布、Capability 注册/调用、Intent factory 注册、动态列表 resolver、custom-panel factory 和生命周期句柄。SDK 不提供 Palette frame、数据库根表、SecureButton、任意 Lua source 执行或第三方全局快捷键。所有第三方调用都经过 API 版本、稳定 ID、参数 schema 和错误边界校验；内部模块也使用同一 Command/Provider/Intent 数据模型。

内置复杂面板也注册 PanelFactory 并使用同一 ViewHost 生命周期。内部 PanelContext 可以获得明确列出的 ContextStore 只读查询、配置 facade、CapabilityBroker 和诊断接口，但不能接管 Palette 根 frame 或绕过焦点、Esc、IntentRouter 与清理状态机。Host 自身的 Palette/Input/ResultList/ViewHost 基础 UI 不作为 Command 面板注册。
