# Lychee Command Platform

## 本 change 的交付形式

本规格通过 `docs/ARCHITECTURE.md` 交付系统设计，不创建 Lua/XML/TOC 运行时代码。文档必须完整定义下述模型、依赖方向、生命周期、性能门槛、后续实现顺序和验证矩阵；示例 API 属于后续实现 change 的约束。

## 目标

Lychee 提供一个单入口命令平台。用户输入只匹配 Command；Command 可调用一个或多个 CapabilityProvider，并通过 IntentHandler 执行普通或受保护动作。

## 核心模型

```text
Extension
├─ Command              发布可搜索入口（CommandSource 仅指该逻辑角色）
├─ CapabilityProvider  提供可复用数据/能力
├─ IntentHandler       执行白名单 Intent
└─ PanelFactory        创建受 ViewHost 管理的复杂面板
```

### Extension

Extension 是内部模块或第三方插件的稳定身份，至少包含稳定 ID、API 版本、显示名称、能力声明和生命周期状态。第三方通过独立 `LycheeSDK` 创建 draft，注册全部子声明后调用 `Commit()` 原子发布；Host 未加载时 committed registration 进入 pending registry，Host attach 后一次性消费。

第三方数据不会因 AddOn 已加载或 Provider 已注册而自动进入搜索。第三方若要让实体名称参与 Lychee 主输入框搜索，必须在同一 Extension draft 中同时注册 CapabilityProvider 和引用该能力的 `ambient` `dynamic-list` Command，再以 `Commit()` 原子发布。SDK 返回的 Extension 句柄是状态查询、owner 启停和幂等 `Unregister()` 的唯一控制入口；Lychee 不通过扫描 AddOn 目录推断或补造搜索接入。

### Command

Command 是唯一可搜索和选择的入口，至少包含 stable ID、标题、别名/关键词、match、presentation、参数描述和 Intent factory。Command 不直接暴露任意回调给 UI。Provider 中的实体不会自动进入全局搜索；需要直接搜索实体名称时，仍由一个 Command 声明主动匹配并调用 Provider。

Command 的匹配模式：

- `catalog`：默认模式。只通过标题、别名、关键词、拼音和显式命令语法进入静态候选。
- `ambient`：主动内容匹配。只允许 `dynamic-list` 使用；当规范化输入满足 `minLength`、`maxLength`、availability、用户启用状态和 Host 预筛选时，QueryOrchestrator 才调用 resolver。注册时必须显式提供长度边界，非法组合原子失败。

支持的 presentation：

- `row`：Host 统一绘制单行结果，选择后立即路由 Intent。
- `dynamic-list`：Command 命中后请求结构化 items，由 Host 统一绘制、导航和选择。
- `custom-panel`：Command 命中后进入 Lychee 管理的 ViewHost。第三方拿到受限 `PanelContext`，只在 Host 提供的 content frame 中创建和更新自己的子 frame；Lychee 仍拥有输入焦点、Esc/关闭、尺寸、层级、超时和清理。

`custom-panel` 不是把 Palette frame 交给第三方。第三方不能替换根 frame、注册全局快捷键或修改 Host 的 secure 属性。Panel 实例由 Host 复用，必须实现 `Mount(context)`、可选的 `Update(state)`、`Unmount()` 和可选 `Dispose()`；隐藏 Palette 时 Host 调用 `Unmount`。Host 托管 timer/ticker 使用可取消的 `C_Timer.NewTimer`/`NewTicker` 句柄；`C_Timer.After` 没有可取消句柄，只能使用 generation/active guard 丢弃迟到回调。第三方自己创建的事件、ticker 和 timer 由其清理。

### CapabilityProvider

CapabilityProvider 按稳定 capability type 注册输入/输出契约。它不进入搜索结果、不持有 Palette frame、不注册 Lychee 快捷键，也不决定结果行布局。一个 Provider 可服务多个 Command，同一 capability type 可有多个实现并由 Host/用户选择默认实现。

