# Lychee 架构与实现契约

> 状态：design baseline v0.2
>
> 这是一份面向实现和代码评审的契约，不是产品介绍。凡是本文没有标记为
> “实现可选”的内容，均视为必须遵守的架构决定。实现者不得自行增加第二套
> Provider、搜索、Intent 或快捷键模型；需要改变契约时必须先更新本文和版本。

## 0. 阅读规则与不可变决定

### 0.1 名词

| 名词 | 定义 |
| --- | --- |
| Host | `Lychee` 主插件，拥有 UI、索引、上下文和执行器 |
| SDK | `LycheeSDK` 独立 AddOn，第三方只依赖它 |
| Provider | 能力提供者，内部和外部使用同一个注册协议 |
| Entry | 可被搜索和展示的一条能力描述 |
| Intent | 用户选择 Entry 后的结构化执行请求 |
| Context | 由 Host 维护的只读游戏状态快照 |
| Generation | 一次输入快照的单调递增查询代次 |

### 0.2 必须保持的单一事实源

1. **只有一个全局 Binding：** `TOGGLELYCHEE`。所有调用最终进入
   `Lychee:TogglePalette()`；第三方不能注册 Lychee 命名空间下的 Binding。
2. **只有一个 ProviderRegistry：** SDK 负责收集和校验，Host 负责启停和消费。
3. **只有一个 QueryOrchestrator 和 Ranker：** UI、内置模块、第三方都不能绕过它。
4. **只有一个 IntentRouter：** UI 不能直接调用 Provider 回调或任意 Lua 函数。
5. **只有一个 ContextStore：** Provider 读取快照，不自行监听并缓存完整游戏状态。
6. **SDK 与 Host 是两个可独立加载的 AddOn：** SDK 不引用 Host UI；Host 缺失时 SDK
   仍能安全接收注册并提供状态查询。

### 0.3 变更规则

- 新增字段必须是可选字段，或提升 `apiVersion` 并提供迁移/降级路径。
- 修改字段语义、排序权重、错误码或执行策略属于契约变更，必须更新本文件的版本号。
- 任何“临时兼容”必须落在 `Adapters/` 或 SDK compatibility 层，不能散落在搜索和 UI 热路径。
- 代码提交前必须通过本文第 18 节的静态检查、运行时验证和 Git/正式服同步流程。

## 1. Product Contract

Lychee is an in-game command palette for World of Warcraft. The user presses
one WoW binding, enters a natural-language or keyword query, selects a result,
and executes a standard Intent.

The product has exactly one global binding:

```xml
<Bindings>
    <Binding name="TOGGLELYCHEE" header="LYCHEE" category="ADDONS">
        Lychee:TogglePalette();
    </Binding>
</Bindings>
```

Third-party providers do not register global bindings. Provider actions are
discovered and launched from the Lychee palette. Palette-local navigation is
handled by the input/result frames while the palette is visible.

### 1.1 Goals

- Provide one predictable entry point for Blizzard, Lychee and third-party addon capabilities.
- Keep the public integration contract smaller and more stable than the host implementation.
- Make ordinary UI actions and protected combat actions explicit and separate.
- Support deterministic Chinese/English/pinyin search without a runtime network dependency.
- Keep the hidden/idle cost at zero Lua work per frame.
- Allow the host to survive a broken or slow third-party provider.

### 1.2 Non-goals

- No operating-system launcher or out-of-game hotkey.
- No dynamic code download or runtime package installation.
- No provider-owned Lychee UI.
- No provider-specific global hotkey namespace.
- No runtime machine-learning model requirement.
- No AceAddon/AceEvent/AceDB/AceConfig/AceGUI dependency in the host or SDK.

## 2. Repository and Runtime Layout

The repository is a source/package workspace. The two directories under
`package/` are separate WoW AddOns and are copied as siblings into the live
`AddOns` directory.

```text
Lychee/
├─ package/
│  ├─ Lychee/
│  │  ├─ Lychee.toc
│  │  ├─ Bindings.xml
│  │  ├─ Bootstrap.lua
│  │  ├─ Core/
│  │  │  ├─ Host.lua
│  │  │  ├─ Lifecycle.lua
│  │  │  ├─ ProviderRegistry.lua
│  │  │  ├─ ContextStore.lua
│  │  │  ├─ Scheduler.lua
│  │  │  ├─ IntentRouter.lua
│  │  │  ├─ ErrorBoundary.lua
│  │  │  └─ Diagnostics.lua
│  │  ├─ Builtin/
│  │  │  ├─ BlizzardProvider.lua
│  │  │  ├─ SpellProvider.lua
│  │  │  ├─ ItemProvider.lua
│  │  │  ├─ MacroProvider.lua
│  │  │  ├─ SettingsProvider.lua
│  │  │  ├─ PluginProvider.lua
│  │  │  └─ SystemProvider.lua
│  │  ├─ Semantic/
│  │  │  ├─ Normalizer.lua
│  │  │  ├─ Tokenizer.lua
│  │  │  ├─ Pinyin.lua
│  │  │  ├─ IntentParser.lua
│  │  │  ├─ StaticIndex.lua
│  │  │  ├─ DynamicResolver.lua
│  │  │  ├─ Ranker.lua
│  │  │  └─ QueryOrchestrator.lua
│  │  ├─ UI/
│  │  │  ├─ Palette.lua
│  │  │  ├─ Input.lua
│  │  │  ├─ ResultList.lua
│  │  │  ├─ ResultRow.lua
│  │  │  ├─ KeybindManager.lua
│  │  │  └─ Theme.lua
│  │  ├─ Secure/
│  │  │  ├─ SecureActionBroker.lua
│  │  │  ├─ SecureButtonPool.lua
│  │  │  └─ Descriptor.lua
│  │  ├─ Adapters/
│  │  │  └─ (legacy bridges only)
│  │  └─ Media/
│  └─ LycheeSDK/
│     ├─ LycheeSDK.toc
│     ├─ Bootstrap.lua
│     ├─ API/
│     │  ├─ Version.lua
│     │  ├─ Schema.lua
│     │  ├─ ProviderAPI.lua
│     │  ├─ EntryAPI.lua
│     │  ├─ IntentAPI.lua
│     │  └─ Errors.lua
│     ├─ Runtime/
│     │  ├─ PendingRegistry.lua
│     │  ├─ Compatibility.lua
│     │  └─ Notifications.lua
│     └─ Docs/
├─ docs/
│  └─ ARCHITECTURE.md
├─ tools/
├─ analyze/                 # local-only, ignored by Git
├─ AGENTS.md                # local-only, ignored by Git
└─ .gitignore
```

