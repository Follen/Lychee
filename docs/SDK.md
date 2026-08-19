# LycheeSDK 第三方接入设计

> 状态：Proposed Public API v1
>
> 本文定义后续 `LycheeSDK` 实现必须满足的公开契约。当前 change 只交付设计；Lua API 在实现 change 中按本文落地并通过 fixture 验证。

证据基线：wowdoc source `wow-ui-source`，product `retail`，Tag `12.1.0`，commit `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`。本文使用的关键证据为：

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:48`（`canaccesstable`）、`:65`（`canaccessvalue`）、`:263`（`issecretvalue`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:322`（`C_AddOns.IsAddOnLoaded`，返回 `loadedOrLoading` 与 `loaded`）；
- `Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml:4`（`SecureActionButtonTemplate`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua:42`（`Click` 检查 `ScriptedInput`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ForbiddenAspectConstantsDocumentation.lua:19`（`ScriptedInput`/`QueryFocus`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:11`、`:22`、`:39`（`After`、`NewTicker`、`NewTimer` 返回契约）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:20`、`:668`（`ClearFocus`/`SetFocus` 检查 `ScriptedInput`）。

## 1. 接入模型

第三方 AddOn 不需要理解 Lychee 的输入框、索引、排序、结果行或安全按钮。接入只包含四类声明：

```text
Extension
|- RegisterCommand(...)             用户能搜索什么
|- RegisterCapabilityProvider(...)  插件提供什么数据/能力
|- RegisterIntentHandler(...)       选择后执行什么
`- RegisterPanelFactory(...)        复杂交互如何挂载
```

最常见的插件只需注册一个 Extension、一个 IntentHandler 和一个 `row` Command。Command、Provider 和 Intent 分层：Command 是搜索入口，Provider 是可复用数据能力，IntentHandler 是经过校验的动作执行器。

## 2. TOC 与加载顺序

第三方 TOC 声明可选依赖：

```toc
## OptionalDeps: LycheeSDK
```

推荐增加仅供诊断和 LoadOnDemand 发现使用的元数据：

```toc
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Commands: 2
## X-Lychee-Keywords: sample,settings
```

`OptionalDeps` 声明第三方对 `LycheeSDK` 的可选关系，并向客户端提供加载顺序信息；它不保证 SDK 一定存在、启用或成功加载，也不强制用户安装 Lychee。第三方只能以运行时全局表为准，并在入口短路：

```lua
local SDK = _G.LycheeSDK
if not SDK or not SDK:Supports(1, 1) then
    return
end
```

这条路径只跳过 Lychee 集成，不改变第三方 AddOn 自己的功能。SDK 不通过扫描和执行第三方代码补注册；加载状态变化后，由客户端的正常 AddOn 加载流程决定第三方入口是否再次执行。

Lychee Host 自己的 TOC 使用 `## Dependencies: LycheeSDK` 声明硬依赖；Host 启动时仍校验 `_G.LycheeSDK` 和 API 版本。只有第三方 AddOn 使用 `OptionalDeps`。

### 2.1 LoadOnDemand AddOn

LoD AddOn 还可声明：

```toc
## LoadOnDemand: 1
## OptionalDeps: LycheeSDK
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Keywords: sample,settings
```

Host 可在登录期一次性读取 `X-Lychee-*`，建立轻量 LoD 候选。用户选择候选后，Host 才调用 `C_AddOns.LoadAddOn(addonName)`；加载成功后必须出现与元数据一致的已提交 Extension，才算接入成功。缺少发现元数据的 LoD AddOn 不会凭空出现在搜索中，只能由其他已加载入口触发加载。

所有 `X-Lychee-*` 字段都是不可信的字符串提示，不能发布 Command、绕过 schema 校验或代替运行时注册。

## 3. Lychee 如何发现接入

```text
第三方 TOC OptionalDeps
  -> LycheeSDK 创建全局 facade 和私有 registry
  -> 第三方创建 Extension 草稿并提交
  -> committed extension 进入 pending registry
  -> Lychee Host attach
  -> Command Catalog / Capability Broker / Intent Router
```

**已提交的 SDK registry 是“插件已经接入”的唯一事实源。** 草稿、TOC 元数据、AddOn 已启用或 `LoadAddOn` 成功都不等于已经接入。

Lychee 只在登录、诊断页或显式 LoD 加载入口读取以下信息：

- `C_AddOns.GetNumAddOns`
- `C_AddOns.GetAddOnInfo`
- `C_AddOns.GetAddOnMetadata`
- `C_AddOns.GetAddOnDependencies`
- `C_AddOns.IsAddOnLoaded`
- `C_AddOns.LoadAddOn`

`C_AddOns.IsAddOnLoaded` 返回两个 boolean，调用方不得把第一个值直接命名为 `loaded`：

```lua
local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(addonName)
local state
if loaded then
    state = "loaded"
elseif loadedOrLoading then
    state = "loading"
else
    state = "not-loaded"
end
```

AddOn 枚举和元数据读取不得进入每次输入的查询链路。`LoadAddOn` 成功但没有匹配注册时，诊断状态为 `loaded-without-registration`。

本机 SDK 调用不使用 `C_ChatInfo.RegisterAddonMessagePrefix` 或 `C_ChatInfo.SendAddonMessage`。AddonMessage 是客户端间文本消息通道，不承担同一客户端内的注册、查询和函数调用。