### IntentHandler

IntentHandler 只处理已注册的 Intent type。普通动作经错误边界执行；受保护动作使用声明式 Secure Descriptor，以及通过 `CreateFrame(..., "SecureActionButtonTemplate")` 创建并在脱战时配置的 Host 安全按钮。Lychee 采用严格的战斗策略：战斗中 Palette 不可用，所有 Lychee Intent 返回 `COMBAT_LOCKED`，不暴露战斗内真实点击入口；Enter、`dispatchIntent` 和 scripted `Button:Click()` 永远不能模拟硬件点击。UI 不按名称直接调用 Provider 函数。

## 快捷键与战斗状态

Lychee 只注册 `TOGGLELYCHEE`。实现必须提供 `Bindings.xml` 中的 `<Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">`、稳定全局 Toggle 函数，以及 `BINDING_HEADER_LYCHEE`/`BINDING_NAME_TOGGLELYCHEE` 本地化全局文案。Toggle 入口第一步检查 `InCombatLockdown()`：战斗中静默返回，不打开、不关闭、不移动焦点、不启动查询。收到 `PLAYER_REGEN_DISABLED` 时，已打开的 Palette 立即走与 Esc 相同的关闭、`Unmount` 和任务清理路径；`PLAYER_REGEN_ENABLED` 后快捷键无需重新绑定即可恢复。关闭时恢复原 EditBox 只作 best-effort：对象和相关方法仍可访问时才尝试，否则只清除 Lychee 输入焦点。

## 查询链路

```text
输入变化
  -> generation + 1
  -> normalize/tokenize/intent parse
  -> 静态 Command Catalog 候选
  -> 计算满足规则的 ambient dynamic Command
  -> context/availability filter
  -> stable rank
  -> 发布普通结果
  -> 只调用已命中的 catalog/ambient dynamic-list resolver
  -> 校验 generation
  -> diff render
```

输入合并使用唯一 debounce；新 generation 使旧动态结果失效。ambient Command 必须有全局调用数、每 Command 结果数和协作式耗时预算；Host 使用稳定优先级选择预算内的命令，并允许用户逐项停用主动匹配。短于 `minLength`、长于 `maxLength`、不可用、被停用或超出本次调度预算的 Command 不调用 resolver。Palette 隐藏时取消查询、清空 deferred 队列并停止驱动。

## 动态列表

动态 item 是结构化数据，至少包括 stable item ID、主文本、可选副文本、图标、availability 和 opaque payload。Host 拥有行 frame、选中状态、滚动、鼠标/键盘事件和生命周期。选择 item 后，Host 将 Command ID、item ID 和 payload 交给对应 Intent factory；Extension 不直接接管全局输入框。Context、payload 和第三方返回值在复制、比较、排序、格式化、记录或持久化前必须递归检查 `issecretvalue`、`canaccessvalue` 和表的 `canaccesstable`；不安全值不得进入索引、Intent、日志或 SavedVariables，并返回稳定错误码。

resolver 可以通过 CapabilityBroker 查询 Provider，但不能持有 Provider 函数引用。大规模实体数据由 Provider 或所属模块在注册/数据更新时维护轻量名称索引；按键热路径只查索引，不全表扫描，不把每个实体注册成 Command。

item Intent 成功后，Handler 可返回声明式视图转换：`transition = { type = "custom-panel", panelFactoryID = string, state = plainData }`。Host 必须确认 PanelFactory 属于同一 Extension、当前会话和 Context 仍有效，并对 state 执行边界/schema 校验，之后才由 ViewHost Mount；resolver、Provider 和 Handler 都不能直接取得 Palette 根 frame或绕过 ViewHost。

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

## 生命周期和隔离

Extension 至少具有 draft、pending、registered、enabled、slow、disabled、retiring 和 removed 状态。`Commit()` 是进入 registry 的唯一时点。错误、超时或禁用只移除本 Extension 的动态任务和索引项。注销时先标记 retiring，当前查询安全结束后再移除。