Live installation:

```text
D:\Game\World of Warcraft\_retail_\Interface\AddOns\
├─ Lychee\
└─ LycheeSDK\
```

The current repository policy treats `AGENTS.md` and `analyze/` as local-only.
They are never included in a runtime package.

### 2.1 文件依赖方向

依赖只能从上到下，禁止反向引用：

```text
Bootstrap
  -> Core/Lifecycle -> Core services
  -> Semantic      -> Core/ProviderRegistry + Core/ContextStore (只读接口)
  -> UI            -> Semantic/QueryOrchestrator + Core/IntentRouter
  -> Secure        -> Core/IntentRouter (只接收 Descriptor)
  -> Builtin       -> Core/ProviderRegistry + SDK-compatible host services
```

- `SDK` 目录中的代码不能 `:CreateFrame`、注册 Blizzard 事件或引用 `Lychee.UI`。
- `Semantic` 不能写 SavedVariables、显示 UI 或执行 Intent。
- `UI` 只能持有 `ResultViewModel`，不能持有 Provider 原始表。
- `Builtin` 不得修改其他 Provider 的状态；跨模块数据只能通过 ContextStore 或窄接口读取。
- `Secure` 不得暴露按钮对象、脚本字符串或任意属性写入 API 给 SDK。

### 2.2 TOC 加载契约

`LycheeSDK.toc` 只列 SDK 的 `Bootstrap.lua`、`API/` 和 `Runtime/` 文件；
`Lychee.toc` 通过 `## OptionalDeps: LycheeSDK` 保证 SDK 先加载，并按以下顺序列文件：

1. `Core/ErrorBoundary.lua`、`Core/Diagnostics.lua`（先建立错误接收处）。
2. `Core/Host.lua`、`Core/Lifecycle.lua`、`Core/Scheduler.lua`。
3. `Core/ProviderRegistry.lua`、`Core/ContextStore.lua`、`Core/IntentRouter.lua`。
4. `Semantic/*`。
5. `Secure/*`。
6. `Builtin/*`。
7. `UI/*`、`Bootstrap.lua`、`Bindings.xml`。

任何文件不得依赖“同一 TOC 中稍后才执行的 chunk 已经运行”。需要前置对象时，
通过 `Lychee:RegisterModule(name, initFn, priority)` 放入生命周期队列，由 Host 统一调用。

### 2.3 AddOn loading topology

`LycheeSDK` is loaded before `Lychee`. Third-party addons that integrate with
the SDK declare `## OptionalDeps: LycheeSDK`; they remain functional when the
SDK or host is absent.

```text
LycheeSDK.toc
    -> creates the public SDK object and pending provider registry
Lychee.toc
    -> consumes the SDK registry and installs the host implementation
Third-party addon
    -> calls SDK:RegisterProvider(...) from its own main chunk
```

The SDK must be usable before the host loads. Registration stores validated
provider declarations in a pending registry. When Lychee attaches, it drains
that registry exactly once. A provider does not need a reload or second user
action to become searchable.

## 3. Module Ownership

### 3.1 `LycheeSDK`

Public, stable and deliberately small. It owns:

- API version and capability negotiation.
- Provider/Entry/Intent schema validation.
- Provider registration and pending-registration storage.
- Compatibility shims and no-op behavior when Lychee is absent.
- Public error codes and provider lifecycle notifications.

It does not own frames, search indexes, Blizzard event collection, SavedVariables,
secure buttons, palette rendering or provider business logic.

### 3.2 `Lychee/Core`

Host-only implementation. It owns:

- Host lifecycle and initialization order.
- Provider registry consumption and enable/disable state.
- Context Store and event subscriptions.
- Static and dynamic indexes.
- Query orchestration and ranking.
- Intent routing and execution policy checks.
- Host error reporting and performance accounting.

### 3.3 `Lychee/Builtin`

First-party capabilities implemented with the same normalized Provider contract:

- `BlizzardProvider`: Blizzard panels and system UI.
- `SpellProvider`: known spells and spell-related actions.
- `ItemProvider`: inventory, equipment and consumable actions.
- `MacroProvider`: pre-existing macros and macro navigation.
- `SettingsProvider`: Lychee and registered addon settings.
- `PluginProvider`: installed addons and their exposed capabilities.
- `SystemProvider`: recent items, favorites, help and diagnostics.

Built-ins may call internal services. External providers may only use SDK
services. Both produce the same Entry and Intent shape before entering search
or execution.

### 3.4 `Lychee/UI`

Owns the palette state machine and pooled controls. UI code consumes ranked
results and emits `execute(entryID)`; it does not call provider functions by
name and does not inspect provider internals.

### 3.5 `Lychee/Secure`

Owns protected execution descriptors, secure button creation and combat-state
policy. It never accepts arbitrary Lua source from a provider.

### 3.6 `Lychee/Adapters`

Adapters are compatibility bridges for addons that cannot ship a provider.
New integrations use the SDK and do not add a host adapter. An adapter may
translate an old API into the Provider/Entry/Intent contract, then disappears
from the rest of the system.

## 4. Core Runtime State

The host has one authoritative runtime object:

```lua
Lychee = {
    state = "BOOTSTRAP",       -- BOOTSTRAP/READY/PALETTE/COMBAT_LOCKED/SHUTDOWN
    apiVersion = 1,
    providerRegistry = ...,
    contextStore = ...,
    query = ...,
    intent = ...,
    palette = ...,
}
```

Internal fields are private by convention and are not part of the SDK. Public
objects are returned through SDK methods and are never exposed as mutable host
tables.

### 4.1 Lifecycle phases

