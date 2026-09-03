# Lychee 命令平台架构设计

> 状态：Design Contract v0.4
>
> 本文是后续实现和评审的系统级契约。公开 SDK 的字段、示例和第三方接入步骤见
> [SDK.md](SDK.md)。需要改变本文中的分层、所有权或生命周期时，先更新设计文档，再进入代码变更。

## 1. 产品边界

Lychee 是 World of Warcraft 内的单入口命令平台。用户通过唯一全局快捷键呼出输入框，搜索命令、选择动态结果，或进入 Lychee 托管的交互视图。

### 1.1 目标

- 一个全局 Binding：`TOGGLELYCHEE`。
- 内置能力和第三方能力使用同一套 Command、SearchSource/SearchRecord、CapabilityProvider 和 Intent 模型。
- 普通结果和动态列表由 Lychee 统一绘制。
- 复杂交互通过 Lychee 托管的 ViewHost 承载。
- 中文、英文、拼音和别名使用确定性本地匹配，不依赖运行时网络或 AI。
- 命令名和实体名共用一个 Host 搜索引擎：Command 是固定命令入口，SearchSource/SearchRecord 是技能、任务、副本、成就和第三方实体的统一收录协议。
- Palette 隐藏且无任务时，Lua 每帧工作为零。
- 单个第三方扩展的错误、超时或卸载不影响其他扩展和 Palette 关闭。
- Host 与 SDK 都采用轻量自有实现，不依赖 Ace3 全家桶。

### 1.2 本设计不包含

- 操作系统级启动器或游戏外快捷键。
- 插件市场、下载、安装和自动更新服务。
- 客户端间同步协议。
- 第三方独立全局快捷键。
- 第三方对 Palette 根 frame、Host SavedVariables 或 SecureButton 的访问。
- 任意 Lua 源码下载或执行。

## 2. 核心分层

```text
Extension
├─ Command
│  └─ fixed searchable entry -> Presentation -> Intent
├─ SearchSource
│  └─ SearchRecord snapshot -> Host SearchIndex -> SearchResult
├─ CapabilityProvider
│  └─ typed capability -> structured result
├─ IntentHandler
│  └─ typed intent -> policy -> execution result
└─ PanelFactory
   └─ custom-panel -> host-owned ViewHost lifecycle
```

| 概念 | 职责 | 明确排除 |
| --- | --- | --- |
| Extension | 内部模块或第三方 AddOn 的稳定身份和生命周期容器 | 搜索、绘制和执行策略 |
| Command | 用户可搜索、选择的固定入口 | 共享数据服务和任意 UI frame |
| SearchSource | 发布可搜索实体的快照、增量更新和生命周期 | 匹配、排序、结果行和 Palette 根 frame |
| SearchRecord | 描述一个稳定实体、类别、局部化文本和声明式动作 | 任意 Lua 回调、Frame 和第二套索引 |
| CapabilityProvider | 提供可复用数据或能力 | 搜索入口、结果布局和 Palette 控制 |
| IntentHandler | 执行已注册的结构化动作 | 按显示文本调用函数 |
| PanelFactory | 为 `custom-panel` 创建受控 Panel 实例 | Palette 根 frame、全局焦点和全局快捷键 |
| Presentation | 描述结果由 Host 如何呈现 | 绕过 Host 生命周期 |
| ContextSnapshot | Host 维护的只读游戏状态切片 | 第三方自建全量状态镜像 |

SearchSource、Command 与 CapabilityProvider 必须分层。新增稳定可搜索实体时注册 SearchSource；新增固定入口或真实动态组合查询时注册 Command；新增可复用数据能力时注册 CapabilityProvider；新增普通执行动作时注册 IntentHandler。一个 Command 可以组合多个能力，一个能力也可以服务多个模块，但业务域只声明自己实际需要的角色。

Extension 可以在同一注册草稿中发布一组 Command；这不是独立的公共对象、registry 或第二套注册 API。公开接入统一使用 Extension draft 上的 `RegisterCommand`。

## 3. 单一事实源

系统始终只有以下实例：

1. 一个 `ExtensionRegistry`：保存 SDK 和内部 Extension 的规范化状态。
2. 一个 `CommandCatalog`：独占固定 Command 的私有索引、优先级、启停状态、查询和 ambient 调度视图；Command 不写入实体 SearchIndex。
3. 一个 `SearchIndex`：只保存 SearchSource/SearchRecord 的活动实体索引。
4. 一个 `SearchSession`：唯一拥有 Palette session、query generation、防抖、取消和结果接纳。
5. 一个 `QueryOrchestrator`：执行 Catalog、实体索引和 ambient resolver 的查询与结果合并，不持有 UI 会话状态。
6. 一个 `Ranker`：负责确定性评分和稳定排序。
7. 一个 `ContextStore`：把 WoW 事件转换为版本化状态切片。
8. 一个 `IntentRouter`：校验并路由普通 Intent。
9. 一个 `ResultActionExecutor`：统一校验结果 token，并编排 Intent、Panel、drag 和 secure-spell。
10. 一个 `PaletteController`：拥有快捷键、焦点、结果列表和 ViewHost，只转交查询与动作事件。

UI 不按名称直接调用第三方函数。第三方不持有上述对象的可变表。

## 4. 仓库与 AddOn 布局

后续实现使用一个 Lychee Host AddOn；SDK 是 Lychee 暴露的公共 API，不是第二个运行时 AddOn。第三方插件把 Lychee 集成代码放在自己的 AddOn 内。

```text
Lychee/
├─ package/
│  ├─ Lychee/
│  │  ├─ Lychee.toc
│  │  ├─ Bindings.xml
│  │  ├─ Bootstrap.lua
│  │  ├─ Core/
│  │  │  ├─ Lifecycle.lua
│  │  │  ├─ ExtensionRegistry.lua
│  │  │  ├─ CommandCatalog.lua
│  │  │  ├─ CapabilityBroker.lua
│  │  │  ├─ ContextStore.lua
│  │  │  ├─ IntentRouter.lua
│  │  │  ├─ ResultActionExecutor.lua
│  │  │  ├─ Scheduler.lua
│  │  │  └─ Diagnostics.lua
│  │  ├─ Search/
│  │  │  ├─ Normalizer.lua
│  │  │  ├─ Tokenizer.lua
│  │  │  ├─ IntentParser.lua
│  │  │  ├─ RuntimeIdentity.lua
│  │  │  ├─ StaticIndex.lua
│  │  │  ├─ Ranker.lua
│  │  │  ├─ QueryOrchestrator.lua
│  │  │  └─ SearchSession.lua
│  │  ├─ UI/
│  │  │  ├─ Palette.lua
│  │  │  ├─ Theme.lua
│  │  │  ├─ Input.lua
│  │  │  ├─ ResultList.lua
│  │  │  ├─ ViewHost.lua
│  │  │  └─ FocusController.lua
│  │  ├─ Secure/
│  │  │  ├─ Descriptor.lua
│  │  │  ├─ Policy.lua
│  │  │  └─ SecureActionBroker.lua
│  │  ├─ PublicAPI/
│  │  │  ├─ SDK.lua
│  │  │  ├─ Schema.lua
│  │  │  ├─ Extension.lua
│  │  │  └─ Ready.lua
│  │  ├─ Builtin/
│  │  │  ├─ Data/
│  │  │  │  ├─ PlayerSpellAliases.lua  # 可替换别名数据，不是技能源
│  │  │  │  └─ DungeonGuide.lua       # 可替换攻略数据，不由 Provider 写死
│  │  │  ├─ DungeonGuide/
│  │  │  ├─ PlayerSpells/
│  │  │  │  ├─ Provider.lua
│  │  │  │  └─ Init.lua
│  │  │  ├─ DungeonAliases/
│  │  │  ├─ Quests/
│  │  │  └─ Cooldowns/
│  │  └─ Media/
├─ sdk/
│  ├─ README.md                # 第三方开发说明
│  ├─ examples/                # 可复制的接入样例
│  └─ stubs/                   # 编辑器提示/测试桩，不加载进客户端
├─ docs/
│  ├─ ARCHITECTURE.md
│  └─ SDK.md
├─ analyze/                    # 本机调研，Git 忽略
└─ AGENTS.md                   # 本机执行约定，Git 忽略
```

正式服安装布局：

```text
Interface/AddOns/
├─ Lychee/
└─ ThirdPartyAddOn/
```

依赖方向固定为：