## 4. API 版本

SDK 暴露：

```lua
SDK.API_VERSION = 1   -- major：不兼容变更时提升
SDK.API_REVISION = 1  -- 同一 major 内只增加可选能力

SDK:Supports(apiVersion, minApiRevision) -> boolean
```

规则：

- `apiVersion` 必须精确匹配受支持的 major，不能只用 `>=` 判断未来 major。
- 增加可选字段或新方法提升 `API_REVISION`，删除字段、改变类型或改变既有语义提升 `API_VERSION`。
- Extension 的 `minApiRevision` 高于 SDK 时，注册返回 `UNSUPPORTED_API`。
- Host attach 时也声明 major/revision。SDK 支持但 Host revision 不足时，Extension 保留诊断记录，不执行回调，错误为 `INCOMPATIBLE_HOST`。
- 兼容适配只发生在注册/attach 层，不进入搜索热路径。

## 5. 原子注册

注册采用“草稿 + 提交”事务，避免 Command 已经可见而对应 Handler 注册失败：

```lua
local extension, err = SDK:RegisterExtension({
    id = "sample-extension",
    apiVersion = 1,
    minApiRevision = 1,
    title = "Sample Extension",
    version = "1.0.0",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    invalidationKeys = { "items" },
})

if not extension then
    return
end

-- Register* 只写入草稿，不发布到 Host。
extension:RegisterIntentHandler(intentDescriptor)
extension:RegisterCommand(commandDescriptor)

local committed, commitErr = extension:Commit()
if not committed then
    return
end
```

Extension 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | `[a-z0-9][a-z0-9.-]{0,63}`，发布后保持稳定 |
| `apiVersion` | integer | 是 | 当前为 `1` |
| `minApiRevision` | integer | 否 | 默认 `1` |
| `title` | string/locale table | 是 | 用户可见名称；locale table 必须有 `default` |
| `version` | string | 是 | 第三方 AddOn 自己的显示版本，不参与 API 比较 |
| `icon` | texture path/fileID | 否 | 展示图标 |
| `invalidationKeys` | string[] | 否 | 本 Extension 可传给 `Invalidate` 的稳定 key 白名单 |
| `onHostAttached` | function | 否 | Host 可用后的通知 |
| `onHostDetached` | function | 否 | Host 断开后的通知 |
| `onEnabled` | function | 否 | Extension 进入 enabled 后通知 |
| `onDisabled` | function | 否 | Extension 停用后的通知 |

事务规则：

- `RegisterExtension` 校验元数据、预留 ID，并返回状态为 `draft` 的句柄。
- 四种 `Register*` 只向草稿暂存声明；同类 ID 在当前 Extension 内唯一。成功返回只读 declaration token，失败返回 `nil, errorObject`。
- 任一暂存调用失败会使草稿进入 `invalid`，后续只能 `Abort()`；调用方必须重新创建完整草稿。
- `Commit()` 一次性校验交叉引用、版本、schema 和声明上限。成功返回同一个 committed handle 和 `nil`；失败返回 `nil, errorObject`，全部不发布并释放预留 ID。
- Host 尚未 attach 时，成功提交进入 `pending`；Host 已 attach 时立即尝试 attach。
- 提交后注册面关闭，再调用 `Register*` 或 `Commit()` 返回 `REGISTRATION_CLOSED`。运行期变更通过注销并重新注册完成。
- 同 ID 的 committed Extension 不被后来注册覆盖。注销使用句柄身份，不按字符串 ID 删除。

这保证错误不会留下“半个 Extension”。草稿不是已接入状态，也不参与查询。

## 6. Extension 句柄

句柄提供以下窄接口：

```lua
-- draft 状态
extension:RegisterCommand(commandDescriptor)
extension:RegisterCapabilityProvider(providerDescriptor)
extension:RegisterIntentHandler(intentDescriptor)
extension:RegisterPanelFactory(panelDescriptor)
extension:Commit()
extension:Abort()

-- committed 状态
extension:SetEnabled(enabled)
extension:Unregister()
extension:GetState()
extension:Invalidate(key)
extension:QueryCapability(request, contextSnapshot)
```

`GetState()` 返回只读快照，不返回内部表。`Invalidate(key)` 只接受该 Extension 在描述符中声明过的失效 key，Host 合并同帧重复失效。`QueryCapability` 只能在 Host attached 且 Extension enabled 时调用。

`SetEnabled` 只设置第三方自己的 owner-enabled 位。Extension 的实际可用状态是 owner-enabled、用户设置、Host 兼容性和健康熔断的合取；第三方不能用 `SetEnabled(true)` 覆盖用户禁用或 Host 熔断。

句柄不暴露：

- SDK 可变 registry；
- Palette 根 frame 或 CommandCatalog/ContextStore 的可变表；
- `LycheeDB` 或其他 AddOn 的 SavedVariables；
- SecureButton 或属性写入接口；
- 第三方全局快捷键入口。

Lua 插件共享同一进程，错误边界不是安全沙箱。SDK 通过窄接口、校验、私有闭包和状态机限制误用，但不能撤销第三方 AddOn 自己在全局环境中执行 Lua 的能力。

## 7. 公共数据契约

### 7.1 Schema v1

Schema 支持以下形式：