```text
BOOTSTRAP
  -> SDK_READY
  -> PROVIDERS_COLLECTED
  -> SAVED_VARIABLES_READY
  -> PLAYER_LOGIN_READY
  -> HOST_READY
  -> PALETTE_OPEN (temporary)
  -> HOST_READY
```

Rules:

1. SDK creates its registry in its main chunk.
2. Host creates Core services and consumes pending registrations.
3. SavedVariables are bound before provider initialization that reads settings.
4. Blizzard-dependent providers initialize at `PLAYER_LOGIN`.
5. Palette frames are created once, hidden, and pooled.
6. A provider that fails initialization is disabled for the session and reported.

No provider assumes the palette is open during registration. No provider creates
a permanent `OnUpdate` driver during registration.

### 4.2 精确启动时序

```text
ADDON_LOADED(LycheeSDK)
  1. SDK 创建私有状态和 pendingRegistry
  2. SDK 暴露全局只读入口 `LycheeSDK`
  3. 已加载的第三方主 chunk 调用 RegisterProvider，进入 pending

ADDON_LOADED(Lychee)
  4. Host 创建 `Lychee` 私有运行时和 direct event frame
  5. Host 绑定/迁移 `LycheeDB`，但不初始化依赖玩家状态的 Provider
  6. Host 调用 `SDK:AttachHost(hostAdapter)`，一次性 drain pending
  7. Host 校验所有声明，状态置为 `registered`

PLAYER_LOGIN
  8. ContextStore 建立初始快照并注册精确 unit/event 监听
  9. 静态 Provider 批量发布 Entry，StaticIndex 单次构建
 10. UI 创建并隐藏 Palette、ResultRow 池和安全按钮池
 11. 所有成功 Provider 状态置为 `enabled`，Host 状态置为 `READY`
```

同一事件重复触发必须幂等。`AttachHost`、`PLAYER_LOGIN` 和 `ReloadIndex` 均有
一次性 guard；不允许通过重复执行来“修复”初始化顺序。

### 4.3 Provider 生命周期状态机

```text
PENDING -> REGISTERED -> ENABLED -> SLOW -> DISABLED
             |             |          |          |
             +-------------+----------+----------+
                    UNREGISTERED（仅在 Host 未执行中的安全点）
```

- `PENDING`：SDK 已校验声明，Host 尚未 Attach。
- `REGISTERED`：已进入 Host registry，但尚未完成 `init`。
- `ENABLED`：可参与静态检索和动态解析。
- `SLOW`：最近窗口超过预算，仍可参与但只走 deferred resolver。
- `DISABLED`：本会话停止调用；必须保留错误码和最后一次耗时。
- `UNREGISTERED`：Provider 主动注销或其 AddOn 卸载。若当前查询正在执行，
  先标记 `retiring=true`，待 generation 完成后再从索引移除，不能在遍历中直接删表。

Provider 只允许通过 `SDK:RegisterProvider`、`SDK:UnregisterProvider(handle)`、
`SDK:SetProviderEnabled(handle, enabled)` 改变状态。handle 由注册调用返回，防止
同 ID 的新版本误删旧实例。Host 禁用不会删除 SavedVariables 或公开 Entry ID。

## 5. Public SDK Contract

### 5.1 Provider registration

```lua
SDK:RegisterProvider({
    id = "my-addon",
    apiVersion = 1,
    name = "My Addon",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    priority = 100,
    capabilities = {
        staticEntries = true,
        dynamicSearch = true,
        contextActions = true,
        secureActions = false,
    },
    entries = { ... },
    search = function(query, context) ... end,
    resolve = function(ast, context) ... end,
})
```

Required fields: `id`, `apiVersion`, `name`, and at least one of `entries`,
`search` or `resolve`.

Provider IDs are lowercase, globally unique and immutable after publication.
The SDK rejects duplicate IDs; the first valid registration wins and a
diagnostic is emitted for the duplicate.

Allowed `priority` range is `-100..1000`. Host built-ins use `500..1000`;
external providers default to `0`. Priority affects ranking only and never
grants execution privileges.

#### 5.1.1 注册结果与版本协商

`RegisterProvider` 不向第三方抛出错误；始终返回 `ok, handleOrError`：

```lua
local ok, handleOrError = LycheeSDK:RegisterProvider(declaration)
if not ok then
    -- handleOrError.code: INVALID_SCHEMA / DUPLICATE_ID / UNSUPPORTED_API / ...
end
```

SDK 支持矩阵：

| `apiVersion` | 行为 |
| --- | --- |
| `1` | 支持 `entries`、`search`、`resolve` 和普通 Intent |
| `1` + `secureActions=true` | 还必须提供 v1 Descriptor；不接受任意回调执行 |
| 高于 Host 支持版本 | 保留为 `pending/incompatible`，不调用回调 |
| 低于最低版本 | 返回 `UNSUPPORTED_API`，不进入 registry |

Provider 可声明 `minHostVersion`。Host 不满足时状态为 `incompatible`，诊断显示
需要的版本，但不影响其他 Provider。`SDK:GetCapabilities()` 返回
`{ apiVersion, hostAttached, secureDescriptors }`，第三方可据此只发布兼容能力。

#### 5.1.2 完整声明形状

```lua
{
    id = "my-addon",                  -- [a-z0-9][a-z0-9.-]{0,63}
    apiVersion = 1,                    -- integer
    minHostVersion = 1,                -- optional integer
    name = "My Addon",                -- string or locale table
    icon = "Interface\\Icons\\...", -- optional texture path/fileID
    priority = 0,                      -- integer -100..1000
    capabilities = { ... },
    dependencies = { "other-addon" }, -- optional provider IDs
    entries = function() return entries end, -- table or zero-arg factory
    search = function(query, context) return entries end,
    resolve = function(ast, context) return entryOrNil end,
    init = function(hostServices) return cleanupFn end,
    shutdown = function(reason) end,
}
```

`entries` 工厂只在启用或显式索引失效时调用，不在每次按键时调用。`init` 返回的
`cleanupFn` 在禁用/注销时只执行一次；即使没有返回值，Host 仍会断开由它托管的事件
和 timer。`dependencies` 只表达能力依赖，不改变 WoW AddOn 加载顺序。