```text
Bootstrap -> Core
Search    -> Core 的只读接口
UI        -> QueryOrchestrator + IntentRouter
Secure    -> IntentRouter 的 Descriptor
PublicAPI -> Core 的受限只读 facade
Builtin   -> 与第三方相同的 PublicAPI 注册 facade
ThirdPartyAddOn -> OptionalDeps: Lychee
```

Lychee 本体在加载时创建 `_G.Lychee` 公共 facade，并发布 ready 状态。第三方 AddOn 使用 `## OptionalDeps: Lychee`；没有 Lychee 时只跳过集成，自身功能继续工作。`LycheeSDK` 是这套公共 API 的名称和文档，不单独占用一个 AddOn 目录。

## 5. AddOn 发现与通信

WoW 内的插件运行在同一个 Lua 环境中，接入不需要桌面应用式 IPC。

### 5.1 加载拓扑

第三方 TOC 声明：

```toc
## OptionalDeps: Lychee
```

`OptionalDeps` 用于声明希望先加载 Lychee；它不强制用户安装或启用 Lychee，也不能代替运行时检查 `_G.Lychee`。真正的加载结果和接入状态仍由运行时确认。

加载流程：

```text
Lychee 本体加载
  -> 创建 _G.Lychee facade、PublicAPI 和私有 registry
第三方 AddOn 加载
  -> 取得 _G.Lychee 公共 API
  -> RegisterExtension(descriptor)
  -> RegisterCommand/RegisterSearchSource/RegisterCapabilityProvider/RegisterIntentHandler/RegisterPanelFactory
  -> Commit()
  -> 进入 Lychee ExtensionRegistry
  -> 建立 Command/Provider/Intent/Panel 索引
```

如果第三方先加载且 `_G.Lychee` 尚不存在，集成代码监听 `ADDON_LOADED` 的 `Lychee`；facade 一旦存在即可创建 draft 并 `Commit()`，不要求 Host 已 ready。Host 尚未 ready 时 committed Extension 进入 pending，ready 后转为 registered；Host 已 ready 时立即注册。Lychee 缺席时，第三方跳过集成路径，其自身功能继续运行。

`RegisterReady(callback)` 只能在 facade 已存在后调用，用于接收 Host ready 通知，不是创建 draft 或 `Commit()` 的前置条件。第三方不得在 `_G.Lychee` 不存在时调用它，也不需要用 timer 轮询 ready。ready callback 不负责创建 Palette、结果行或安全按钮。

第三方必须主动通过 `_G.Lychee` 创建完整 Extension draft，注册需要的 SearchSource、Command、Provider、Handler 和 PanelFactory，并以 `Commit()` 一次性发布。Lychee 不扫描插件目录猜测接入；AddOn 已加载、TOC 已声明或单独注册 Provider 都不会自动变成搜索结果。实体名直接通过 SearchSource 收录；只有需要按输入即时组合能力时，才额外注册 `ambient` `dynamic-list` Command。

Lychee PublicAPI 必须支持以下两个等价时序，并对每个 Extension 只提交一次注册事务：

```text
Third-party first: wait for ADDON_LOADED -> facade -> Register* -> Commit -> pending -> ready -> registered
Lychee first:      facade ready -> RegisterExtension -> Register* -> Commit -> registered immediately
```

### 5.2 发现策略

Lychee ExtensionRegistry 是“已接入”的唯一事实源。以下 API 只用于登录期诊断、兼容性展示和按需加载：

- `C_AddOns.GetNumAddOns`
- `C_AddOns.GetAddOnInfo`
- `C_AddOns.GetAddOnMetadata`
- `C_AddOns.GetAddOnDependencies`
- `C_AddOns.IsAddOnLoaded`，返回 `loadedOrLoading, loaded`
- `C_AddOns.LoadAddOn`

Addon 枚举不进入每次按键的查询链路。LoD AddOn 被加载后，Host 仍等待它创建并成功 `Commit` Extension；“已加载”和“已接入”是两个状态。

诊断必须区分三种事实，不能根据 TOC 元数据推断注册成功：

1. `installed`：AddOn 可被 `C_AddOns` 枚举。
2. `loading/loaded`：调用 `local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(name)`；`loaded == true` 才是加载完成，`loadedOrLoading == true` 且 `loaded == false` 表示正在加载，两者均为 false 表示尚未加载。
3. `sdk-registered`：Extension 已成功 `Commit`，并进入 pending 或 registered registry。未提交草稿不算接入。

`X-Lychee-*` TOC 字段只提供候选信息和诊断文案。LoD AddOn 若希望在加载前可被搜索，必须声明可索引的 `X-Lychee-Keywords`；Host 在登录期一次性建立轻量候选索引，用户选择候选后才调用 `C_AddOns.LoadAddOn`。缺少该元数据的 LoD AddOn 只在诊断页或其他已加载入口中出现。Host 不在每次输入时扫描或自动加载所有候选。

两个返回值来自 wowdoc `wow-ui-source`、retail `12.1.0`、提交 `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b` 的 `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`（322-335）。

### 5.3 通信边界

本机 SDK 调用使用 Lua 表、注册句柄和结构化 payload。`C_ChatInfo.RegisterAddonMessagePrefix` 与 `C_ChatInfo.SendAddonMessage` 属于客户端间文本消息通道，不参与本机注册、查询或 Intent 调用。

### 5.4 Secret 与不可访问值边界

SDK schema 层和 Host 的所有数据入口共用一个递归 plain-data validator。它用于 Extension descriptor、Command/Provider 声明、ContextSnapshot 字段、capability request/result、dynamic item、Intent payload 和 ExecutionResult；只允许受限深度和数量的 `nil`、boolean、有限 number、string 与无环 plain table。

校验顺序是安全契约，而不是实现细节：

1. `nil` 直接按 schema 处理；对每个非 nil 根值、table key 和 table value，先调用 `issecretvalue(value)`；为 true 时立即拒绝，不做比较、格式化、复制或字符串化。
2. 再调用 `canaccessvalue(value)`；为 false 时立即拒绝。
3. 值为 table 时，必须先确认 `canaccesstable(value)`，之后才允许 `next`/`pairs`、索引或递归。
4. 通过访问检查后再做类型、循环、深度、字段数和 schema 校验；key 与 value 都递归执行同一顺序。
5. 任一步失败只返回稳定错误码和不包含原值的字段路径，例如 `INACCESSIBLE_VALUE`；诊断不得记录该值、table 内容或由其派生的文本。

Secret 或当前调用方不可访问的数据不得进入 CommandCatalog/StaticIndex/Ranker、Intent、recent/favorite、诊断 ring buffer、缓存或 SavedVariables。ContextStore 从 Blizzard API 收到这类字段时丢弃该字段或整个受影响切片、递增无 payload 的计数器并使相关 capability 返回 unavailable；不得把占位字符串或原值转交第三方。

这些检查依据 wowdoc `wow-ui-source`、retail `12.1.0`、提交 `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`：`FrameScriptDocumentation.lua` 中 `issecretvalue`（263）、`canaccessvalue`（65）和 `canaccesstable`（48）。

## 6. Extension 生命周期

```text
draft --Commit--> pending -> registered -> enabled -> slow
  |                                    |          |
  +--Abort/invalid--> discarded        +-> disabled
                                       +-> retiring -> removed
```

- `draft`：Extension 元数据和子声明暂存，尚未发布到 registry。
- `pending`：Extension 已提交，但 Lychee Host 尚未 ready，或 PublicAPI 已接受该版本而当前 Host revision 暂时不足。
- `registered`：Host 已完成 schema 和版本校验，尚未启用。
- PublicAPI 不支持 Extension 声明的 API major/minimum revision 时，`Commit()` 原子失败并返回 `UNSUPPORTED_API`。PublicAPI 支持但当前 Host revision 不足时，`Commit()` 成功，实例停留在 `pending/incompatible`，诊断码为 `INCOMPATIBLE_HOST`，且不执行第三方回调。
- `enabled`：Command、Provider 和 Handler 可以参与运行。
- `slow`：动态调用连续超过预算，只进入降频队列。
- `disabled`：本会话停止调用，保留诊断记录。
- `retiring`：注销已开始，等待当前 generation 和 ViewHost 清理。

注册必须是原子的。`RegisterExtension` 只创建草稿并预留 ID，四种 `Register*` 只写入草稿；`Commit()` 一次性校验交叉引用、版本、schema 和数量上限。任一子声明或 Commit 失败时不发布任何对象，草稿只能 Abort 或丢弃。重复 ID 不覆盖已提交实例。

每次注册返回不可伪造的句柄。注销使用句柄而非 ID，避免旧实例移除同 ID 的新实例。