## 第三方接入发现

发现必须分为加载期和运行期两条路径：

1. **加载期顺序：** 第三方 TOC 声明 `## OptionalDeps: LycheeSDK`，请求在双方均可用时先加载 SDK；这不是 SDK 存在或注册成功的证明。第三方主 chunk 必须检查 `_G.LycheeSDK`，存在时才创建 draft、注册子声明并 `Commit()`；缺失时走无 Lychee 的短路路径，不创建 Palette 相关 frame。
2. **运行期事实源：** LycheeSDK committed registry 保存每个 Extension 的注册句柄、API 版本、能力声明和状态。未 Commit draft、TOC 元数据和 AddOn loaded 状态都不算接入。Lychee Host attach 后消费 pending registry，并通过显式 `OnHostAttached`/`OnHostDetached` 生命周期通知。
3. **诊断扫描：** Lychee 可在登录或诊断页一次性枚举 `C_AddOns.GetNumAddOns`、`C_AddOns.GetAddOnInfo`、`C_AddOns.GetAddOnMetadata` 和 `C_AddOns.GetAddOnDependencies`，展示 `X-Lychee-*` 元数据、依赖和加载原因；输入变化时禁止重新枚举。`C_AddOns.IsAddOnLoaded` 必须同时读取 `(loadedOrLoading, loaded)`，仅第二返回值为 true 才是加载完成，第一返回值单独为 true 时显示 `loading`。
4. **按需加载：** 声明 `LoadOnDemand` 和 `X-Lychee-Keywords` 的候选可进入登录期轻量索引；用户明确选择后 Host 调用 `C_AddOns.LoadAddOn`，然后等待其 Commit。缺少关键词元数据的 LoD AddOn 只在诊断页或其他已加载入口中出现。加载成功不代表注册成功，必须以 committed registry 为准。
5. **通信边界：** `C_ChatInfo.RegisterAddonMessagePrefix`/`SendAddonMessage` 只用于客户端间消息，不能作为本机插件 SDK RPC。SDK 调用使用同一客户端内的 Lua 表、受限 context 和结构化 payload。

SDK 先加载而 Host 后加载时，已 Commit 的句柄留在 pending registry；Host 先加载而第三方后加载时，`Commit()` 立即触发 attach。两种顺序必须产生相同的 registered Extension，不要求第三方重试注册，也不在输入时重新扫描 AddOn。

## 性能

- Palette 隐藏时无常驻 per-frame Lua 工作。
- 静态 Catalog 在注册/显式失效时更新，不在每次按键时重建。
- ambient Command 只在显式声明、用户启用、长度/availability 规则命中且位于本次稳定调度预算内时调用。
- 动态 resolver 有全局调用数、单 Command 结果数和协作式耗时上限；实体数据使用预索引/缓存，不在每次按键全量扫描。
- 结果行池化并按 stable ID 增量更新。
- ContextStore 事件驱动并按 slice version 失效。

## SDK 边界

SDK 提供 Extension 注册、Command 发布、Capability 注册/调用、Intent factory 注册、动态列表 resolver、custom-panel factory 和生命周期句柄。SDK 不提供 Palette frame、数据库根表、SecureButton、任意 Lua source 执行或第三方全局快捷键。所有第三方调用都经过 API 版本、稳定 ID、参数 schema 和错误边界校验；内部模块也使用同一 Command/Provider/Intent 数据模型。

内置复杂面板也注册 PanelFactory 并使用同一 ViewHost 生命周期。内部 PanelContext 可以获得明确列出的 ContextStore 只读查询、配置 facade、CapabilityBroker 和诊断接口，但不能接管 Palette 根 frame 或绕过焦点、Esc、IntentRouter 与清理状态机。Host 自身的 Palette/Input/ResultList/ViewHost 基础 UI 不作为 Command 面板注册。