### 5.2 Entry schema

```lua
{
    id = "my-addon:open-options",
    title = "打开插件设置",
    subtitle = "My Addon",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    category = "settings",
    aliases = { "配置", "选项", "options" },
    keywords = { "设置", "config" },
    pinyin = { "shezhi", "sz" },
    verbs = { "打开", "查看", "open", "show" },
    availability = function(context) return true end,
    intent = {
        type = "open-config",
        addon = "my-addon",
    },
}
```

Invariants:

- `id` is unique within a provider and stable across releases.
- `title` is user-visible and localized by the provider.
- Index metadata is separate from display text.
- `availability` is cheap and runs after candidate retrieval.
- An Entry has a declarative Intent or a host-approved callback registration.
- An Entry never receives a UI frame reference.

#### 5.2.1 Entry 与 Intent 的稳定性

Provider 只填写 `intent` 或注册过的 `intentFactoryKey`，`providerID` 由 Host 填充：

```lua
{
    id = "my-addon:open-options",
    providerID = "my-addon",
    schemaVersion = 1,
    title = "打开插件设置",
    subtitle = "My Addon",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    category = "settings",
    aliases = { "配置", "选项", "options" },
    keywords = { "设置", "config" },
    pinyin = { "shezhi", "sz" },
    verbs = { "打开", "查看", "open", "show" },
    availabilityKey = "my-addon:settings",
    intent = { type = "open-config", addon = "my-addon" },
}
```

`Entry.id` 在 Provider 的整个发布周期内不可复用；删除后保留 tombstone 一个数据版本，
避免 recent/favorite 指向另一项能力。展示文本变化不影响 ID。Provider 的
`availability` 函数必须无副作用且快速；新实现优先使用 Host 注册的
`availabilityKey`，由 Host 统一读取 Context。

### 5.3 Dynamic search contract

`search(query, context)` receives an immutable query snapshot and a read-only
context snapshot. It returns at most 20 normalized Entry values. The host may
discard results from an obsolete query generation.

The provider does not mutate `context`, write SavedVariables, create frames or
perform protected actions in `search`.

#### 5.3.1 查询代次、取消和预算

每次输入变化生成不可复用的 `generation`：

```lua
querySnapshot = {
    generation = 1042,
    raw = "打开 天赋",
    normalized = ...,
    contextVersion = 42,
    deadlineMS = 8,
}
```

Host 先递增 generation、标记旧任务 cancelled，再同步完成静态检索。动态 Provider
收到只读快照，返回值由 Host 绑定 generation。回调没有协作式取消时，采用“结果丢弃”：

```lua
if resultGeneration ~= Query.activeGeneration then return end
```

同一 Provider 同一 generation 不重复调用。输入事件在 `0.05s` debounce 窗口内只保留
最后一次；上下文变化在窗口内合并为一次 flush。每代最多调用 8 个动态 Provider、
每个最多返回 20 条 Entry、同步总预算 8ms。超预算 Provider 进入 `SLOW` 并排入
deferred 队列，不能继续占用下一次按键的同步路径。

### 5.4 Capabilities

```text
staticEntries       provider has load-time entries
dynamicSearch       provider resolves query-dependent results
contextActions      provider consumes context fields
secureActions       provider declares secure descriptors
settingsLink        provider exposes a settings target
```

Capabilities describe behavior, not trust. Only the host grants secure
execution after validating a descriptor.

## 6. Query and Semantic Matching Pipeline

```text
raw input
  -> Normalizer
  -> Tokenizer
  -> IntentParser
  -> StaticIndex retrieval
  -> Provider resolver pass
  -> Availability/context filter
  -> Fuzzy scoring
  -> Ranker
  -> pooled ResultRows
```

### 6.1 Normalizer

```lua
{
    raw = "打开 天赋",
    folded = "打开 天赋",
    tokens = { "打开", "天赋" },
    asciiTokens = {},
    pinyinTokens = {},
    compact = "打开天赋",
}
```

It performs case, punctuation and whitespace folding, known
traditional-to-simplified aliases, English lowercase and command-prefix
extraction. It does not call provider code.

Reserved prefixes:

```text
>query       prefer command/provider search
@name        prefer addon/provider names
!action      prefer executable actions
?help        search help and diagnostics
```

Prefixes are optional ranking hints, not separate execution paths.

### 6.2 Token and alias data

Every Entry contributes title, aliases, keywords, pinyin and optional verbs to
an inverted index:

```text
token -> entry IDs
```

Chinese segmentation uses a small built-in dictionary plus character bigrams
as fallback. Pinyin is generated offline or supplied by the provider; runtime
code does not load a large NLP package.

### 6.3 Intent parsing

```lua
{
    verb = "open",
    target = "talent",
    unit = nil,
    modifiers = {},
}
```

Canonical verbs include `open`, `show`, `search`, `cast`, `use`, `equip`,
`copy`, `navigate` and `help`. Providers add aliases but do not create an
execution path outside the Intent schema.

### 6.4 Candidate retrieval and ranking

The host retrieves a bounded candidate set before fuzzy work. Default limit is
200 candidates and 20 displayed results.

```text
ID exact match          1000
Title exact match        900
Alias exact match        800
Token prefix match       700
All-token match          600
Intent verb/object       550
Synonym match            500
Fuzzy match              400
Context relevance        +100
Favorite                 +80
Recent                   +50
Provider priority        +priority
```

Scores are explainable and can be logged in developer mode. A low-confidence
result is displayed only above the configured threshold; otherwise the UI shows
help/recent fallback results.

### 6.5 Dynamic provider budget

Static retrieval is synchronous. Dynamic calls are limited to providers whose
metadata intersects the query or context. The host invokes at most 8 dynamic
providers per query generation and accepts at most 20 results from each.

Slow providers are measured with `debugprofilestop`, marked in the session and
moved to deferred resolver passes. The host never performs a full provider scan
on every keystroke.

### 6.6 QueryOrchestrator 精确算法

一次查询按以下顺序执行，顺序不可调整：