句柄是 Extension owner 查询状态、`SetEnabled(enabled)` 和 `Unregister()` 的唯一控制入口。`SetEnabled` 只设置 owner-enabled 位，不能覆盖用户禁用、Host 兼容性或健康熔断；启停只增量更新该 Extension 的 Catalog 条目、ambient 调度资格和运行中任务。重复设置同一状态或注销均必须幂等，不得对其他 Extension 产生副作用。

Lychee facade detach 或版本切换时，`registered`/`enabled` Extension 先停止 Host 托管任务并清理 ViewHost，再回到 `pending`；后续兼容版本 ready 后重新注册。`Unregister()` 幂等，只移除 Lychee 接入，不卸载第三方 AddOn。

同一 Extension ID 的重载不是覆盖操作。SDK/Host 收到新 draft 时，旧句柄必须先进入 `retiring`：立即停止新 Command/Provider/resolver 调度，使所有活动 generation 和待处理 transition 失效，尽力 `Unmount` 并 `Dispose` 已挂载 Panel，取消 timer/ticker/deferred 与 Host 托管驱动，最后移除 Catalog 条目和 Provider 私有索引引用。只有旧句柄进入 `removed` 且上述清理屏障完成后，registry 才接受同 ID 新句柄；新 draft 在此前保持 pending/reload-wait，不可见也不参与查询。旧回调不能通过新句柄的 ID 重新激活。

## 7. Command 与 SearchRecord 模型

Command 是固定的可搜索入口；SearchRecord 是实体搜索对象。CommandCatalog 使用自己的私有索引，SearchSource/SearchRecord 进入 Host 实体 SearchIndex；两者复用相同的规范化和评分规则，并在 QueryOrchestrator 中合并为统一结果。最小 Command 形状：

```lua
{
    id = "sample.search",
    title = "搜索示例数据",
    aliases = { "示例", "sample" },
    keywords = { "search" },
    presentation = "row", -- row/dynamic-list/custom-panel
    match = { type = "catalog" },
    availability = { context = "ui-state", key = "sample.available" },
    intent = {
        type = "sample.open",
        version = 1,
        payload = {},
    },
}
```

需要主动内容匹配时，`dynamic-list` 使用：

```lua
match = {
    type = "ambient",
    minLength = 2,
    maxLength = 64,
    priority = 0,
}
```

约束：

- ID 在 Extension namespace 内稳定且唯一；Host 规范化为 `extensionID:commandID`，第三方不自行填写 `extensionID`。
- 展示文案与索引关键词分离。
- availability 读取 ContextSnapshot，不产生副作用。
- Command 不持有 Palette frame。
- `match.type` 默认为 `catalog`：Command 只通过 title、alias、keyword、拼音或显式命令语法进入静态候选。`row` 和 `custom-panel` 只能使用该模式。
- `match.type = "ambient"` 表示输入可以直接匹配 Command 背后的动态内容；它不是第二种 registry。稳定实体优先使用 SearchSource，只有需要运行时组合或查询 Provider 的场景才使用 ambient。
- `ambient` 只允许 `dynamic-list`，并必须显式声明 `minLength` 和 `maxLength`；`minLength >= 1` 且 `maxLength >= minLength`。Host 在注册期拒绝缺少/非法长度边界或 presentation 不匹配的整个 draft。
- `ambient.match.priority` 只用于预算紧张时的稳定调度顺序，同优先级按全局 Command ID 排序；它不能绕过用户禁用、availability、健康熔断或预算。
- `row` 必须声明静态 `intent`。
- `dynamic-list` 必须声明 `resolve` 和 `itemIntent`；resolver 只返回结构化 item。
- `custom-panel` 必须引用已注册的 PanelFactory ID，Panel 生命周期由 ViewHost 驱动。

SearchSource 的最小规范化形状：

```lua
{
    id = "player-spells",
    version = 1,
    priority = 80,
    revision = 7,
    scope = { product = "retail" },
    snapshot = function(context) return records end,
}
```

SearchRecord 至少包含稳定 `id`、`kind`、`category`、当前 locale 可用的 `title`，以及可选的 `aliases`、`keywords`、`description`、`scope` 和声明式 `actions`。`id` 指向同一个 canonical 实体；别名命中只产生一个结果，不复制实体。SearchSource 的 snapshot/upsert/remove 由 Host 校验后增量写入 SearchIndex；Source 禁用或注销只失效自己的记录。

## 8. CapabilityProvider 模型

Provider 以稳定 capability type 注册输入/输出契约：

```lua
{
    id = "sample.data.default",
    type = "sample.data",
    version = 1,
    priority = 0,
    requestSchema = { text = "string" },
    resultSchema = "sample.data-list.v1",
    query = function(request, context) return result end,
}
```

`CapabilityBroker` 负责：

- 按 type 和版本选择 Provider。
- 校验输入与输出 schema。
- 设置耗时、结果数和调用深度预算；v1 Provider 只执行有界同步查询，昂贵数据必须来自事件驱动缓存或预索引。协作式 deferred queue 只提供给 `dynamic-list` resolver。
- 隔离错误并返回稳定错误码。
- 按 `priority desc -> extensionID -> providerID` 确定性选择；停用、retiring 或 removed 的 Provider 不调用。

Broker 稳定区分：能力类型不存在 `CAPABILITY_NOT_FOUND`、当前没有可调用 Provider `PROVIDER_UNAVAILABLE`、请求不符合 schema `INVALID_SCHEMA`、返回值不符合 schema `INVALID_RESULT`、回调异常 `PROVIDER_ERROR`、结果超限 `RESULT_LIMIT`。本版本不提供跨查询缓存、自动重试或复杂 fallback。

Provider 本身不直接成为搜索结果、不控制结果布局、不注册快捷键；它可以被 SearchSource 用作数据源，也可以被 ambient resolver 查询。Host 内置 Provider 和第三方 Provider 进入同一 Broker；内部实现可以获得额外的 Host service，但输出必须规范化成相同 schema。

技能、任务、怪物技能等大规模实体索引由所属业务模块在注册、数据加载或相关 WoW 事件到达时增量构建为 SearchRecord，并通过 SearchSource 原子提交；不公开独立 Content Index registry，也不把每个实体注册成 Command。只有真实动态组合查询才由 resolver 在按键热路径通过 CapabilityBroker 查询预索引/缓存，且不得全表扫描。

Command 不持有 Provider 函数引用。需要能力时只提交 capability type、版本和结构化 request，由 Broker 完成选择、调用和校验。这保证更换或新增数据源不需要改写 Command 的 UI 契约。

## 9. Intent 模型与执行

Intent 是结构化动作：

```lua
{
    type = "sample.open",
    version = 1,
    payload = { itemID = "42" },
}
```

第三方通过 Extension handle 创建 Intent，只填写 `type`、`version` 和 `payload`。IntentRouter 规范化时补入可信的 `extensionID`，第三方 payload 不能覆盖归属。

执行链路：

```text
Command/item selection
  -> IntentFactory
  -> Intent schema validation
  -> availability/policy check
  -> normal or secure handler
  -> ExecutionResult
  -> recent/diagnostics update
```

`ExecutionResult` 至少包含 `ok`、稳定 code 和可选 message key。只有 `ok=true` 才写入 recent。

动态 item 需要进入详情面板时，Handler 可在成功结果中返回声明式转换：

```lua
{
    ok = true,
    transition = {
        type = "custom-panel",
        panelFactoryID = "creature-detail",
        state = { creatureID = 12345 },
    },
}
```

Host 只在 IntentRouter 成功执行 Intent 后处理 transition。它必须确认 PanelFactory 与 Command、IntentHandler 属于同一 Extension，当前 Palette session、generation 和 ContextSnapshot version 仍有效，并对 `transition.state` 执行第 5.4 节的 plain-data、secret/inaccessible、深度、字段数与 schema 校验，才能交给 ViewHost 挂载。校验失败只结束该转换，不打开 Panel；resolver、Provider 和 Handler 均不能直接持有 Palette 根 frame 或调用 Panel 生命周期。

### 9.1 普通动作

普通 Handler 通过局部 `xpcall` 执行。回调错误只结束当前 Intent，并为对应 Extension 增加失败计数。

Intent 的 schema、availability/policy、Handler 或 transition 任一阶段失败时，IntentRouter 必须停止当前动作，不执行后续 Handler/transition，不写入 recent。Palette 由 Host 统一绘制一条不包含第三方原始异常文本的错误行，并在所有成功、错误和过期退出路径上释放当前结果的 `busy` 状态，恢复键盘/鼠标选择和 Palette 关闭。该错误行只是 Host Presentation，不是 Command，不进入 Catalog、recent 或 SavedVariables。