```lua
"string"                 -- string
"integer?"               -- 可选 integer
{ itemID = "integer" }   -- record；默认拒绝未知字段
{ kind = "array", items = "string", maxItems = 20 }
```

基础类型为 `string`、`number`、`integer`、`boolean`、`table` 和 `any`，后缀 `?` 表示可选。locale table 的形状为 `{ default = "Sample", zhCN = "示例" }`，未知 locale 回退到 `default`。

payload、request、result 和动态 item 只能包含 `nil`、boolean、有限 number、string 和无环 plain table；不得包含 function、thread、userdata、Frame、纹理对象或循环引用。注册描述符本身允许在规定字段中放置回调函数。运行时 plain data 默认最大嵌套 8 层、单表 128 个字段；具体 schema 可以进一步收紧。

### 7.2 Secret 与 inaccessible value

每个进入 SDK 边界的 Context 字段、Command 索引字段、Intent payload、capability request/result、动态 item 和诊断字段都必须先经过同一个递归 validator。验证顺序固定：

1. 对当前值先调用 `issecretvalue(value)`；为 true 时立即返回 `SECRET_VALUE`，不得做 `type`、比较、拼接、格式化或记录值本身。
2. 再调用 `canaccessvalue(value)`；为 false 时立即返回 `INACCESSIBLE_VALUE`。
3. 仅在前两步通过后读取 `type(value)`。若是 table，必须先确认 `canaccesstable(value)`；为 false 时返回 `INACCESSIBLE_VALUE`，不得用 `pairs`、`next`、`#` 或索引表。
4. 对可访问 table 执行有界遍历。每个 key 和 value 都从步骤 1 重新递归验证；key 验证完成前，不得用该 key 访问 scratch/seen/path/log 表，也不得把它格式化进错误文本。
5. validator 同时执行 plain-data 类型、循环、深度、字段数和 schema 限制。任何子项失败都拒绝整个边界值，不生成部分副本。

实现骨架：

```lua
local function ValidateBoundaryValue(value, seen, depth)
    if issecretvalue(value) then
        return nil, { code = "SECRET_VALUE", retryable = false }
    end
    if not canaccessvalue(value) then
        return nil, { code = "INACCESSIBLE_VALUE", retryable = false }
    end

    local valueType = type(value)
    if valueType ~= "table" then
        return ValidateScalarType(value, valueType)
    end
    if not canaccesstable(value) then
        return nil, { code = "INACCESSIBLE_VALUE", retryable = false }
    end
    if seen[value] or depth >= 8 then
        return nil, { code = "INVALID_SCHEMA", retryable = false }
    end

    seen[value] = true
    local count = 0
    for key, child in next, value do
        local keyOK, keyErr = ValidateBoundaryValue(key, seen, depth + 1)
        if not keyOK then seen[value] = nil; return nil, keyErr end

        local childOK, childErr = ValidateBoundaryValue(child, seen, depth + 1)
        if not childOK then seen[value] = nil; return nil, childErr end

        count = count + 1
        if count > 128 then
            seen[value] = nil
            return nil, { code = "INVALID_SCHEMA", retryable = false }
        end
    end
    seen[value] = nil
    return true
end
```

生产实现还要拒绝非 plain table/metatable 和未允许的标量类型。错误对象只带稳定 code、边界名和由公开 schema 生成的静态 field ID；不得包含被拒绝的值、动态 key、`tostring(value)` 或由其派生的文本。

secret/inaccessible value 不得进入搜索规范化、alias/token/拼音索引、排序、Intent/secure descriptor、Provider 缓存、recent/favorite、诊断 ring buffer、错误日志或 SavedVariables。ContextStore 在写入切片前执行相同验证；失败字段不发布、不缓存，依赖该字段的 Command 对本 generation 不可用。

### 7.3 ContextSnapshot

回调收到的 ContextSnapshot 是一次查询内稳定的只读视图：

```lua
context:Get("combat", "inCombat")
context:Get("bags", "revision")
context:GetSliceVersion("bags")
```

Command 和 Provider 使用 `contextDependencies = { "bags", "combat" }` 声明所需切片。Host 只准备通过 7.2 节验证的切片，并在提交动态结果时复核其 version。标量直接返回；table 通过只读代理或不可变副本返回。第三方不得保存 ContextSnapshot 作为长期状态，也不得修改其返回表。

## 8. 普通 Command

```lua
local command, err = extension:RegisterCommand({
    id = "open-settings",
    title = "打开 Sample 设置",
    aliases = { "sample", "配置", "选项" },
    keywords = { "settings", "options" },
    presentation = "row",
    contextDependencies = { "combat" },
    availability = function(context)
        return not context:Get("combat", "inCombat")
    end,
    intent = {
        type = "sample-extension.open-settings",
        version = 1,
        payload = {},
    },
})
```

Command ID 只需在当前 Extension 内唯一，Host 生成全局 ID `sample-extension:open-settings`。`title`、alias 和 keyword 在注册期规范化并建立索引。

`availability` 可省略（默认可用），也可使用 Host 定义的声明式条件或快速、无副作用的回调。回调只读取 ContextSnapshot，不调用 Provider、不执行 Intent、不创建 frame。回调报错时本 Command 对本次查询不可用，并记录 `CALLBACK_ERROR`。

`row` Command 必须声明静态 `intent` 或 `intentFactory(context)`，二者只能有一个。工厂返回结构化 Intent，不直接执行动作。