```text
OnTextChanged(raw)
  -> generation += 1，旧 generation 标记 cancelled
  -> 记录 pendingRaw，重启唯一 debounce timer
  -> Flush(generation)
       1. Normalize/Tokenize/ParseIntent
       2. 用 tokenPosting 求并集，截断为 200 个 candidateID
       3. 读取 generation 创建时的 ContextSnapshot
       4. availability/context filter
       5. 计算静态分数并 stable sort
       6. 立即发布最多 20 条静态结果
       7. 选择最多 8 个动态 Provider
       8. 在同步预算内执行 fast resolver
       9. 合并、去重、重排并发布
      10. 剩余 resolver 进入 deferred queue
```

每一个可重入边界之后都检查 `generation == activeGeneration`：Provider 回调返回后、
deferred tick 开始时、结果发布前和 UI render 前。旧 generation 只能释放 scratch/table，
不能更新结果、recent、诊断中的“当前查询”或选中行。

去重键固定为 `providerID .. "\0" .. entryID`。动态结果与静态结果同键时，动态结果只允许
更新 `subtitle`、`icon`、`availability` 和 Intent payload，不允许改变 ID、Provider 和
基础索引词。排序使用 `(score desc, providerPriority desc, normalizedTitle asc, stableID asc)`，
因此同样输入和 Context 必须得到同样顺序。

### 6.7 Deferred resolver 调度

`Core/Scheduler.lua` 只有一个可见时驱动：Palette 打开且队列非空时 `Show()`，否则
`Hide()`。每帧可使用的 Lua 时间片默认 2ms，最多执行一个 Provider 回调；执行前后用
`debugprofilestop()` 采样。队列元素为：

```lua
{
    generation = 1042,
    providerID = "my-addon",
    querySnapshot = querySnapshot,
    contextSnapshot = contextSnapshot,
    enqueuedAtMS = 123456,
}
```

调度规则：

1. Palette 隐藏、generation 过期或 Provider 不再 enabled 时直接丢弃。
2. 同 Provider 在一代中只允许一个排队项。
3. 一个回调超过 4ms 记一次 slow strike；连续 3 次进入 `SLOW`。
4. `SLOW` Provider 只在静态结果不足 10 条时调度，且每代最多一次。
5. 回调错误记 failure，不重试当前 generation；下一个 generation 才可重新参与。
6. 队列清空时当帧隐藏 driver，不能等下一帧再隐藏。

### 6.8 缓存分层与失效

| 缓存 | Key | 失效条件 |
| --- | --- | --- |
| normalized query | raw string | LRU 128；超限淘汰 |
| token posting | normalized token | Provider static revision 改变 |
| parsed intent | normalized compact query | synonym/verb dictionary revision 改变 |
| provider static entries | providerID + declaration revision | enable/disable/register/unregister |
| dynamic result | providerID + query + declared context versions | 任一版本变化或 TTL 到期 |
| ranked result | generation only | generation 结束即释放 |

缓存不得把完整 Context、UI frame、Provider declaration 或闭包作为 key。失效操作只标记
revision/dirty，在安全点批量重建；事件 handler 内不重建完整索引。

## 7. Context Store

```lua
{
    version = 42,
    player = { class = "MAGE", specID = 64, level = 90 },
    target = { exists = true, hostile = true, unit = "target" },
    zone = { mapID = 123, instanceType = "party" },
    group = { type = "party", size = 5 },
    combat = false,
    ui = { activePanel = nil },
}
```

Events update only the affected slice and increment its version:

```text
PLAYER_SPECIALIZATION_CHANGED -> player.specVersion
PLAYER_TARGET_CHANGED         -> target.version
PLAYER_ENTERING_WORLD         -> zone.version/group.version
PLAYER_REGEN_DISABLED         -> combat
PLAYER_REGEN_ENABLED          -> combat
```

Providers declare context dependencies. A provider is invalidated only when a
declared dependency changes. Context collection is event-driven; providers do
not poll the whole game state from `OnUpdate`.

### 7.1 Snapshot 契约

ContextStore 内部按 slice 保存 `{ value, version }`。查询开始时只复制 Provider 声明的
slice 引用与数值 version，Provider 得到的表设置只读 metatable；修改尝试产生
`READ_ONLY_CONTEXT` 诊断。快照在整个 generation 中保持一致，不因中途目标变化而替换。

Provider 声明依赖：

```lua
context = {
    required = { "player.spec", "combat" },
    optional = { "target", "zone" },
}
```

未知字段在注册时拒绝。`required` slice 尚未 ready 时 Provider 暂不参与；`optional`
缺失时读取为 `nil`。不得把 `Unit*` API、背包全量扫描等昂贵工作藏在 getter 中；
ContextStore getter 只返回已经由事件更新的缓存。

## 8. Intent and Execution

Search results produce an Intent, never an arbitrary function call from UI.

```lua
{
    type = "open-panel",
    provider = "blizzard",
    action = "talents",
    payload = {},
    policy = {
        combat = "allowed",
        secure = false,
    },
}
```

### 8.1 Ordinary executor

Handles panels, settings, navigation, copying text and ordinary UI actions. It
validates provider/action ownership and wraps external callbacks in a local
`xpcall` boundary.

### 8.2 Secure Action Broker

Handles spell, item, target and macro actions through declarative descriptors:

```lua
{
    type = "spell",
    spellID = 12345,
    unit = "target",
}
```

The broker pre-creates a bounded secure-button pool, writes attributes only
when permitted, and applies these policies:

```text
allowed          execute immediately
out-of-combat    show “available after combat” state
secure-required  route through broker
unavailable      return a user-visible reason
```

Provider callbacks never receive secure button references and never submit Lua
source for execution.

### 8.3 IntentRouter 路由表

Intent 类型必须注册到静态路由表，不能根据字符串拼接全局函数名：

| 类型 | Executor | 可在战斗中搜索 | 可在战斗中执行 |
| --- | --- | --- | --- |
| `open-panel` | OrdinaryExecutor | 是 | 视 Blizzard API 限制 |
| `open-config` | OrdinaryExecutor | 是 | 否，排队到脱战或提示 |
| `copy-text` | OrdinaryExecutor | 是 | 是 |
| `run-provider-action` | CallbackExecutor | 是 | 仅声明为 allowed |
| `cast-spell` | SecureActionBroker | 是 | 仅预备好的 secure action |
| `use-item` | SecureActionBroker | 是 | 仅预备好的 secure action |
| `run-macro` | SecureActionBroker | 是 | 仅预备好的 secure action |