### 9.2 受保护动作

战斗相关动作使用 Host 定义的声明式 Secure Descriptor。第三方只提交允许字段；第三方不接触按钮对象、属性写入接口或脚本源码。

SecureActionBroker 在初始化期且 `not InCombatLockdown()` 时创建 Host 自有按钮：

```lua
local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("LeftButtonUp")
```

Descriptor 先经过白名单和 schema 校验，再由 Broker 在脱战时写入 `type`、目标和动作所需的最小 attributes。按钮只在 descriptor 与可见结果一致后显示；进入战斗后不得创建按钮、修改 protected attributes、改变父级/锚点或重新绑定动作。配置失效时保持 dirty，等待 `PLAYER_REGEN_ENABLED` 后重新准备。

SecureActionButton 能执行受保护动作的前提是用户对已经显示、已在脱战完成配置的按钮进行真实硬件点击。普通 Lua 回调、`dispatchIntent`、输入框 Enter、`Button:Click()` 和其他 scripted input 不能替代这个点击；`ScriptedInput` 明确限制 Lua 触发的合成输入。

Lychee 当前产品策略更严格：战斗中 Palette 必须关闭，`TOGGLELYCHEE` 失效，所以 Lychee 不在战斗中展示或触发上述按钮。SecureActionBroker 仍按正确的模板和属性冻结规则实现，用于脱战准备、避免错误的 scripted click，并为未来单独评审的战斗交互保留清晰边界；没有新的设计变更前，不得以 secure button 为由绕过战斗关闭策略。

这一约束以 wowdoc `wow-ui-source`、retail `12.1.0`、提交 `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b` 为证据：`Blizzard_FrameXML/SecureTemplates.xml` 的 `SecureActionButtonTemplate`（4），以及 `ForbiddenAspectConstantsDocumentation.lua` 的 `ScriptedInput`（19）。后续实现需再次按目标客户端版本验证。

## 10. 搜索与语义匹配

### 10.1 查询链路

```text
Input text changed
  -> SearchSession generation + 1 / debounce
  -> normalize
  -> tokenize / intent parse
  -> CommandCatalog fixed candidate retrieval
  -> SearchIndex SearchRecord candidate retrieval
  -> prefilter eligible ambient dynamic Commands
  -> context availability filter
  -> confidence/evidence scoring and deterministic rank
  -> publish unified result cards
  -> invoke matched catalog/ambient dynamic resolvers
  -> SearchSession verifies generation + query key + context version
  -> merge and diff-render
```

每次输入变化由 SearchSession 生成单调递增 generation。固定 Command 通过 CommandCatalog 私有索引召回，SearchRecord 通过实体 SearchIndex 召回；`ambient` Command 不需要用户先输入命令名，但只在规范化查询满足其长度边界、availability、Extension/Command 启用状态和 Host 静态预筛选时获得调度资格。Provider 本身不参与该预筛选。

输入只有一个 debounce、一个 generation 和一份查询 ContextSnapshot，catalog 与 ambient 不建立两条并行状态机。动态结果返回时必须同时匹配当前 generation、query key 和它声明依赖的 context slice version；旧结果直接丢弃。

### 10.2 Normalization

规范化顺序固定：

1. 去除首尾空白并合并连续空白。
2. ASCII 转小写。
3. 全角字符转半角。
4. 统一受支持的中文标点。
5. 提取显式动词、参数和剩余 token。
6. 读取预生成的拼音全拼/首字母索引。

拼音数据在注册或构建索引时生成，按键热路径不做全量转写。

本地化和搜索别名同样在注册或数据更新时建索引。Host 在加载期读取一次 `GetLocale()`，显示文本按“当前 locale -> `default`”回退；别名既可使用兼容的 string 简写，也可使用 `{ text = string, locale = "zhCN" | "enUS" | ... | "default" }`。查询只启用当前 locale 与 `default` 的别名，避免其他语言的俗称污染候选。例如法术“复仇之怒”可以声明 `zhCN` 搜索别名“翅膀”。别名必须是经过 plain-data/secret/inaccessible 校验的显式数据，不能在按键热路径调用翻译服务、网络或生成式模型。

Command 的 title/aliases/keywords 和 Provider 实体的 canonical name/localized aliases 走同一规范化管线。Provider 在自己的业务索引中把别名映射到 canonical stable item ID；命中别名仍只返回一个 canonical item，显示当前 locale 的正式名称，不复制实体或产生第二个动作协议。相同规范化别名可映射多个实体，Host 交给稳定排序处理，注册时不得以覆盖写入的方式丢失候选。

### 10.3 候选与排序

静态索引维护 Command/SearchRecord 的 exact ID、title token、alias、keyword、description、pinyin 和 category 倒排表。候选上限默认 200，展示上限默认 20。每个候选保留最高置信度和一条 evidence（命中的字段、文本和匹配类型）。

SearchRecord 和 ambient item 都只保留结构化轻量字段，由 Host 与 Command 结果一起合并、去重和排序；详情数据在用户选中后再通过 Intent/Panel 链路加载。同分时先使用置信度、source/Command 优先级、category order，最后使用规范化 stable ID 破除平局。

排序因子按固定顺序组合：

1. exact title/alias；
2. prefix；
3. token coverage；
4. substring/keyword/description；
5. bounded fuzzy；
6. context relevance；
7. favorite/recent（只在同一匹配层级内有限加权）；
8. source/Extension priority、category order；
9. stable ID 作为最终 tie-break。

相同输入、相同 ContextSnapshot 和相同索引版本必须产生相同顺序。

### 10.4 调度

- `SearchSession` 使用单一 debounce，拥有 session/generation、取消 token 和结果接纳；Palette/Bootstrap 不直接推进 generation。
- 静态检索同步完成。
- 只有通过 catalog 命中，或通过 ambient 长度、availability、启用状态和静态预筛选的 `dynamic-list` Command 才调用 resolver。用户可以逐个停用 ambient Command，该偏好由 Host 按 stable Command ID 保存。
- QueryOrchestrator 按稳定优先级为 ambient Command 分配全局调用数、单 Command 结果数和协作式耗时预算。未获得本 generation 预算的 Command 不调用 resolver，不以不确定顺序超额执行。
- resolver 只读取查询、ContextSnapshot 和预索引/缓存；不扫描 AddOn，不创建 frame，不注册常驻事件，不执行动作。
- resolver 超时或抛错时丢弃该 Command 在本 generation 的全部结果，保留其查询 `dirty` 标记，不发布部分结果。连续失败使 Extension 被标记为 `slow`，并按 Host 定义的有界退避窗口降频；退避有最小/最大延迟和最大尝试次数，成功后清除 dirty 并恢复健康计数。重试只能由 QueryOrchestrator/Scheduler 在 Palette 可见、当前 generation/context 仍有效且 Extension 有效启用时调度；第三方不能自建重试计时器。Palette 隐藏、Extension disable/unregister/retiring 时取消已排队重试，不在后台继续退避调度。
- deferred 工作按固定时间片执行，Palette 隐藏后立即取消。
- resolver 没有协作式取消时使用 generation 丢弃旧结果。
- 需要取消的一次性延迟和周期任务分别使用 `C_Timer.NewTimer`、`C_Timer.NewTicker`，保存返回的 callback object，并在查询替换、Palette 关闭、Panel Unmount、Extension disable/unregister 和 Host detach 时调用 `:Cancel()` 后清除引用。
- `C_Timer.After` 不返回可取消句柄，只允许用于无需持有业务对象的极短 next-turn flush。回调必须捕获数值 generation/session token，开头校验 token、Palette 可见性和所属 Extension 状态；过期立即 return。需要可靠取消、可能跨越战斗切换或会持有 frame/payload 的工作不得使用 `After`。
- Scheduler 统一登记 timer/ticker 句柄；不得创建无法从所有退出路径找到并取消的匿名后台任务。

timer 契约依据同一 wowdoc 快照的 `Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua`：`After`（11-20）没有返回项，`NewTicker`（22-36）和 `NewTimer`（39-52）返回 callback object。

## 11. Presentation 与 UI 所有权

### 11.1 `row` 与统一结果卡片

Lychee 绘制统一结果卡片，至少包含 icon、category badge、localized title、description/subtext 和有限 action slots。Command 的 `row` 结果与 SearchRecord 使用同一 renderer；Enter 或点击后生成并路由 Intent。

### 11.2 `dynamic-list`