需要组合能力的 dynamic resolver、intent factory 或 Handler 可用当前 Extension 句柄和本次 ContextSnapshot 调用 `QueryCapability`。Command 不保存具体 Provider 回调引用。

## 9. IntentHandler

```lua
extension:RegisterIntentHandler({
    type = "sample-extension.open-settings",
    version = 1,
    schema = {
        itemID = "integer?",
    },
    execute = function(intent, context)
        OpenSampleSettings(intent.payload.itemID)
        return { ok = true, closePalette = true }
    end,
})
```

规则：

- 第三方 Intent type 必须以 `<extensionID>.` 开头并在全局唯一；`lychee.*` 保留给 Host。
- Intent 必须包含 `type`、`version` 和符合 schema 的 `payload`。Host 注入并校验 `extensionID`，第三方不能冒充其他 Extension。
- payload 校验成功后才进入 `execute`；Handler 返回 `ExecutionResult`，不直接操作 Lychee UI。
- 成功返回 `{ ok = true, closePalette = boolean? }`；业务失败返回 `{ ok = false, code = stableCode, messageKey = string? }`。抛错映射为 `CALLBACK_ERROR`。
- 只有 `ok=true` 才写入 recent。`messageKey` 是本地化键，不把异常堆栈直接显示给用户。
- 普通回调由 Host 用局部 `xpcall` 包裹。受保护动作注册声明式 Secure Descriptor；第三方不取得 Host SecureButton。

### 9.1 受保护 Intent

受保护动作不注册普通 `execute` 回调，而是提交 Host allowlist 支持的声明式 Secure Descriptor，例如：

```lua
{
    kind = "spell",
    spellID = 12345,
    unit = "target",
}
```

Host 把 descriptor 规范化为允许的 secure attributes。按钮只由 Host 创建，第三方不接触该对象；以 spell 为例，脱战准备路径为：

```lua
local button = CreateFrame(
    "Button",
    "LycheeSecureActionButton1",
    secureHostFrame,
    "SecureActionButtonTemplate"
)

-- 以下创建、点击注册和属性写入都只在 InCombatLockdown() == false 时执行。
button:RegisterForClicks("LeftButtonUp")
button:SetAttribute("type", "spell")
button:SetAttribute("spell", normalizedSpellID)
button:SetAttribute("unit", normalizedUnit)
```

Host 必须在脱战时完成按钮创建、`RegisterForClicks`、attribute 清理/写入、锚点和显示状态准备；descriptor 或上下文变化后重新准备，也只能走脱战路径。进入战斗后不写 `type`、`spell`、`item`、`macrotext`、`unit` 或其他 protected attributes，不替换脚本，不重新挂载按钮。

动作执行要求用户在按钮上完成真实鼠标/按键点击。输入框 Enter、`dispatchIntent`、普通 Lua 回调和 `button:Click()` 都不能替代真实输入；官方 `SimpleButtonAPI.Click` 检查 `Enum.ForbiddenAspect.ScriptedInput`。脚本调用只可用于普通非受保护按钮，不得作为 secure action 的执行路径。

本产品当前在战斗中关闭 Palette，因此这些按钮只在脱战 Palette 会话中展示；若战斗开始，按 14 节统一关闭并取消会话。战斗期间收到受保护 Intent 直接返回 `COMBAT_LOCKED`，不自动执行，也不保留一个会在脱战时替用户执行的点击。

第三方始终只接触 Descriptor 和执行结果，不接触 SecureButton、protected attributes 或脚本字符串。该约束以 wowdoc retail `12.1.0`、源提交 `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b` 的 secure button 与 `ScriptedInput` 规则为设计证据。

## 10. 动态列表

动态列表适用于背包物品、队伍成员、装备方案和配置项等运行时数据：

```lua
extension:RegisterCommand({
    id = "find-item",
    title = "查找物品",
    aliases = { "物品", "item" },
    presentation = "dynamic-list",
    contextDependencies = { "bags" },

    resolve = function(query, context, runtime)
        local items = SearchOwnInventory(query.normalized, query.limit)
        return items
    end,

    itemIntent = function(item, context)
        return {
            type = "sample-extension.use-item",
            version = 1,
            payload = { itemID = item.payload.itemID },
        }
    end,
})
```

`query` 的 v1 形状：

```lua
{
    generation = 1042,
    raw = "item sword",
    normalized = "item sword",
    tokens = { "item", "sword" },
    limit = 20,
    deadlineMS = 8,
    contextToken = opaqueReadOnlyToken,
}
```

Item 形状：

```lua
{
    id = "item-19019",
    text = "雷霆之怒，逐风者的祝福之剑",
    subtext = "背包 1",
    icon = 135349,
    enabled = true,
    payload = { itemID = 19019 },
}
```

Lychee 负责输入 debounce、generation、结果行池化和 diff、键鼠导航、滚动、选中态、空/加载/错误状态，以及 item Intent 路由。Host 只接受当前 generation、相同 `contextToken`、稳定且唯一 item ID 的结果，超过 `query.limit` 的尾项被截断并记录诊断。

Resolver 只读取 query 和 ContextSnapshot，不创建 frame、不注册事件、不执行动作。结果变化由已声明的 `Invalidate(key)` 或 Context slice version 驱动，不靠轮询。

### 10.1 协作式 deferred resolver