路由前依次校验：Entry 仍存在、Provider 仍 enabled、Intent schema 合法、Context 条件仍满足、
combat policy、secure descriptor。任一步失败返回结构化 `ExecutionResult`：

```lua
{ ok = false, code = "COMBAT_LOCKED", messageKey = "action_after_combat" }
```

只有 `ok=true` 才写 recent 和 usage count；失败不得改变排序历史。

### 8.4 SecureActionBroker 准备生命周期

Secure Action 不能在按下 Enter 后临时创建或随意改属性。Broker 使用以下两阶段模型：

```text
OUT_OF_COMBAT
  descriptor validate
    -> canonical key
    -> 从固定池分配 secure button
    -> ClearAttributes + 写 type/spell/item/macrotext/unit
    -> 标记 PREPARED(descriptorKey, revision)

USER EXECUTE
  -> 再校验 descriptorKey/revision/context
  -> READY: 通过预备按钮的受保护点击路径执行
  -> NOT_PREPARED: 返回结构化原因，不伪装成已执行
```

池的默认上限由设置固定，首版为 32；仅为当前可见候选和固定 favorite 预备。Palette 结果变化
时，脱战状态下复用/重写池；战斗中冻结属性，只允许使用战斗开始前已 `PREPARED` 且 revision
一致的按钮。`PLAYER_REGEN_ENABLED` 后批量处理 `dirtyDescriptors`，每帧最多准备 4 个，
完成后 driver 立即停止。

Descriptor canonical key 包含 type、spellID/itemID/macroID、unit、button 和所有影响 secure
属性的 modifier。禁止 Provider 提供 `_onclick`、`PreClick`、`PostClick`、frame reference、
macro Lua、任意 attribute 名或超过 Blizzard 宏文本限制的内容。Descriptor 校验失败时返回
`INVALID_SECURE_DESCRIPTOR`，并记到 Provider session record。

### 8.5 普通回调边界

外部普通回调通过注册时获得的 callback key 调用，不允许把 closure 直接挂进 Entry。Host 在
局部 `xpcall(callback, errorHandler, immutablePayload, contextSnapshot)` 中执行；回调不能得到
Palette frame、registry、SavedVariables root 或 SecureButton。一次执行超过 8ms 记录 slow
strike，但不在同一次用户动作里自动重试，防止副作用重复。

## 9. Palette UI and Keybinding

### 9.1 State machine

```text
HIDDEN
  -> OPENING
  -> READY
  -> SEARCHING
  -> EXECUTING
  -> HIDDEN
```

The only global binding calls `TogglePalette`:

- HIDDEN: reuse the palette, show it, focus the EditBox and select all text.
- READY/SEARCHING: hide the palette and release focus.
- Combat/secure restriction: the palette may open for search; protected
  execution remains subject to Intent policy.

### 9.2 Pooled UI

The palette owns a fixed result-row pool. Rendering diffs previous result IDs
against new result IDs. It updates changed rows, hides unused rows and never
tears down the entire list for one query change.

Palette-local keys:

```text
UP/DOWN       move selection
ENTER         execute selected Intent
ESCAPE        hide palette
TAB           cycle category/filter
CTRL+ENTER    explicit confirmation when supported
```

When hidden, the palette has no active `OnUpdate`; query work happens on text
change and is debounced/coalesced.

### 9.2.1 Palette 状态转换副作用

| 转换 | 必须执行 | 禁止执行 |
| --- | --- | --- |
| `HIDDEN -> OPENING` | Show、恢复上次位置、建立空 generation | 重建索引、创建结果行 |
| `OPENING -> READY` | Focus EditBox、选择文本、发布 recent/favorite | 启动永久 OnUpdate |
| `READY -> SEARCHING` | 递增 generation、启动唯一 debounce | 同步调用全部 Provider |
| `SEARCHING -> READY` | 仅接受当前 generation、diff render | 整体销毁/重建 ResultList |
| `READY -> EXECUTING` | 冻结选择、路由 Intent、防重复 Enter | 直接调用 Provider 表函数 |
| `* -> HIDDEN` | cancel generation、清 deferred、释放焦点、Hide driver | 保留查询 timer/动画 |

快速重复按快捷键必须幂等：OPENING 再 Toggle 直接进入 HIDDEN；EXECUTING 时 Toggle 只隐藏 UI，
不能中断已经进入外部回调的普通动作。关闭时保留文本由用户设置决定，但无论是否保留都要
递增 generation，使所有晚到结果失效。

ResultRow 池固定 20 行。每行只接收不可变 ViewModel：

```lua
{
    stableID = "provider\0entry",
    title = "...",
    subtitle = "...",
    icon = 123,
    selected = false,
    availability = "ready", -- ready/locked/unavailable/deferred
}
```

`ResultList:Render` 以 stableID 复用行，只对变化字段调用 setter；选中项消失时选择排序后的
第一项，不能按旧数组 index 选择另一条 Entry。

### 9.3 Keybind configuration

`KeybindManager` follows FarmHud's native pattern:

```lua
local function SetLycheeBinding(key)
    local old = GetBindingKey("TOGGLELYCHEE")
    if old then SetBinding(old) end
    if key and key ~= "" then SetBinding(key, "TOGGLELYCHEE") end
    SaveBindings(GetCurrentBindingSet())
end
```

The host never overwrites a saved binding at login. A default binding is a
first-install suggestion only. Conflict information is read with
`GetBindingAction` and shown in options; changing a binding is a user action.

## 10. Persistence

Lychee owns one SavedVariables root. Provider data is namespaced beneath it:

```lua
LycheeDB = {
    version = 1,
    profileKeys = {},
    profiles = {
        Default = {
            recent = {},
            favorites = {},
            providers = {},
        },
    },
}
```