第三方返回结构化 item：

```lua
{
    id = "item-42",
    text = "主文本",
    subtext = "副文本",
    icon = texture,
    enabled = true,
    payload = opaque,
    interaction = { -- optional, declared data rather than callbacks
        primaryActionID = "open-detail",
        actions = {
            { id = "open-detail", title = "查看详情", kind = "intent" },
            { id = "cast", title = "施放", kind = "secure-spell", spellID = 12345 },
        },
        drag = { type = "spell", spellID = 12345 },
    },
}
```

Lychee 拥有行 frame、对象池、滚动、键盘上下、鼠标、选中态和空状态。`SearchSession` 校验结果 generation，`ResultActionExecutor` 校验行/source/Extension token；item payload 只传给所属 Command 的 `itemIntent`。

空输入显示 Host-owned HomeView（最近、固定、按 category 分组和第三方入口）；有输入时切换 SearchView。两种状态共用 Palette session/generation、对象池和动作校验，不允许 Source 或 Command 创建第二个根窗口。

Palette 使用约 `720x500` UI 单位的固定三段工作台：Header 承载品牌和无模板原生 EditBox，Content 在 HomeView、SearchView、无结果状态、ViewHost 之间保持单一可见状态，Footer 只显示当前模式或结果数。窗口在每次显示时依据 `UIParent` 可用尺寸做有界整体缩放，不注册常驻缩放轮询。`Theme.lua` 集中拥有石墨背景、暖白文字、荔枝红主强调、低饱和类别色、间距和固定尺寸 token；Input、Home tile、结果行和动作按钮只消费 token，不各自定义另一套视觉系统。

Host 基础视觉原语集中在 `UI/Components.lua`，按组件库方式返回带 `frame` 的实例对象，而不是把子控件散落在 Palette：`CreateBand`、`CreateSurface`、`CreateBrand`、`CreateButton`、`CreateStatus` 和 `CreateEmptyState` 分别拥有自己的视觉状态、资源引用和幂等 setter。组件在创建期建立固定的 frame/texture/font 结构，后续只通过 `SetText`、`SetState`、`SetTexture`、`SetColor` 或 `SetShown` 做 change guard；组件不注册常驻 `OnUpdate`、不创建业务 timer，也不触碰搜索、焦点和 Panel 生命周期。Palette 只负责组合这些实例、连接点击回调和切换可见状态；新增 Host 视觉组件应扩展该目录，而不是把创建细节重新写回 `Palette:Create()`。

HomeView 的最近、已固定、分类和第三方来源是四个真实分组，空分组显示不可点击的空状态而不伪造实体。分类和来源入口提交结构化 `categoryID` / `sourceID` filter，由 SearchSession 推进 generation、QueryOrchestrator 分配索引预算、StaticIndex 使用分类桶或来源 entry keys 返回实体；不得把显示标题伪装成普通文本查询。Home 标题和常用 Tile 在 Palette 创建期预建，超过预分配容量时只允许在打开、recent/pinned 变化或 Source 生命周期变化路径受控扩容，输入路径不得创建 Frame 或重扫完整索引。

SearchView 固定复用六个高信息密度结果行；每行保持类别 badge、图标、标题、受限描述、来源、命中证据、最多四个动作槽和可选拖拽区。键盘选中与鼠标 hover 是独立状态，长文本不改变行高或动作区宽度。新文本 generation 必须先清除上一代已接纳结果再进入 debounce；Panel 激活时异步结果只能更新缓存，不能让 SearchView 或空状态重新可见。结果刷新按 stable ID 和逐字段缓存做差量 setter，freshness token 始终更新，但未变化的文字、颜色、纹理、动作和显示状态不重复调用原生 setter。清空、较短结果、Source 失效或 Panel 切换必须清除旧行、旧动作、旧拖拽绑定和旧视觉状态。

`resolve` 由 QueryOrchestrator 调用，不由 ResultList 直接调用。返回 item 必须有 Extension 内稳定 ID；`itemIntent` 只把选中 item 转换为结构化 Intent，实际执行仍经过 IntentRouter。

#### 结果动作与拖拽

`interaction` 是动态 item 的可选、有界声明，不是给结果行挂任意 Lua 回调的入口。`actions` 最多四项，ID 必须在同一 item 内稳定且唯一；Host 只接受 `intent`、同 Extension 的 `open-panel`、自行解释的 `secure-spell` 和 `drag-spell` 四种 kind。描述符不得包含 function、Frame、宏文本、任意 secure attribute 或无界数据。

- 只有一个普通主动作时，行左键和 Enter 都执行它；有多个动作时，二者仍只执行 `primaryActionID`，其余动作由 Host 在稳定的行内动作槽显示明确按钮。Host 不根据标题、图标或 Provider 名称猜测动作。
- `intent` 动作只由所属 Command 的 `itemIntent(item, actionID, context)` 生成结构化 Intent，再交 IntentRouter；跨 Extension 的 Handler、PanelFactory 或 transition 一律拒绝。普通动作可执行操作，也可在成功后返回同 Extension 的声明式 `custom-panel` transition。
- `secure-spell` 只能声明有限的 numeric `spellID`。Enter、IntentRouter、普通 Lua 回调和 `Button:Click()` 都不能触发它；用户必须真实左键点击 Host 已在脱战配置的 `SecureActionButtonTemplate` 行/按钮。若安全动作被设为 primary，Enter 返回 `ACTION_REQUIRES_HARDWARE_CLICK`。
- `drag` 当前只支持 `{ type = "spell", spellID = number }`。Host 仅在结果可见、当前 generation、Extension 已启用、脱战且法术已知、可用、非被动时显示专用拖拽区域；真实 `OnDragStart` 调用 `C_Spell.PickupSpell(spellID)`，由标准动作条接收光标内容。点击行、Enter、resolver 和 `itemIntent` 绝不触发 PickupSpell。
- 无效描述符、不支持类型、不可用法术、过期行或战斗状态分别返回稳定的 `INVALID_INTERACTION`、`DRAG_UNSUPPORTED`、`ACTION_UNAVAILABLE`、`STALE_GENERATION` 或 `COMBAT_LOCKED`，且不改变鼠标光标。

动作、拖拽和安全按钮都绑定 `extensionID + itemID + actionID + Palette session/context token + generation`。所有入口由 `ResultActionExecutor` 按固定顺序校验当前会话、source revision/generation、Extension 状态、战斗和 availability，再委托 IntentRouter、ViewHost、spell drag adapter 或 SecureActionBroker。输入变化、Palette 关闭、进入战斗、Extension disable、retiring 或 removed 后，Host 立即使对应绑定失效；旧行、旧回调和迟到 resolver 结果不能作用于新一轮结果。

主动内容搜索的端到端示例：

```text
输入大秘境小怪名称
  -> mythic-creature dynamic-list Command 的 ambient match 通过预筛选
  -> resolver 通过 CapabilityBroker 查询 creature Provider 的私有名称索引
  -> Host 统一绘制结构化怪物 item
  -> itemIntent 生成 open-creature-detail Intent
  -> IntentRouter 调用同 Extension Handler
  -> Handler 返回 custom-panel transition
  -> Host 校验同 Extension PanelFactory 和 state
  -> ViewHost 挂载怪物详情 Panel
```

任何一步不可用、超预算、过期或校验失败都只终止该 Command 的结果/转换，不允许 resolver 或 Provider 跳过 IntentRouter 直接打开 Panel。

### 11.3 `custom-panel`

Lychee 创建 ViewHost，并向 Extension 提供受限 `PanelContext`：

```lua
{
    contentFrame = hostOwnedFrame,
    width = number,
    height = number,
    context = readOnlyContextSnapshot,
    close = hostClose,
    invalidate = requestUpdate,
    requestFocus = requestDescendantFocus,
    dispatchIntent = routeStructuredIntent,
}
```

Panel 生命周期：

```text
create once -> (Mount(context) -> Update(state)* -> Unmount(reason))* -> Dispose
```

Lychee 始终拥有 Palette 根 frame、焦点、Esc、尺寸、层级、关闭和清理。第三方只在 `contentFrame` 下创建子 frame。Palette 隐藏、Extension 禁用、Panel 异常和 `/reload` 前清理都经过 `Unmount`；Extension 注销时在最后一次 Unmount 后调用可选 `Dispose`。