同步 resolver 必须快速返回。需要分批处理时，使用本次调用的临时 `runtime`：

```lua
resolve = function(query, context, runtime)
    local cursor = 1
    local items = {}

    return runtime:Defer(function(task)
        if task:IsCancelled() then
            return true, nil
        end

        cursor = ProcessBoundedBatch(cursor, items)
        if cursor == nil then
            return true, items   -- 完成
        end
        return false             -- 让出，下一时间片继续
    end)
end
```

`runtime:Defer(step)` 返回只属于当前查询的 DeferredResult。Host 仅在 Palette 可见时调度 step；新 generation、Context 依赖变化、Palette 关闭、Extension 停用或注销都会取消 task。取消后不再调用 step，迟到结果丢弃。step 每次只处理有界批次；它不是后台线程，也不能让长同步 Lua 自动变成可抢占任务。

step 的返回约定固定为：`false` 表示让出并继续；`true, items` 表示成功完成；`nil, errorObject` 表示失败。取消时允许返回 `true, nil`，Host 将其记为取消而不是空结果。

`deadlineMS` 是测量和调度预算，不是硬超时。WoW Lua 无法安全抢占正在运行的第三方回调；Host 只能在回调返回后记录超时，并降低或停止后续调用。

## 11. CapabilityProvider

Provider 提供可复用能力，不作为搜索入口：

```lua
extension:RegisterCapabilityProvider({
    id = "item-source",
    type = "inventory.items",
    version = 1,
    priority = 0,
    contextDependencies = { "bags" },
    requestSchema = {
        text = "string",
        limit = "integer?",
    },
    resultSchema = {
        kind = "array",
        items = { itemID = "integer", name = "string" },
        maxItems = 20,
    },
    query = function(request, context)
        return SearchOwnInventory(request.text, request.limit)
    end,
})
```

平台定义的 capability type（例如 `inventory.items`）由 Lychee 文档规定 schema 和语义。第三方自定义 type 必须以 `<extensionID>.` 开头。Provider ID 在 Extension 内唯一。

消费者通过 Broker 调用，不持有 Provider 函数：

```lua
local result, queryErr, providerInfo = extension:QueryCapability({
    type = "inventory.items",
    minVersion = 1,
    maxVersion = 1,
    request = { text = "sword", limit = 10 },
}, context)
```

Broker 先校验 request，再按兼容版本、用户默认、availability、priority 和稳定全局 ID 选择一个 Provider，最后校验 result。成功返回 `result, nil, { extensionID, providerID, version }`；失败返回 `nil, errorObject`。递归调用带调用栈和深度上限，环依赖返回 `CALL_DEPTH_EXCEEDED`。

Provider 错误只影响本次 request。v1 Provider 同步返回；昂贵数据应由事件驱动缓存或预索引，不能在一次 capability 调用中启动无界扫描。

## 12. Custom Panel

Custom Panel 适用于确实需要表单、分页、按钮组或复杂状态的交互。普通命令和可枚举数据优先使用 `row` 或 `dynamic-list`。

```lua
extension:RegisterPanelFactory({
    id = "profile-editor",
    contextDependencies = { "combat" },
    create = function()
        local panel = {}

        function panel:Mount(context)
            if not self.frame then
                self.frame = CreateFrame("Frame", nil, context.contentFrame)
                self.frame:SetAllPoints(context.contentFrame)
            elseif self.frame:GetParent() ~= context.contentFrame then
                self.frame:SetParent(context.contentFrame)
                self.frame:SetAllPoints(context.contentFrame)
            end

            self.context = context
            self.frame:Show()
            self.refreshTimer = context.timer:After(0.25, function()
                if not context:IsActive() then return end
                RefreshPanel(self)
            end)
        end

        function panel:Update(state)
            -- 依据 state.reason/context/width/height 增量更新。
        end

        function panel:Unmount(reason)
            -- 注销 Panel 自己注册的事件，并取消全部托管句柄。
            if self.refreshTimer then
                self.refreshTimer:Cancel()
                self.refreshTimer = nil
            end
            if self.frame then self.frame:Hide() end
            self.context = nil
        end

        function panel:Dispose()
            -- Extension 注销时解除脚本和大型引用，并把可复用对象交回池。
        end

        return panel
    end,
})

extension:RegisterCommand({
    id = "edit-profile",
    title = "编辑 Sample 配置",
    presentation = "custom-panel",
    panel = "profile-editor",
})
```

Host 在第一次打开时惰性调用一次 `create`，缓存该 panel 实例并在后续打开时复用。成功 `Mount` 后必有且仅有一次对应 `Unmount`；Extension 注销时在 Unmount 后调用一次可选 `Dispose`。Mount 或 Update 报错时，Host 执行尽力 Unmount、关闭 ViewHost，并记录 `PANEL_ERROR`。

`PanelContext` 只在当前 Mount 期间有效：

```lua
{
    contentFrame = hostOwnedFrame,
    width = 560,
    height = 360,
    context = readOnlyContextSnapshot,
    close = function() end,
    invalidate = function(reason) end,
    requestFocus = function(descendantFrame) end,
    dispatchIntent = function(intent) end,
    generation = 17,
    IsActive = function(self) return boolean end,
    timer = {
        After = function(self, seconds, callback) return CancelHandle end,
        NewTicker = function(self, seconds, callback, iterations) return CancelHandle end,
    },
}
```