Provider settings use `profiles.Default.providers[providerID]`. Providers do not
create independent SavedVariables for search metadata. Defaults are merged on
load; values equal to defaults may be stripped on logout. Migrations are
versioned and run before provider enablement.

The format may be AceDB-compatible for migration convenience, but the runtime
implementation remains Lychee-owned and dependency-free.

## 11. Errors, Isolation and Diagnostics

Every provider has a session record:

```lua
{
    state = "enabled", -- pending/enabled/slow/disabled
    failures = 0,
    lastError = nil,
    queryCostMS = 0,
}
```

Rules:

- Registration errors disable only that provider.
- Search errors return no results from that provider and preserve the query.
- Execution errors show a concise user error and retain a developer trace.
- Three failures in one session put a provider in `disabled` state.
- Core errors use the normal WoW error handler and keep the palette closable.
- Developer mode may show provider, score components, query generation and
  execution policy; default mode avoids diagnostic allocation in hot paths.

## 12. Performance Budget

These are architecture constraints:

- No global per-frame search/update loop.
- No provider full scan on every keystroke.
- Static indexes build once and invalidate by explicit version changes.
- Dynamic providers have bounded count, result count and measured cost.
- Result rows, temporary token tables and common strings are reused where they
  are proven hot.
- Expensive UI setters are change-guarded.
- Provider callbacks do not create frames during search.
- Hidden Palette, empty provider registry and completed Intent execution have no
  active ticker.
- Search debounce defaults to `0.05` seconds.
- Ranking runs on at most 200 candidates; display is capped at 20.

Validation scenarios:

```text
login -> idle -> open palette -> 1-char query -> 20-char query
single target combat -> multi-target combat -> full group
1000+ static entries -> 8 dynamic providers -> provider failure
palette close -> provider disable -> reload
```

Measure CPU, Lua memory, active rows, provider query cost and frame time with
WoW profiling tools. A permanent frame/ticker requires a documented cost and an
explicit stop condition.

## 13. EllesmereUI Reference Decisions

The reference implementation is EllesmereUI release v8.9.1, commit
`1b37158d7533deb2d5b0a74292438a8ea2191588`.

Relevant decisions to reuse:

- `EllesmereUI_Lite.lua` replaces AceAddon/AceEvent/AceDB with a small addon
  registry, direct event frames, lifecycle queues and local database helpers.
- Direct event handlers avoid a generic callback dispatch layer in the hot path.
- Existing AceDB-shaped SavedVariables are read for compatibility without
  requiring AceDB at runtime.
- `EllesmereUI_Ticker.lua` uses self-disarming drivers and dense-array
  swap-remove registration.
- `EllesmereUI_UICore.lua` separates cheap visual updates from throttled widget
  refreshes and defers full GC.
- `EllesmereUI_AuraKit.lua` caches normalized filters and change-guards expensive
  UI setters.

EllesmereUI still uses selected standalone libraries such as LibStub,
CallbackHandler, LibSharedMedia, LibDeflate, LibKeystone and
LibSpecialization. The decision for Lychee is “no Ace3 framework dependency”,
not “no reusable library may ever be used”. A dependency must be justified by a
concrete capability and measured cost.

## 14. Host Services 与内部功能接入

### 14.1 ProviderContext（内部与 SDK 统一）

Host 给 Provider 的 `init(hostServices)` 只暴露以下窄接口；返回对象必须是只读代理：

```lua
hostServices = {
    apiVersion = 1,
    providerID = "my-addon",
    registerEntries = function(entriesOrFactory) end,
    invalidate = function(reason) end,
    getContext = function(keys) return snapshot end,
    registerIntentFactory = function(key, descriptor) end,
    registerCallback = function(key, fn, policy) end,
    getProviderSetting = function(key, default) return value end,
    log = function(level, code, fields) end,
}
```

禁止暴露：`LycheeDB` 根表、`ProviderRegistry`、`StaticIndex`、Palette frame、任意
`CreateFrame` helper、SecureButtonPool 和全局事件 frame。`registerEntries` 只写入该
Provider 的 namespace；`invalidate("entries"|"availability"|"context")` 只设置 dirty 位，
不在调用点同步重建索引。

### 14.2 内部功能的接入方式

内部功能与第三方完全走相同的四步：

1. 在 `Builtin/<Name>Provider.lua` 定义声明和稳定 Entry ID。
2. 在 `init` 中注册静态 Entry、Intent factory 和 Context 依赖。
3. 由 `Core/ProviderRegistry` 完成启用、索引和错误隔离。
4. 由 `IntentRouter`/`SecureActionBroker` 执行，不从 UI 直接调用内部函数。

示例：设置页面只发布 `intent={type="open-config", addon="lychee"}`；SpellProvider
只发布 `cast-spell` Descriptor；RecentProvider 不创建新动作，而是读取 usage store
生成已有 Entry 的排序加权。这样内部功能不会形成一套绕过 SDK 的“特权 API”。

### 14.3 SDK 外部接入最小示例

```lua
local SDK = LycheeSDK
local ok, handle = SDK:RegisterProvider({
    id = "my-addon",
    apiVersion = 1,
    name = "My Addon",
    entries = {
        {
            id = "my-addon:open",
            title = "打开面板",
            aliases = { "配置", "open" },
            intent = { type = "open-config", addon = "my-addon" },
        },
    },
})
```

接入方只需要声明能力；不需要知道索引、输入框、快捷键或安全按钮如何实现。卸载/禁用时
调用 `SDK:UnregisterProvider(handle)`，而不是操作 Host 表。

## 15. 配置、迁移与数据所有权

### 15.1 SavedVariables 所有权

`LycheeDB` 只由 Host 声明和写入。Provider 数据必须位于
`LycheeDB.profiles[profile].providers[providerID]`，SDK 不声明 SavedVariables。
Host 给出的 settings API 返回拷贝或标量；Provider 通过 `SetProviderSetting` 写入，
写入操作只标记 dirty，由 logout/显式保存时批量落盘。

### 15.2 迁移顺序

```text
读取根表 -> 缺失字段补默认 -> 执行 version migration[n]
-> 校验 profile/provider namespace -> 丢弃未知/损坏值并记录诊断
-> 迁移完成后才 Enable Provider
```