PanelFactory `create`、`Mount`、`Update`、`Unmount` 或 `Dispose` 任一回调抛错时，ViewHost 必须先标记该 Panel 不可用，再以独立错误边界尽力执行一次 `Unmount("panel-error")`。无论清理回调是否再次失败，Host 都必须隐藏该 Extension 的 content frame，清空其中的 Host 状态、焦点和大对象引用，取消并注销通过 PanelContext/runtime 登记的 timer、ticker、事件、deferred 和其他 Host 托管驱动/任务，释放 `busy` 状态，然后显示 Host 统一 `PANEL_ERROR` 行或返回结果列表。该隔离只处理出错 Extension 的 Panel 资源，不卸载其他 Extension、不清空其他结果，也不停止 PaletteController。

PanelFactory 由 Extension handle 的 `RegisterPanelFactory` 注册，Command 只引用其 ID。ViewHost 通过错误边界调用 `create`、`Mount`、`Update`、`Unmount` 和 `Dispose`；PanelContext 只暴露本文列出的托管能力，Panel 不直接访问 CommandCatalog、CapabilityBroker 或 IntentHandler。

WoW AddOn 共享同一 Lua 环境，ViewHost 是生命周期和所有权边界，不是强安全沙箱。Host 自动取消通过 PanelContext/runtime 创建的托管任务；第三方直接注册的 Blizzard 事件、`C_Timer` 和 ticker 必须由其 `Unmount`/`Dispose` 清理，Host 无法枚举并撤销这些资源。

WoW Frame 没有供 AddOn 普遍调用的销毁操作。这里的 `Dispose` 表示停止脚本/事件/timer/ticker、隐藏 frame、清空大对象和回调引用，并将可复用对象交回池；它不承诺销毁底层 Frame。`SetParent(nil)` 也不等于销毁，不作为释放证明。Panel 重挂载优先复用既有子 frame，避免每次打开无界创建对象。

### 11.4 快捷键与焦点

Lychee 只注册一个全局 Binding。`Bindings.xml` 的完整契约是：

```xml
<Bindings>
    <Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">
        Lychee_Toggle();
    </Binding>
</Bindings>
```

加载期按 locale 设置下列 WoW 约定的全局字符串；缺少 locale 时回退到默认文案：

```lua
_G.BINDING_HEADER_LYCHEE = "Lychee"
_G.BINDING_NAME_TOGGLELYCHEE = "打开/关闭 Lychee"
```

`Lychee_Toggle` 是 Bindings.xml 唯一调用的稳定全局函数，初始化时定义一次并只委托给私有 `PaletteController`。第三方、Command 和 Panel 都不能替换该函数、增加 Lychee 级 Binding 或直接持有 Controller。

默认唤起键是 `Alt + Space`（`ALT-SPACE`），但只能在首次初始化时做一次无冲突尝试：当 `GetBindingKey("TOGGLELYCHEE")` 没有任何返回值且 `GetBindingAction("ALT-SPACE")` 为空，并且当前不在战斗，才调用 `SetBinding("ALT-SPACE", "TOGGLELYCHEE")` 和 `SaveBindings(GetCurrentBindingSet())`。`LycheeDB.defaultBindingAttempted` 必须记录这次尝试，防止每次登录重复写入。若该 action 已绑定或此组合键属于其他 action，Lychee 不覆盖、不选择替代键，并在设置页提示玩家自行设置。玩家后来在 WoW 按键设置中修改或解绑后，Lychee 永不自动回写；不得使用 `SetOverrideBinding`，也不得在战斗中或每次登录写 Binding。

战斗策略是强制契约：

```lua
_G.Lychee_Toggle = function()
    if InCombatLockdown() then
        return
    end
    PaletteController:Toggle()
end
```

- `InCombatLockdown()` 为 true 时必须静默 return；不得打开、关闭或重排 Palette，不移动焦点，不创建 timer，也不启动、取消或递增查询。Binding 仍显示在按键设置中，但战斗期间调用无效果。
- Core 事件 frame 注册 `PLAYER_REGEN_DISABLED` 和 `PLAYER_REGEN_ENABLED`。进入战斗事件到达且 Palette 已打开时，立即调用统一 `Close("combat")`：递增 generation、取消所有 timer/ticker/deferred token、Unmount 当前 Panel、回池结果行、隐藏 Palette 并清理输入状态。该路径不经过 toggle 的战斗短路。
- 战斗关闭路径只清除 Lychee 自己的输入焦点，不尝试把焦点设置到外部 frame。`PLAYER_REGEN_ENABLED` 后不自动重开 Palette；无需重绑按键，`Lychee_Toggle` 因锁定解除而自动恢复，同时 Broker 可处理脱战后的 dirty secure 配置。
- Esc 优先关闭 custom-panel，再走同一个 Palette `Close(reason)`；Enter 选择当前可用项，上下键改变选择，Tab 行为由 Palette 状态机统一定义。
- 第三方 Panel 只注册可见期间的 frame-local 输入，不注册 Lychee 命名空间下的 Binding。

焦点恢复只能是 best-effort。打开前仅保存当前调用方可访问的键盘焦点；关闭时先 `ClearFocus()` 自有输入框，再确认关闭 session 未变化、当前不在战斗、旧对象仍可访问且仍适合接收键盘输入，最后以局部 `pcall` 尝试恢复。任一检查失败就保持无焦点，不报错、不重试、不保存该对象到 SavedVariables。Lychee 不承诺恢复被其他 UI 在 Palette 打开期间主动改变的焦点。

本节 API 依据同一 wowdoc 快照：`RestrictedActionsDocumentation.lua` 的 `InCombatLockdown`（45-52），`Blizzard_SharedXML/BindingUtil.lua` 中按 `BINDING_NAME_<binding>` 读取本地化名称的实现（142-145），以及 `Blizzard_Commentator/Bindings.xml` 使用 `category="BINDING_HEADER_COMMENTATOR"` 的官方分类形式。

## 12. ContextStore

ContextStore 把 Blizzard 事件转换为只读、版本化切片，例如：

```text
player, target, combat, group, instance, specialization,
bags, equipment, spellbook, addons, ui-state
```

每个切片有独立 version。事件只更新受影响切片，并向 Catalog/Provider 发布精确 invalidation key。Provider 申报依赖切片，Host 只传需要的数据。

高频事件由一个 Core handler 接收和聚合。第三方通过 SDK 读取快照，不自行建立完整镜像。

ContextStore 在构造或更新切片时执行第 5.4 节的递归访问检查。未经检查的 Blizzard API 返回值不进入共享快照；包含 secret/inaccessible key、value 或不可索引 table 的字段在边界处拒绝，Provider 只能看到缺失/不可用状态，不能看到原值或其字符串表示。

## 13. 内置功能

内置功能使用和第三方相同的注册 facade：

```text
Builtin module
  -> RegisterExtension
  -> RegisterSearchSource
  -> Commit
  -> same SearchIndex/UI
```

内部模块可以使用额外 Host service，例如直接读取缓存后的 Context slice；它们不建立第二套索引、搜索或执行通道。建议的后续内置域包括 Blizzard 面板、法术、物品、宏、设置、插件、最近使用和收藏。

内置的技能、任务、怪物技能、副本 CD 等稳定实体与第三方使用同一套 SearchSource/SearchRecord 合同。只有固定命令、运行时组合查询或可复用能力才额外注册 Command/CapabilityProvider；数据来源不改变搜索对象和 UI 所有权。

内置 Extension 按同一协议组织，避免为任一业务另建搜索或 UI 通道。当前运行时只交付 `PlayerSpells`；以下 DungeonGuide、DungeonAlias 和副本 CD 是待真实数据源或稳定适配器就绪后再注册的规划能力，生产包不得用 fixture 占位：

1. 规划中的 `DungeonGuideProvider` 为大秘境小怪名与小怪技能建立怪物记录的反向索引；普通动作打开 Lychee 详情，并可提供打开外部指南的动作。
2. `PlayerSpells` Extension 的 `PlayerSpellProvider` 只建立一份当前角色已知、有效法术快照，并通过一个 SearchSource 发布。`PlayerSpellAliases.lua` 只提供 Locale 别名投影：既包括“复仇之怒”对应“翅膀”等技能俗称，也包括已知副本传送法术对应“红玉”等副本简称。结果支持专用区域拖到动作条和真实点击安全施放；当前没有详情 Panel，不注册 Command、CapabilityProvider 或 IntentHandler。
3. 规划中的 `DungeonAliasProvider` 把 Boss 名、赛季简称（如 `M1`）和版本别名映射为攻略实体；结果动作打开同 Extension 的详情 Panel。
4. 副本传送搜索是第 2 项 `PlayerSpells` 的别名场景，不新增额外 Provider、独立目录或第二份法术索引；命中后仍返回同一个 canonical spell item，并沿用拖拽和真实点击安全施放合同。