`invalidate` 合并同帧请求，并以如下状态调用 `Update`：

```lua
{
    reason = "data-changed",
    width = 560,
    height = 360,
    context = freshReadOnlyContextSnapshot,
}
```

所有权规则：

- 第三方只在 `contentFrame` 下创建子 frame；`requestFocus` 只接受其后代区域。
- Host 管理 Palette 根 frame、ViewHost 尺寸、层级、Esc、best-effort 焦点恢复和关闭。
- Panel 按钮需要触发 Lychee 动作时使用 `dispatchIntent`，不能直接调用 Host Handler。战斗中 Palette 已关闭，任何迟到或绕过入口的受保护 Intent 都返回 `COMBAT_LOCKED`；9.1 节的安全按钮只在脱战会话中可见。
- `close`、`invalidate`、`requestFocus`、`dispatchIntent` 和 timer callback 都绑定当前 generation。Unmount 后控制方法返回 `INVALID_STATE`，`IsActive()` 返回 false。
- Palette 隐藏、切换 Command、Extension 禁用/注销和 Panel 错误都会触发 Unmount。
- `context.timer:After` 和 `NewTicker` 返回幂等 `CancelHandle`，至少提供 `Cancel()` 和 `IsCancelled()`。Host 的 `After` 使用 `C_Timer.NewTimer` 实现，`NewTicker` 使用 `C_Timer.NewTicker` 实现，均不直接转发裸 `C_Timer.After`；Host 跟踪当前 Mount 创建的全部句柄，并在 Unmount 前统一取消，取消后 callback 不再进入第三方代码。
- `runtime:Defer` 是 dynamic resolver 的分帧工作队列，不是 Timer/Ticker，不能用于等待墙钟时间；Panel 的延时和周期任务只用 `context.timer`。
- 不推荐 Panel 直接调用 `C_Timer.After`，因为它不返回可取消句柄。确需调用时必须捕获 Mount generation，并在 callback 第一行同时检查 generation 和 active；失效后只 return，不访问 frame、ContextSnapshot 或 Host：

```lua
local generation = context.generation
C_Timer.After(0.25, function()
    if context.generation ~= generation or not context:IsActive() then return end
    RefreshPanel(self)
end)
```

- 第三方直接创建的 `C_Timer.NewTimer`/`NewTicker` 句柄由第三方保存并在 Unmount 中 `Cancel()`；Host 只保证取消 `context.timer` 创建的托管句柄。
- Panel 可复用隐藏 frame，但不得在每次 Mount 无界创建新 frame。Lychee 唯一全局 Binding 是 `TOGGLELYCHEE`；第三方不得为 Lychee 注册额外入口，只能使用 Panel 可见期间的 frame-local 输入。

## 13. 生命周期

```text
draft -> pending -> registered -> enabled -> slow/disabled
                                      `----> retiring -> removed
```

- `draft`：声明暂存，尚未接入。
- `pending`：已原子提交，Host 尚未 attach，或 attach 因 Host revision 不足而等待兼容 Host。
- `registered`：Host 已建立索引，尚未启用。
- `enabled`：Command、Provider、Handler 和 Panel 可以参与运行。
- `slow`：仍是已注册实例，但调度被降频；达到熔断条件可进入 disabled。
- `disabled`：本会话不再调用；保留注册和诊断，可显式重新启用。
- `retiring`：新查询已停止，等待 generation、Panel 和 Host 托管任务清理。
- `removed`：从 registry 和索引移除，旧句柄失效。

Host attach 时按 Extension ID 稳定排序消费 pending。Host 已就绪时，新提交立即 attach。生命周期回调由 SDK 在局部错误边界中调用：

```lua
onHostAttached = function(hostInfo)
    -- hostInfo 含 API major/revision 和只读 feature flags。
end
onHostDetached = function(reason) end
onEnabled = function() end
onDisabled = function(reason) end
```

attach 回调顺序固定为 `onHostAttached -> onEnabled`；detach 时若当前 enabled，则按 `onDisabled(reason) -> onHostDetached(reason)` 执行。Host detach 后，Extension 停止所有 Host 托管任务并回到 pending；下一个兼容 Host attach 后可再次注册和启用。

`Unregister()` 幂等：第一次调用进入 retiring，后续调用返回同一状态。它只清理 Lychee 接入，不卸载第三方 AddOn，也不删除第三方 SavedVariables。生命周期回调报错只记录 `CALLBACK_ERROR`，状态机仍继续完成清理。

## 14. Binding、焦点与战斗策略

Lychee 只声明一个全局 Binding：`TOGGLELYCHEE`。Host TOC 加载 `Bindings.xml`，文件内容为：

```toc
Bindings.xml
```

```xml
<Bindings>
    <Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">
        Lychee_Toggle()
    </Binding>
</Bindings>
```

Host 在加载期定义标准显示字符串和唯一入口：

```lua
BINDING_HEADER_LYCHEE = "Lychee"
BINDING_NAME_TOGGLELYCHEE = "打开/关闭 Lychee"

function Lychee_Toggle()
    if InCombatLockdown() then
        return -- 静默：不改变任何 Palette 状态。
    end
    Lychee.Host:TogglePalette("binding")