迁移函数必须幂等、无 UI/战斗 API 调用、无深拷贝整表；每个版本只执行一次并写入
`LycheeDB.version`。Provider 自己的配置版本放在 namespace 的 `schemaVersion`，由
Host 在调用 `init` 前按声明迁移。

### 15.3 Recent/Favorite 数据规则

- `recent` 只存 stableID、最后时间和计数，不存 Entry 全量快照。
- `favorites` 只存 stableID；Entry 不存在时显示“已移除”并提供清理动作。
- 只有成功 `ExecutionResult.ok=true` 才更新 recent；搜索/预览不计入。
- Provider 注销不删除其历史数据，重新注册同 ID 可恢复；ID 重新指向不同语义属于兼容性错误。

## 16. 错误、事件和可观测性契约

### 16.1 错误码

SDK/Host 使用稳定机器码，UI 只把机器码映射到本地化 message key：

```text
INVALID_SCHEMA, DUPLICATE_ID, UNSUPPORTED_API, INCOMPATIBLE_HOST,
PROVIDER_DISABLED, PROVIDER_TIMEOUT, PROVIDER_ERROR, STALE_GENERATION,
ENTRY_NOT_FOUND, INTENT_INVALID, COMBAT_LOCKED, INVALID_SECURE_DESCRIPTOR,
SECURE_NOT_PREPARED, ACTION_UNAVAILABLE, CALLBACK_ERROR
```

错误对象至少包含 `code`、`providerID`（若有）、`generation`（查询错误时）、
`retryable` 和内部 `traceID`。默认 UI 不显示 Lua error 原文；开发者诊断页可按 traceID 展开。

### 16.2 事件归属

每个事件只允许一个 Core handler 接收，然后更新 Context slice 或设置 dirty 位。Provider
不得自行注册全局 `COMBAT_LOG_EVENT_UNFILTERED`、全量 `NAME_PLATE_*` 等高频事件；需要
这些数据时必须申报 capability，由 Host 评估成本后提供聚合快照。模块卸载时按注册 token
注销 handler，不能依赖 `OnHide` 自动清理。

### 16.3 诊断采样

开发者模式的每条查询记录：generation、raw 长度、candidate 数、动态 Provider 数、
各阶段耗时、丢弃原因和最终结果数。默认模式只维护计数器和最近一次错误，避免为每个按键
分配日志表。采样 ring buffer 固定 64 条，重载或关闭 Palette 时清空。

## 17. 验证矩阵与交付证据

### 17.1 单元/契约测试

在不依赖 WoW UI 的 Lua harness 中测试：

- SDK 未 Attach 时注册、Attach 后 drain、重复 ID、版本不兼容、token 注销。
- Entry 字段校验、stableID 去重、tombstone、Provider namespace 隔离。
- Normalizer 的中英文/繁简/拼音/前缀、IntentParser、固定排序 tie-break。
- generation 过期结果丢弃、debounce 合并、deferred 队列去重和 slow 晋级。
- Intent schema、combat policy、secure descriptor 禁止字段和普通 callback xpcall。

### 17.2 游戏内场景

每次常驻路径改动都记录同一客户端、同一角色和同一时长的 baseline/modified：

| 场景 | 必查指标 |
| --- | --- |
| 登录/重载 | 加载错误、Provider 状态、索引构建耗时 |
| 站立空闲 60s | AddOn CPU、Lua 内存、active ticker 必须为 0 |
| 1/20 字符输入 | debounce 次数、generation 丢弃数、结果延迟 |
| 单目标/多目标战斗 | 无全量扫描、secure action 可用性、战斗锁定提示 |
| 1000+ Entry/8 dynamic | candidate 上限、2ms deferred 时间片、帧时间 |
| 关闭/禁用/注销 | timer、driver、事件、ResultRow active 数归零 |

证据至少包含 `/console scriptProfile 1`、`UpdateAddOnCPUUsage()`、
`GetAddOnCPUUsage("Lychee")`、`debugprofilestop()` 的命令、输入、字面输出和退出状态。

### 17.3 交付与同步

源码修改完成后必须按本仓库 `AGENTS.md` 的顺序：`git diff --check` -> 精确暂存 ->
描述性 commit -> 记录 hash -> 复制 `package/Lychee` 与 `package/LycheeSDK` 到正式服
同名目录 -> 比较文件清单和关键文件 SHA-256。文档、`AGENTS.md`、`analyze/`、`.codex/`
不复制。未提交成功时不得复制运行时代码；删除旧文件需先生成删除清单。

## 18. Implementation Order

Implementation follows this dependency order:

1. `LycheeSDK`: version, schema validation, pending registry and no-op host.
2. `LycheeLite`: lifecycle, direct event registration, database defaults and
   error boundary.
3. Host `ProviderRegistry`, `ContextStore`, static index and Intent types.
4. `Bindings.xml`, `KeybindManager` and the hidden/showing Palette state machine.
5. Normalizer, tokenizer, intent parser, candidate retrieval and ranker.
6. Ordinary executor and secure broker descriptor validation.
7. Built-in providers.
8. Documentation examples and external provider compatibility tests.

Each step must leave a loadable addon state. No step introduces a second
provider registration API, a second global keybind mechanism or a second search
ranking path.

## 19. Acceptance Checklist

- [ ] `TOGGLELYCHEE` is the only Lychee global binding.
- [ ] SDK is a separate sibling AddOn and has no UI dependency.
- [ ] Internal and external providers normalize to the same registry shape.
- [ ] Provider registration works before and after host load.
- [ ] Query results are generated through one orchestrator and one ranker.
- [ ] Context invalidation is event-driven and versioned.
- [ ] Search produces Intents; UI does not call arbitrary provider methods.
- [ ] Secure actions use descriptors and the broker, never provider Lua source.
- [ ] A failing provider is isolated without hiding the palette.
- [ ] Hidden palette and idle providers have zero active per-frame work.
- [ ] No Ace3 framework is required by the host or SDK.
- [ ] Packaging copies `Lychee/` and `LycheeSDK/` as sibling AddOns and excludes
      local `AGENTS.md`, `analyze/` and `.codex/` artifacts.