`PlayerSpellProvider` 的法术源不是固定技能表：Retail 运行时在登录、`SPELLS_CHANGED`、`LEARNED_SPELL_IN_SKILL_LINE`、`PLAYER_SPECIALIZATION_CHANGED` 和 `TRAIT_CONFIG_UPDATED` 事件后，使用 `C_SpellBook.GetNumSpellBookSkillLines()`、`GetSpellBookSkillLineInfo()` 与 `GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)` 重建当前角色的已知非被动、非 off-spec 法术快照。别名定义只作为 canonical spell ID 的投影；输入查询只读取快照和倒排别名索引。离线测试必须在 `tests/` 中注入 SpellBook fixture，生产 Provider 不包含固定技能回退。

PlayerSpells 先完成 Extension `Commit()`，再保存 `handle:GetSearchSource("records")` 返回的窄 source handle；后续刷新只调用该 handle 的 `CommitSnapshot`，不访问 StaticIndex、不手拼 source ID、不维护私有 source generation。停用时注销事件并保留 handle 供重新启用，重新启用后重建实时快照；注销时停止待处理刷新并释放事件 frame 与 source handle。SpellBook 短暂读取失败保留上一份已提交快照。

外部指南是可选 adapter，不是 Host 特权路径。以 MRT 为例，未来的 `DungeonGuideProvider` 只能调用目标 AddOn 的稳定公开接口；目标未加载、未接入或不支持该实体时，该动作返回 `ACTION_UNAVAILABLE`，不操作其内部 frame，不影响 Lychee 详情动作或其他结果。

内置复杂面板同样注册 PanelFactory，并挂载到同一个 ViewHost，遵循 `Mount/Update/Unmount/Dispose`。内部 PanelContext 可以增加明确列出的 Host service，例如 ContextStore 只读查询、配置 facade、CapabilityBroker 和诊断接口；这些服务仍通过窄接口提供。内置面板不直接接管 Palette 根 frame，也不绕过焦点、Esc、关闭、IntentRouter 和清理状态机。

Builtin 按业务域垂直拆分，每个域按需维护自己的 SearchSource、Command、Provider、Intent、Panel、索引和数据适配器，不要求每个域注册全部角色；域之间只通过 Core 的窄接口通信。新增技能、任务、怪物技能、副本 CD 或新的第三方适配器时，只新增一个 Extension/业务目录并提交注册，不修改 Palette、QueryOrchestrator、ResultList 或 IntentRouter 的核心协议。域可以独立启停、报错、超时和注销，不能污染其他域。

Palette、输入框、结果列表和 ViewHost 本身属于 Host 基础 UI，不作为 Command 面板注册；用户实际搜索进入的设置、诊断、插件管理等功能页面则作为 Builtin Extension 的 Command/PanelFactory 接入。

## 14. 错误、兼容与诊断

稳定错误码至少覆盖：

```text
INVALID_SCHEMA, DUPLICATE_ID, UNSUPPORTED_API, INCOMPATIBLE_HOST,
EXTENSION_DISABLED, PROVIDER_TIMEOUT, PROVIDER_ERROR, STALE_GENERATION,
COMMAND_NOT_FOUND, INTENT_INVALID, COMBAT_LOCKED,
INVALID_SECURE_DESCRIPTOR, INVALID_INTERACTION, DRAG_UNSUPPORTED,
ACTION_UNAVAILABLE, ACTION_REQUIRES_HARDWARE_CLICK, INACCESSIBLE_VALUE,
PANEL_ERROR, CALLBACK_ERROR
```

SDK 暴露整数 `API_VERSION`（major）和 `API_REVISION`。新增可选字段或方法提升 revision；改变字段语义、类型或删除字段提升 major。Extension 声明精确 major 和最低 revision，SDK 与 Host 分别在注册和 attach 阶段决定兼容结果；兼容分支不进入搜索热路径。

诊断记录包括 Extension 状态、最后错误、查询次数、平均/峰值耗时、过期 generation 数和 Panel 清理结果。默认模式只维护计数器；开发者模式使用固定容量 ring buffer。

## 15. 性能契约

- 隐藏 Palette、空 registry 和已完成 Intent 的 active ticker 数为零。
- AddOn 枚举、schema 校验和索引构建不发生在每次按键。
- Lychee ExtensionRegistry 变更由注册/注销事件增量推送给 Host，不通过轮询发现。
- 静态 Catalog 只在注册、注销或显式 invalidation 时重建。
- Provider/模块在注册、数据更新或事件失效时增量维护私有索引；ambient 按键路径不全表扫描。
- ambient 只在显式声明、用户启用、长度/availability 命中且位于本 generation 预算内时调度。
- dynamic resolver 有全局调用数、单 Command 结果数、调用深度和协作式耗时上限。
- ResultRow 和常用 Panel 容器池化，按 stable ID 增量渲染。
- 交互行按 `itemID + actionID` 复用有限动作槽、专用拖拽区域和 Host 安全按钮；绑定或解绑只发生在结果 diff/脱战 dirty flush，不在鼠标移动、每帧或 resolver 内创建 frame/闭包。
- 热路径避免临时 frame、闭包、长字符串和可规避的 table 分配。
- `SetPoint`、`SetSize`、字体、纹理、颜色和 frame level 使用 change guard。
- 事件驱动优先；必须轮询的任务有固定间隔、对象上限和停止条件。
- timer/ticker 默认使用可取消句柄，退出路径执行 `Cancel()`；`C_Timer.After` 只用于带 generation/session guard 的短 flush。
- 第三方错误边界使用小范围 `xpcall`，不包裹整个 Host tick。
- Palette 关闭后 dynamic queue、Panel、timer、Palette-owned 事件和 frame 引用都归零或回池；Core 生命周期事件 frame 可以继续等待战斗/登录事件，但没有 `OnUpdate`。
- 战斗中 toggle 路径在任何 UI、焦点或查询工作前返回；`PLAYER_REGEN_DISABLED` 只执行一次统一关闭，不留下后台任务。

后续实现的初始预算：

| 项目 | 预算 |
| --- | --- |
| 静态候选 | 最多 200 |
| 展示结果 | 最多 20 |
| 单个 dynamic resolver 结果 | 最多 20 |
| 单个 generation 的 ambient resolver 调用 | 最多 4 个 Command |
| 输入 debounce | 默认 0.05 秒 |
| deferred 时间片 | 每帧最多 2 ms，且仅 Palette 可见时 |
| 诊断 ring buffer | 64 条 |

预算是初始实现约束，后续只能依据实际 profile 调整。

## 16. SavedVariables 与所有权

- `LycheeDB` 只由 Host 拥有。
- SDK 不声明 SavedVariables。
- 第三方自己的配置继续由第三方 AddOn 管理。
- Lychee 只保存 Extension 启停、默认 Provider、favorite/recent 和 UI 偏好。
- recent/favorite 只保存 stable ID，不保存完整 Command 快照。
- 迁移按版本执行且幂等，发生在 Extension enable 之前。

## 17. 参考项目取舍

### 17.1 ZTools

借鉴：`mainPush` 中“Command 先声明参与范围，命中后动态查询数据，Host 统一绘制结果”的分层，以及 Command Catalog、动态结果 generation、统一列表与插件自定义 view 的双模式、稳定插件 ID 和按需加载思想。

不采用：插件无条件向 UI 推送结果的接口。WoW 实现由 QueryOrchestrator 在预算内同步/协作式调度，Provider 查询预索引，Host 验证 generation/context 后统一发布。

舍弃：Electron IPC、多进程、运行时安装器、桌面窗口管理和网络插件市场。WoW 内通信使用同一 Lua 环境的 Lychee ExtensionRegistry。

### 17.2 EllesmereUI

参考提交 `1b37158d7533deb2d5b0a74292438a8ea2191588`：

- 直接事件和轻量生命周期，不引入 Ace3 framework。
- 订阅为零时隐藏驱动。
- 密集数组 + ID 索引，swap-remove 删除。
- 原生 AnimationGroup 优先于 Lua 每帧补间。
- 高频 setter 使用缓存 key 和 change guard。
- 重刷新按成本分层，延迟 GC 和批量重建。

## 18. 品牌媒体约束

本 change 只记录 Logo 契约，不把媒体复制到运行时目录。设计输入保存在本机 `analyze/inputs/lychee-logo-source.png`，不进入 Git：