end
```

第三方 Extension 不得添加 `TOGGLELYCHEE` 的同名声明、额外 Lychee Binding、`SetBinding`/`SetOverrideBinding` 接管或独立全局快捷键。第三方 Panel 只在已 Mount 且可见期间使用 frame-local 键盘/鼠标脚本；Esc、Enter、Tab 和上下键冲突由 Host 状态机裁决。

### 14.1 战斗状态机

- `TOGGLELYCHEE` 的处理函数第一步检查 `InCombatLockdown()`。战斗中调用静默返回：不打开、不关闭、不改变文本或 selection、不读取/移动焦点、不增加 query generation、不启动 debounce/resolver/deferred/timer。
- Host 注册 `PLAYER_REGEN_DISABLED`。若 Palette 已打开，统一执行 `Close("combat")`：先让当前 Panel `Unmount("combat")`，取消 Panel 托管 Timer/Ticker、resolver deferred、debounce 和待发布结果，使当前 generation 失效，best-effort 清空 Lychee 输入焦点，然后关闭 Palette。
- 战斗关闭流程不执行 Intent、不准备/修改 secure descriptor 和 secure attributes。受限的 secure frame 变更保留 dirty 标记，等 `PLAYER_REGEN_ENABLED` 后再处理；关闭 Palette 本身不能依赖这些变更成功。
- `PLAYER_REGEN_ENABLED` 自动重新启用 `TOGGLELYCHEE` 的正常处理，并处理允许的 dirty cleanup/secure preparation。它不自动重新打开 Palette，也不恢复战斗前 query；用户下一次按键创建全新 generation。
- 其他代码入口调用 `TogglePalette`/`OpenPalette` 时复用同一 combat guard，不能绕过 Binding 策略。

### 14.2 焦点恢复

打开 Palette 时，Host 只在焦点查询可访问且返回对象适合恢复时保存旧焦点，然后聚焦 Lychee 输入框。关闭时先清除 Lychee 输入焦点，再 best-effort 恢复：旧对象仍有效、可见、可聚焦且相关访问未被 `ScriptedInput`/`QueryFocus` 限制时才调用其 `SetFocus`。

焦点对象不可访问、已隐藏、已失效，或 `SetFocus` 被限制/报错时，Host 保持焦点清空并完成关闭；焦点恢复失败不回滚 Unmount、任务取消或 Palette 状态。战斗静默 toggle 完全不查询或保存焦点；`PLAYER_REGEN_DISABLED` 的强制关闭也不以焦点恢复成功作为完成条件。

## 15. 错误对象与错误码

所有失败返回 `nil, errorObject` 或 `false, errorObject`：

```lua
{
    code = "DUPLICATE_ID",
    extensionID = "sample-extension",
    field = "id",
    retryable = false,
}
```

公开稳定错误码：

| Code | 含义 |
| --- | --- |
| `INVALID_SCHEMA` | 字段类型、必填项、plain-data 限制或字段组合无效 |
| `SECRET_VALUE` | SDK 边界值或其任意后代为 secret；整个值被拒绝且不记录内容 |
| `INACCESSIBLE_VALUE` | 调用方不能访问值或索引 table；整个值被拒绝且不记录内容 |
| `DUPLICATE_ID` | ID 已被 committed Extension 或活动草稿占用 |
| `UNSUPPORTED_API` | SDK API major/revision 不受支持 |
| `INCOMPATIBLE_HOST` | Host API revision 低于声明要求 |
| `REGISTRATION_CLOSED` | 在 Commit/Abort 后继续修改注册 |
| `INVALID_STATE` | 当前句柄或 Panel 代次不允许此操作 |
| `HOST_UNAVAILABLE` | 操作需要 attached Host |
| `EXTENSION_DISABLED` | Extension 当前停用 |
| `COMMAND_NOT_FOUND` | Command 或 Panel 引用不存在 |
| `CAPABILITY_NOT_FOUND` | 没有兼容且可用的 Provider |
| `CALL_DEPTH_EXCEEDED` | capability 调用过深或出现环依赖 |
| `PROVIDER_TIMEOUT` | Provider/resolver 返回后测得超出软预算 |
| `PROVIDER_ERROR` | Provider/resolver 回调报错或返回值无效 |
| `RESULT_LIMIT` | 结果超出声明上限并被拒绝或截断 |
| `STALE_GENERATION` | 结果属于旧输入或旧 Context token |
| `INTENT_INVALID` | Intent type、version 或 payload 无效 |
| `COMBAT_LOCKED` | 当前战斗策略不允许执行 |
| `INVALID_SECURE_DESCRIPTOR` | 声明式受保护动作无效 |
| `PANEL_ERROR` | Panel create/Mount/Update/Unmount/Dispose 报错 |
| `CALLBACK_ERROR` | 普通或生命周期回调报错 |

错误码语义在同一 API major 内保持稳定。`retryable` 只描述重新发起是否可能成功，不代表 SDK 会自动重试。SDK 不对报错 resolver 自动循环重试；下一次输入、显式 invalidation 或用户操作才产生新调用。

## 16. 性能要求

第三方接入必须满足：

- 注册期不为 Lychee 创建常驻 `OnUpdate`；不在每次按键重新注册 Command 或 Provider。
- Resolver 不扫描所有 AddOn、不创建 frame、不执行 Intent；每个动态结果集默认最多 20 项。
- availability 快速、无副作用；Provider 使用事件驱动缓存或有界查询。
- Panel 实例和 frame 复用，隐藏后停止事件、ticker、timer 和输入脚本。
- 稳定数据通过 Context slice 或显式 `Invalidate` 更新，不轮询“确保最新”。
- AddOn 枚举、schema 校验和索引构建只发生在加载/注册/诊断入口。
- 第三方回调不得依赖硬超时保护；单次长 Lua 回调仍会阻塞游戏主线程。
- payload 和 capability result 不携带 Frame、函数、大型 SavedVariables 子树或无界集合。
- secret/inaccessible validator 在索引、复制和日志之前运行，命中后立即短路，不尝试格式化被拒绝值。

Host 使用固定容量计数器/ring buffer 记录调用次数、平均/峰值耗时、错误和过期 generation。连续超预算可令 Extension 进入 `slow`，继续超预算或连续报错可触发本会话 disabled；阈值由 Host 版本统一定义并在诊断页展示，不能由 Provider priority 绕过。

## 17. 完整最小示例

```lua
local SDK = _G.LycheeSDK
if not SDK or not SDK:Supports(1, 1) then return end

local Extension, err = SDK:RegisterExtension({
    id = "sample-extension",
    apiVersion = 1,
    minApiRevision = 1,
    title = "Sample Extension",
    version = "1.0.0",
})
if not Extension then return end

local handler, handlerErr = Extension:RegisterIntentHandler({
    type = "sample-extension.print",
    version = 1,
    schema = { text = "string" },
    execute = function(intent)
        print(intent.payload.text)
        return { ok = true }
    end,
})
if not handler then
    Extension:Abort()
    return
end

local command, commandErr = Extension:RegisterCommand({
    id = "hello",
    title = "Sample: Hello",
    aliases = { "hello", "你好" },
    presentation = "row",
    intent = {
        type = "sample-extension.print",
        version = 1,
        payload = { text = "Hello from Sample" },
    },
})
if not command then
    Extension:Abort()
    return
end

local committed, commitErr = Extension:Commit()
if not committed then
    -- 整个 Extension 均未发布。
    return
end
```

实现阶段的 SDK fixture 必须验证：

1. SDK 先加载、Host 后 attach，committed pending 被完整消费；
2. Host 先 attach、第三方后提交，Extension 立即 attach；
3. 草稿未 Commit 不可见，子声明失败和 Commit 失败均无部分注册；
4. 重复 ID、版本不兼容、交叉引用错误和声明数量超限；
5. LoD AddOn 加载成功但未注册时为 `loaded-without-registration`；
6. dynamic-list 旧 generation/Context token 不覆盖新输入；
7. deferred task 在新输入和 Palette 关闭后不再执行；
8. custom-panel 的惰性创建、复用、Mount/Update/Unmount/Dispose 和异常清理；
9. 一个第三方回调报错时，其他 Extension 和 Palette 仍可用；
10. 本机 SDK 路径没有使用 AddonMessage；
11. secret value、不可访问标量、不可索引 table、secret key 和嵌套 secret child 均在复制/索引/日志前被拒绝，错误记录不包含原值；
12. `C_AddOns.IsAddOnLoaded` 的 loading 与 loaded 状态按两个返回值区分；
13. Panel 托管 Timer/Ticker 在 Unmount 时取消，raw `C_Timer.After` 的旧 generation callback 只 return；
14. 战斗中 `TOGGLELYCHEE` 不改变 UI、焦点、generation 和任务数量；已打开 Palette 在 `PLAYER_REGEN_DISABLED` 完整关闭；
15. `PLAYER_REGEN_ENABLED` 自动恢复 Binding 处理但不自动重开旧会话，焦点恢复失败不阻塞关闭；
16. secure descriptor 只在脱战准备，真实点击触发动作，脚本 `Click()` 不作为 secure execution。

## 18. 接入检查清单

- [ ] TOC 使用 `## OptionalDeps: LycheeSDK`，SDK 缺席时只跳过 Lychee 接入。
- [ ] Extension 在所有子声明成功后调用一次 `Commit()`。
- [ ] Extension、Command、Provider、Intent type 和 item 使用稳定 ID。
- [ ] 第三方 Intent/custom capability type 使用自己的 Extension ID 前缀。
- [ ] 普通动作使用结构化 Intent，payload 只含有界 plain data。
- [ ] Context、payload、request/result、item 和诊断字段先递归拒绝 secret/inaccessible value。
- [ ] dynamic-list 返回稳定 item ID，不创建结果行 frame。
- [ ] Provider 不作为搜索入口，不绘制 UI，并通过 Broker 调用。
- [ ] custom-panel 只在 `contentFrame` 下创建子 frame 并复用实例。
- [ ] Panel 在所有退出路径停止自身事件并取消托管 Timer/Ticker；raw `C_Timer.After` 有 generation/active guard。
- [ ] Resolver、Provider 和 availability 没有执行副作用或无界同步工作。
- [ ] 插件没有在唯一的 `TOGGLELYCHEE` 之外为 Lychee 注册额外全局快捷键。
- [ ] Host 的 `TOGGLELYCHEE` 在战斗中静默，战斗开始关闭已有 Palette，脱战后自动恢复入口。
- [ ] Secure Descriptor 只由 Host 脱战配置，执行依赖真实点击而不是脚本 `Click()`。
- [ ] AddonMessage 没有被用作本机 SDK RPC。