| 属性 | 已验证值 |
| --- | --- |
| 尺寸 | 500x500 |
| 像素格式 | `Format32bppArgb` |
| 四角 alpha | `0, 0, 0, 0` |
| SHA-256 | `96887564230FA250D2AF4B151DEC219E9A166F245771C4414135F498E9E4E7E3` |

后续媒体实现保持 1:1 比例、透明背景、完整叶片和荔枝主体，不增加黑色或不透明方形底。允许生成尺寸优化副本，但必须能追溯到上述源文件并保留 alpha。Logo 用于 AddOn 识别和 Palette 品牌位置；TOC 或媒体路径改变后通过重启客户端或 `/reload` 验证实际纹理加载。

## 19. 后续实现顺序

1. Lychee `PublicAPI`：版本、schema、draft/Commit 事务、ready/pending registry 和句柄。
2. Host 生命周期、ExtensionRegistry、错误边界和诊断。
3. CapabilityBroker、ContextStore、CommandCatalog 和 IntentRouter。
4. `TOGGLELYCHEE`、Palette、Input、ResultList 和焦点状态机。
5. normalization、静态索引、Ranker、generation 和 dynamic 调度。
6. ViewHost 与 custom-panel 生命周期。
7. Secure Descriptor 与战斗策略。
8. 首批内置 Extension。
9. SDK fixture、性能采样和正式服验证。

每一步都应保持 AddOn 可加载，并且不引入第二套注册、搜索、快捷键或执行模型。

## 20. 验证矩阵

| 场景 | 关键验证 |
| --- | --- |
| 第三方先加载 | 集成代码等待 Lychee ready 后提交，Extension 进入 Lychee registry |
| Lychee 先加载 | 第三方 Commit 后 Extension 立即注册 |
| Provider 单独注册 | 不进入搜索；稳定实体由同 Extension 的 SearchSource 收录，只有运行时组合查询才额外提交 ambient `dynamic-list` Command |
| Extension 句柄 | `SetEnabled` 只增量影响本 Extension 的 owner-enabled 位，重复设置和 `Unregister()` 幂等 |
| 同 ID Extension 重载 | 旧句柄 retiring 后停调度、失效 generation/transition、清理 Panel/索引/驱动；屏障完成才接受新句柄 |
| SDK 缺席 | 第三方只跳过 Lychee 接入，自身功能继续运行 |
| 草稿/提交失败 | 未 Commit 草稿不可见，任一失败均无部分注册 |
| 重复/非法 ID | 原子失败，不覆盖已有 Extension |
| installed/loading/loaded/sdk-registered | 验证 `loadedOrLoading, loaded` 对应未加载、加载中、已加载三个业务状态，不由 TOC 元数据推断接入 |
| LoD AddOn | 关键词候选、显式加载、加载状态与注册状态分别展示 |
| 快速连续输入 | 旧 generation 结果被丢弃 |
| 直接实体名 | SearchSource 中的稳定实体不输入 Command 名即可得到结构化 item；动态组合项可由 ambient resolver 产生 |
| ambient 短/超长输入 | 不满足 `minLength`/`maxLength` 时 resolver 调用数为零 |
| 多个 ambient Command | 按稳定优先级和全局调用预算调度，合并排序可复现 |
| Provider 不可用 | 只显示该 Command 的稳定 unavailable/空状态，其他结果继续工作 |
| resolver 超时/连续错误 | 本轮结果丢弃且保留 dirty，Host 有界退避并标记 slow；隐藏、disable、unregister 后无重试 |
| 大秘境怪物详情 | 怪物名命中 -> Provider 索引 -> Host item -> Intent -> 同 Extension transition -> ViewHost Panel |
| 详情转换失败 | 跨 Extension PanelFactory、过期 context/session 或非法 state 均不挂载 Panel |
| Intent 错误 | 当前动作终止，Host 统一错误行可见，`busy` 必定释放且不写 recent |
| dynamic-list | 键盘、鼠标、滚动、空状态和 item Intent |
| 单一/多个普通动作 | 左键与 Enter 均只执行主动作，其余动作显示为稳定的行内按钮 |
| 法术拖拽 | 仅专用区域真实 `OnDragStart` 调用 `C_Spell.PickupSpell`；点击、Enter 与 Lua 调用不改变光标 |
| 安全法术动作 | 脱战预配置；真实左键可施放，Enter/scripted click 返回或保持 `ACTION_REQUIRES_HARDWARE_CLICK` |
| 动作生命周期 | 输入替换、关闭、进战、disable、retiring/removed 后旧 session/context/generation 的动作、拖拽和安全按钮均失效 |
| custom-panel | 实例复用、Mount/Update/Unmount/Dispose、Esc、异常后 content frame 隐藏/清空、托管驱动注销，其他 Extension 继续工作 |
| MRT/指南 adapter | 仅经稳定公开 API 打开支持的实体；目标不可用时返回 `ACTION_UNAVAILABLE`，不访问内部 frame |
| 内置实体场景 | 小怪/小怪技能、角色技能、Boss/M1 别名和副本传送别名均经 SearchSource -> SearchRecord -> action/Intent -> Host UI 链路；只有真实动态组合查询额外使用 ambient Command/CapabilityProvider |
| 第三方报错 | 其他 Extension 和 Palette 继续工作 |
| secret/inaccessible 数据 | 根、key、value 和嵌套 table 均在索引/Intent/日志/SavedVariables 前拒绝 |
| timer 取消 | query 替换、关闭、Unmount、disable 和 detach 后句柄已 Cancel，After 旧 generation 无效果 |
| 战斗状态 | toggle 静默无效果；已开 Palette 在 `PLAYER_REGEN_DISABLED` 统一关闭；脱战后快捷键自动恢复但不自动重开 |
| 默认 Binding | 首次且无冲突时保存 `ALT-SPACE -> TOGGLELYCHEE`；已有 action/key、战斗中或玩家后续改键时均不覆盖/回写 |
| secure action | `SecureActionButtonTemplate` 脱战创建/预配置，只有真实点击可执行，scripted click 不作为硬件输入 |
| Palette 隐藏 | ticker、timer、catalog/ambient 动态队列和 active row 归零，迟到结果无效 |
| 1000+ Command | 候选上限、排序稳定性和帧时间 |

## 21. 设计验收清单

- [ ] 顶层公开模型为 Extension/Command/SearchSource/SearchRecord/CapabilityProvider/IntentHandler/PanelFactory。
- [ ] Lychee ExtensionRegistry 是接入唯一事实源，草稿不参与查询。
- [ ] CommandCatalog 私有索引与 SearchRecord 实体索引互不污染，并由 QueryOrchestrator 合并为单一结果；Provider 只能通过 SearchSource 或 `catalog/ambient` resolver 间接提供数据。
- [ ] `ambient` 只能用于带明确长度边界的 `dynamic-list`，并经过单一 debounce/generation/context 和统一预算调度。
- [ ] AddOn 枚举只用于诊断、兼容和 LoD。
- [ ] 内置和第三方走同一 Catalog、Broker、Router 和 UI。
- [ ] dynamic-list 与 custom-panel 的所有权清晰。
- [ ] dynamic item 的动作、拖拽与安全施放均为 Host 解释的有界声明，且受 session/context/generation 生命周期保护。
- [ ] dynamic item 先转换为 Intent，详情只能经同 Extension 的声明式 transition 进入 ViewHost。
- [ ] Extension 重载必须等待旧句柄 retiring 的查询、Panel、索引和驱动清理屏障，新句柄不能提前可见。
- [ ] resolver 失败只由 Host 在有界退避窗口重试，Palette 隐藏或 Extension 退出后不留后台驱动。
- [ ] Intent 与 Panel 错误都释放 `busy`，并由 Host 统一呈现/清场，不影响其他 Extension。
- [ ] `TOGGLELYCHEE` 是唯一全局 Binding。
- [ ] `ALT-SPACE` 只在首次、脱战、action 未绑定且按键空闲时设为默认值，之后不覆盖玩家设置。
- [ ] 战斗中 toggle 不改变 UI、焦点或查询，进入战斗会关闭已打开的 Palette。
- [ ] UI 不直接调用第三方任意函数。
- [ ] 受保护动作只接受声明式 Descriptor。
- [ ] secret/inaccessible 数据不会进入索引、Intent、日志、缓存或 SavedVariables。
- [ ] timer/ticker 可取消，所有 `After` 回调都有 generation/session guard。
- [ ] generation、排序和 context version 行为确定。
- [ ] Palette 隐藏时后台工作归零。
- [ ] SDK 公共字段和示例与 `docs/SDK.md` 一致。
