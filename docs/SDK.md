# LycheeSDK 第三方接入设计

> 状态：Proposed Public API v1
>
> 本文定义 Lychee 本体暴露的 `LycheeSDK` 公共 API 必须满足的契约。SDK 不是独立运行时 AddOn；第三方插件把接入代码集成到自己的 AddOn 中，由 Lychee Host 提供实际注册、搜索、Panel 和执行能力。

证据基线：wowdoc source `wow-ui-source`，product `retail`，Tag `12.1.0`，commit `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`。本文使用的关键证据为：

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:48`（`canaccesstable`）、`:65`（`canaccessvalue`）、`:263`（`issecretvalue`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:322`（`C_AddOns.IsAddOnLoaded`，返回 `loadedOrLoading` 与 `loaded`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:928`（`C_Spell.PickupSpell`）与 `Interface/AddOns/Blizzard_ActionBar/Shared/SpellFlyout.lua:71-76`（暴雪从真实 `OnDragStart` 取起法术）；
- `Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml:4`（`SecureActionButtonTemplate`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua:42`（`Click` 检查 `ScriptedInput`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ForbiddenAspectConstantsDocumentation.lua:19`（`ScriptedInput`/`QueryFocus`）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:11`、`:22`、`:39`（`After`、`NewTicker`、`NewTimer` 返回契约）；
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:20`、`:668`（`ClearFocus`/`SetFocus` 检查 `ScriptedInput`）。

## 1. 接入模型

第三方 AddOn 不需要理解 Lychee 的输入框、索引、排序、结果行或安全按钮。接入只包含四类声明：

```text
Extension
|- RegisterCommand(...)             固定命令入口和动作
|- RegisterSearchSource(...)        统一收录可搜索实体
|- RegisterCapabilityProvider(...)  插件提供什么数据/能力
|- RegisterIntentHandler(...)       选择后执行什么
`- RegisterPanelFactory(...)        复杂交互如何挂载
```

最常见的插件只需注册一个 Extension、一个 SearchSource（或固定 `row` Command）、一个 IntentHandler 和需要的 Panel。SearchRecord 是统一搜索对象；Command 是固定命令入口，CapabilityProvider 是可复用能力，IntentHandler 是经过校验的动作执行器。

第三方接入必须由第三方 AddOn 主动完成：取得 Lychee 本体暴露的 `_G.Lychee` 公共 facade，创建 Extension 草稿，注册全部子声明，最后调用 `Commit()`。Lychee 不扫描插件目录来猜测或补造接入。实体搜索应注册 SearchSource；CapabilityProvider 仍只发布可复用能力，若要通过动态 resolver 查询它，才额外注册 `ambient` `dynamic-list` Command。

## 2. TOC 与加载顺序

第三方 TOC 声明可选依赖：

```toc
## OptionalDeps: Lychee
```

推荐增加仅供诊断和 LoadOnDemand 发现使用的元数据：

```toc
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Commands: 2
## X-Lychee-Keywords: sample,settings
```

`OptionalDeps` 声明第三方对 Lychee 本体的可选关系，并向客户端提供加载顺序信息；它不保证 Lychee 一定存在、启用或成功加载。第三方只能以运行时公共 facade 为准。推荐把完整注册事务封装成幂等函数；下面的 `MyAddon_RegisterLycheeExtension` 代表完整注册示例返回的 committed handle：

```lua
local integrationState = "idle"
local recordedDiagnostics = {}

local function RecordOnce(code)
    if recordedDiagnostics[code] then return end
    recordedDiagnostics[code] = true
    MyAddon_RecordDiagnostic(code)
end

local function TryRegisterLychee()
    if integrationState == "committed" then return true end
    local Lychee = _G.Lychee
    if not Lychee then return false, "SDK_UNAVAILABLE" end
    if not Lychee:Supports(1, 1) then
        integrationState = "unsupported"
        RecordOnce("UNSUPPORTED_API")
        return false, "UNSUPPORTED_API"
    end
    local committed, err = MyAddon_RegisterLycheeExtension(Lychee)
    if not committed then
        integrationState = "failed"
        RecordOnce(err and err.code or "REGISTRATION_FAILED")
        return false, err and err.code or "REGISTRATION_FAILED"
    end
    integrationState = "committed"
    return true
end

local registered, reason = TryRegisterLychee()
if not registered and reason == "SDK_UNAVAILABLE" then
    RecordOnce("SDK_UNAVAILABLE")
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ADDON_LOADED")
    listener:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= "Lychee" then return end
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
        TryRegisterLychee()
    end)
end
```

这条路径只跳过 Lychee 集成，不改变第三方 AddOn 自己的功能。`SDK_UNAVAILABLE` 只表示 facade 暂时缺席；`UNSUPPORTED_API` 表示当前 PublicAPI 不支持声明的 API major/minimum revision。事件监听只在 facade 缺席时创建，命中 `ADDON_LOADED("Lychee")` 后先注销再调用幂等注册函数；PublicAPI 已出现但版本不支持或注册失败时，不等待另一次加载事件，也不轮询。诊断按 code 去重，SDK 不扫描或执行第三方代码补注册。

这里的“SDK 缺席”指 Lychee 本体没有暴露兼容的公共 facade，不是缺少一个名为 `LycheeSDK` 的独立 AddOn。Lychee 本体提供 SDK 的实现、registry、Host UI 和执行路由；第三方只把集成代码放进自己的 AddOn。

双方的有效加载顺序都必须工作：

1. **第三方先、Lychee 后：** `_G.Lychee` 不存在时监听 `ADDON_LOADED` 的 `Lychee`；facade 出现后立即创建 draft 并 `Commit()`。Host 尚未 ready 时 Extension 进入 pending，ready 后转为 registered。
2. **Lychee 先、第三方后：** facade 已存在时可立即 `Commit()`；Host 已 ready 时 Extension 立即注册并可被搜索。

`OptionalDeps` 正常情况下会让 Lychee 先于第三方加载；第一种顺序仍用于 LoD AddOn、运行期加载和测试夹具。无论顺序如何，唯一完成条件都是 Extension 已 Commit 并进入 Lychee registry，而不是 TOC 元数据或 AddOn loaded 状态。

Lychee 本体不依赖另一个 SDK AddOn；它在自己的加载流程中创建 `_G.Lychee` 和 API 版本信息。只有第三方 AddOn 使用 `OptionalDeps: Lychee`。

第三方必须处理加载竞态：公共 facade 已存在时直接注册；尚未存在时监听 `ADDON_LOADED` 的 `Lychee`。`RegisterReady(callback)` 只能在 facade 已存在后调用，用于 ready 通知，不是 `Commit()` 的前置条件。Lychee 不扫描第三方代码，也不要求第三方轮询。

### 2.1 LoadOnDemand AddOn

LoD AddOn 还可声明：

```toc
## LoadOnDemand: 1
## OptionalDeps: Lychee
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Keywords: sample,settings
```

Host 可在登录期一次性读取 `X-Lychee-*`，建立轻量 LoD 候选。用户选择候选后，Host 才调用 `C_AddOns.LoadAddOn(addonName)`；加载成功后必须出现与元数据一致的已提交 Extension，才算接入成功。缺少发现元数据的 LoD AddOn 不会凭空出现在搜索中，只能由其他已加载入口触发加载。

所有 `X-Lychee-*` 字段都是不可信的字符串提示，不能发布 Command、绕过 schema 校验或代替运行时注册。

## 3. Lychee 如何发现接入

```text
Lychee 本体加载
  -> 创建 _G.Lychee 公共 facade 和私有 registry
第三方 AddOn 集成代码
  -> 取得 _G.Lychee
  -> 创建 Extension 草稿并提交
  -> Lychee registry 接收 committed Extension
  -> Command Catalog / Capability Broker / Intent Router / ViewHost
```

**Lychee 本体的 ExtensionRegistry 是“插件已经接入”的唯一事实源。** 草稿、TOC 元数据、AddOn 已启用或 `LoadAddOn` 成功都不等于已经接入。Lychee 不从 Provider registry 自动生成 Command；没有 committed Command 的 Provider 只能由其他已注册声明通过 Capability Broker 调用，不能响应主输入框。

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
- Lychee Host ready 时也声明 major/revision。SDK 支持但 Host revision 不足时，Extension 保留诊断记录，不执行回调，错误为 `INCOMPATIBLE_HOST`。
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
- Lychee facade 尚未 ready 时，成功提交进入 `pending`；Lychee 已 ready 时立即注册。
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
extension:GetSearchSource(sourceID)
```

`GetState()` 返回只读快照，不返回内部表。`Invalidate(key)` 只接受该 Extension 在描述符中声明过的失效 key，并只推进本 Extension 自己的 Source revision/generation。`QueryCapability` 只能在 Lychee Host ready 且 Extension enabled 时调用。`GetSearchSource(sourceID)` 返回 Host 校验过的窄 source handle，不暴露 SearchIndex。

`SetEnabled` 只设置第三方自己的 owner-enabled 位。Extension 的实际可用状态是 owner-enabled、用户设置、Host 兼容性和健康熔断的合取；第三方不能用 `SetEnabled(true)` 覆盖用户禁用或 Host 熔断。

`GetState()` 至少返回 `lifecycle`、`ownerEnabled`、`userEnabled`、`hostAttached`、`effectiveEnabled` 和最后一个稳定错误码。`SetEnabled(false)` 立即停止该 Extension 的新 Command/Provider 调度，并使活动 generation、deferred resolver 和待处理 transition 失效；再次设为 true 只恢复 owner-enabled 位，仍要经过用户设置、Host 兼容性和健康状态判断。

`Unregister()` 幂等。第一次调用把句柄推进到 `retiring` 并开始清理，后续调用返回相同句柄状态，不重复触发生命周期回调；完成后为 `removed`。旧句柄不能删除后来使用同一字符串 ID 注册的 Extension，也不能在 removed 后重新启用。

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

### 7.2 Locale 与搜索别名

所有用户可见 title 使用 string 或 locale table；Host 在加载期读取一次 `GetLocale()`，按“当前 locale -> `default`”选择显示值。Command 的 `aliases`/`keywords` 以及 Provider 自有实体索引可以使用两种别名形状：

```lua
aliases = {
    "fallback-alias",                       -- 等价于 locale = "default"
    { text = "翅膀", locale = "zhCN" },    -- 复仇之怒的中文俗称
    { text = "wings", locale = "enUS" },
}
```

`locale` 必须是 Host 支持的 WoW locale token 或 `default`。Host 只将当前 locale 和 `default` 的别名送入 Normalizer/Tokenizer/拼音索引；其他 locale 保留在注册数据中但不参与本次客户端搜索。别名必须是有限 plain data，按第 7.3 节的顺序先拒绝 secret/inaccessible 值，再做长度、数量、重复项和 locale token 校验。

Provider 的实体别名由 Provider 在注册或数据更新时索引到 canonical stable item ID，resolver 只查询该预索引。命中别名仍返回当前 locale 的 canonical 名称和同一个 item ID；不得为“复仇之怒”和“翅膀”创建两个结果，也不得在每次按键临时翻译、扫描全表或调用网络/生成式模型。规范化后同名的多个实体作为多个候选交给 Host 稳定排序，索引不能用覆盖写入丢弃其中任意实体。

### 7.3 Secret 与 inaccessible value

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

### 7.4 ContextSnapshot

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

Command ID 只需在当前 Extension 内唯一，Host 生成全局 ID `sample-extension:open-settings`。`title`、alias 和 keyword 按第 7.2 节的 locale 规则在注册期规范化并建立索引。

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
- Handler 返回业务失败、抛错、非法结果或 transition 校验失败时，IntentRouter 统一结束本次 busy 状态，发布一条 Host 所有的错误行，并停止当前 Intent；不会留下 busy 锁、重复错误行或半挂载 Panel。错误行使用稳定 `code`/`messageKey`，不展示异常堆栈。
- 成功结果还可包含声明式 `transition`，当前 v1 只支持 `{ type = "custom-panel", panelFactoryID = string, state = plainData }`。Handler 不直接调用 ViewHost 或 PanelFactory。
- Host 只接受当前 Extension 拥有且已启用的 PanelFactory，并复核当前 Palette session、query generation 和 Context token。`transition.state` 必须通过目标 Panel 的 `stateSchema` 以及 7.2 节的 plain-data、secret/inaccessible、深度和字段数校验；任一失败都不 Mount Panel。
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
    match = { type = "catalog" },
    contextDependencies = { "bags" },

    resolve = function(query, context, runtime)
        local items = SearchOwnInventory(query.normalized, query.limit)
        return items
    end,

    itemIntent = function(item, actionID, context)
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

动态 item 可以额外声明交互，但只交给 Host 解释：

```lua
{
    id = "spell-12345",
    text = "红玉新生法池传送门",
    payload = { spellID = 12345 },
    interaction = {
        primaryActionID = "open-detail",
        actions = {
            { id = "open-detail", title = "查看详情", kind = "intent" },
            { id = "cast", title = "施放", kind = "secure-spell", spellID = 12345 },
        },
        drag = { type = "spell", spellID = 12345 },
    },
}
```

Lychee 负责输入 debounce、generation、结果行池化和 diff、键鼠导航、滚动、选中态、空/加载/错误状态，以及 item Intent 路由。Host 只接受当前 generation、相同 `contextToken`、稳定且唯一 item ID 的结果，超过 `query.limit` 的尾项被截断并记录诊断。

Resolver 只读取 query 和 ContextSnapshot，不创建 frame、不注册事件、不执行动作。结果变化由已声明的 `Invalidate(key)` 或 Context slice version 驱动，不靠轮询。

### 10.1 结果交互、拖拽与安全施放

`interaction` 是可选 plain-data 描述符。未声明时，Host 视为一个隐式普通 primary action：`id = "default"`、`kind = "intent"`，并以 `itemIntent(item, "default", context)` 路由，从而兼容只有单一普通选择动作的动态列表。声明时，它的 `actions` 最多四项；每个 action 的 `id` 在 item 内稳定且唯一，`primaryActionID` 必须引用其中一项。Host 拒绝未知 action kind、重复/不稳定 action ID、函数、Frame、宏文本、任意 secure 属性或鼠标脚本。动作不从 `text`、图标或 payload 猜测。

- `kind = "intent"`：Host 将当前 Extension ID、item ID、action ID、Palette session、query generation 和 Context token 绑定为一次动作。左键点击结果行和 Enter 都只请求 `primaryActionID`；若 primary 是普通 intent，Host 调用 `itemIntent(item, actionID, context)`，再走 IntentRouter。其他普通动作必须是 Host 绘制的可见行内按钮，点击后使用相同链路。
- `kind = "secure-spell"`：只允许已验证的声明式 `spellID`。它不调用 `itemIntent`，而由 Host 自己的 `SecureActionButtonTemplate` 行/按钮在脱战时配置；只有真实鼠标左键点击才能施放。若 secure action 是 primary，真实左键可以施放，但 Enter、IntentRouter、普通 Lua 回调和 scripted `Button:Click()` 必须返回 `ACTION_REQUIRES_HARDWARE_CLICK`，绝不模拟点击。
- `drag = { type = "spell", spellID = number }`：只允许当前玩家已知、可用且非被动的法术。Host 仅在 Palette 可见、脱战、item 仍属于当前 Extension/session/generation 时，响应结果行专用拖拽区域的真实 `OnDragStart`，校验后调用 `C_Spell.PickupSpell(spellID)`；标准动作条因此可以接收它。普通点击、Enter、resolver、`itemIntent`、鼠标移动和非专用区域都不能取起 spell。未知 drag type、无效 spell、旧结果或停用/retiring Extension 返回 `DRAG_UNSUPPORTED` 或 `ACTION_UNAVAILABLE`，且不改变鼠标光标。

Palette 关闭、进入战斗、Extension/Command 禁用或注销时，Host 立即使该会话的普通动作、drag token 和 secure action binding 失效。战斗中不写 protected attribute；需要清理的 secure frame 状态保留为脱战 dirty cleanup。第三方既不能取得安全按钮，也不能配置其属性、脚本或点击注册。

### 10.2 Catalog 与 ambient 匹配

Command 未声明 `match` 时等价于：

```lua
match = { type = "catalog" }
```

`catalog` 先按 Command 的 title、aliases、keywords、拼音和显式命令语法产生候选；只有候选命中后，Host 才调用它的 dynamic resolver。

需要让用户不先输入命令名、直接输入怪物或物品名称时，只能由 `dynamic-list` Command 显式声明主动匹配：

```lua
match = {
    type = "ambient",
    minLength = 2,
    maxLength = 64,
    priority = 0,
}
```

ambient 契约：

- `ambient` 只允许 `presentation = "dynamic-list"`；`row`、`custom-panel` 使用 ambient，或缺少合法 `minLength`/`maxLength`，都会使整个 Extension Commit 原子失败。
- `minLength >= 1` 且 `maxLength >= minLength`。长度按 Host 规范化后的查询计算；短输入、超长输入、availability 不满足、Command/Extension 被停用或超出本轮全局调用预算时，不调用 resolver。
- `priority` 只参与稳定调度顺序，不能绕过用户禁用、健康熔断和预算；相同优先级按稳定全局 Command ID 排序。Host 必须允许用户逐个停用 ambient Command。
- 所有 ambient Command 共用主输入框的单一 debounce。每次有效输入创建新 generation；旧 resolver、旧 deferred 任务、旧 Context token 和旧结果全部失效，迟到返回直接丢弃。
- Host 对每轮设置全局 resolver 调用数预算，并通过 `query.limit` 限制单 Command 结果数、通过 `query.deadlineMS` 下发协作式时间预算。它们是 Host 版本统一定义的上限，不由第三方扩大。
- Palette 隐藏、进入战斗、Extension/Command 停用或注销时，取消 debounce、未运行的 resolver 和 deferred 队列；隐藏状态没有 ambient 后台查询。
- resolver 只查询 Provider/模块维护的轻量预索引或缓存，不在每次按键枚举 AddOn、全量扫描原始数据库、创建 frame、注册事件或执行动作。

Command 是固定命令入口，不是唯一搜索对象。`RegisterCapabilityProvider(...)` 仍只向 Broker 发布可复用能力；实体直接搜索使用同一 Extension draft 的 `RegisterSearchSource(...)`。需要把能力查询和命令参数组合起来时，仍可额外注册 ambient Command，在 resolver 中通过 `extension:QueryCapability(...)` 查询 Provider。

### 10.3 SearchSource 与统一 SearchRecord

SearchSource 是 Buildin 和第三方实体进入 Lychee 搜索引擎的统一收录协议。Host 在注册/数据更新时建索引，按键查询只读取活动索引，不调用 Provider 扫描原始数据。

```lua
extension:RegisterSearchSource({
    id = "creatures",
    version = 1,
    revision = 7,
    priority = 80,
    scope = { product = "retail", minInterface = 120000, maxInterface = 120999 },
    snapshot = function(context)
        return {
            {
                id = "creature:12345",
                kind = "creature",
                category = { id = "dungeons", title = { default = "Dungeon", zhCN = "副本" } },
                title = "红玉小怪",
                aliases = { { text = "红玉", locale = "zhCN" } },
                keywords = { { text = "M1", locale = "zhCN" } },
                description = { { text = "打开对应指南页面。", locale = "zhCN" } },
                actions = {
                    { id = "open", kind = "intent", intent = { type = "sample.open", version = 1, payload = { creatureID = 12345 } } },
                },
            },
        }
    end,
})
```

SearchRecord 的 `id` 必须稳定且全局唯一；`kind` 用于语义，`category` 用于结果前置标签和筛选。`title`、`aliases`、`keywords`、`description` 支持 locale 和 product/interface/build scope。当前 locale、`default`、当前 product/build 不匹配的文本只保留在 Source 数据中，不进入活动索引。

Host 统一建立 canonical、alias、keyword、description 和 category title 的 exact/prefix/substring/n-gram 索引，并在查询长度和预算允许时执行有限 fuzzy 匹配。每个结果返回 `confidence`、`matchedField`、`matchedText`、`matchType`；精确标题/别名优先于前缀、关键词、描述和模糊结果。同一 stable record 被多个字段命中只显示一次，排序使用 confidence、Source priority、category order 和 stable ID。

Source 必须显式声明 `version`、`revision`、`priority`、`scope`，并通过 `snapshot` 或静态 `records` 提供初始数据。后续使用 `BeginSnapshot`/`Upsert`/`Remove`/`CommitSnapshot` 更新；每次提交递增 revision，旧 generation 结果丢弃。Source 禁用或注销只移除自己的索引项。Provider 不画 UI、不注册 Lychee 快捷键、不返回 Frame；SearchResult 的 `actions` 由 Host 转成普通 Intent、Panel、secure-spell 或 drag，并重新校验 session、generation、source state、availability 和 combat。

```lua
local source = assert(extension:GetSearchSource("creatures"))
local generation = assert(source:BeginSnapshot())
assert(source:Upsert(nextRecord, generation))
assert(source:Remove("creature:obsolete", generation))
local ok, nextGeneration, nextRevision = source:CommitSnapshot(nil, nil, generation)
```

`BeginSnapshot()` 开启一次显式批量更新；同一 generation 的 `Upsert`/`Remove` 暂存到 `CommitSnapshot`，提交时只重建该 Source 的索引成员。未先调用 `BeginSnapshot` 时，Host 自动把同一帧的 `Upsert`/`Remove` 合并，并在帧末提交一次；需要明确提交边界时使用显式批量 API。`GetState()` 返回当前 revision、generation 和 enabled。第三方自定义 category 必须使用 `<extension-id>:<category>`；`spells`、`achievements`、`quests`、`dungeons`、`extensions` 是 Host 保留的共享类别。

空输入时 Palette 显示 ZTools 风格 HomeView（最近、固定、分类、第三方入口）；有输入时显示带图标、category badge、描述、命中证据和动作槽的 SearchView。最近/固定只保存 stable ID，不保存完整 payload。搜索索引和结果行均池化，Palette 隐藏时没有常驻每帧工作。

### 10.4 协作式 deferred resolver

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

`deadlineMS` 是测量和调度预算，不是硬超时。WoW Lua 无法安全抢占正在运行的第三方回调；Host 只能在回调返回后记录超时。超时或连续 `PROVIDER_ERROR` 时，Host 保留对应 Command/Provider 的 dirty 标记，不发布不完整结果，进入 `slow`，并按统一的有界退避窗口重新调度（例如 50ms、100ms、250ms，达到本轮重试上限后等待下一次输入或显式 `Invalidate`）。退避期间不创建额外 ticker；新 generation、关闭 Palette、停用或注销会取消重试。只有成功刷新或明确确认数据不可用时才清除 dirty。

### 10.5 Lychee 内置 Extension 的同协议用法

Lychee 自己的功能也是 Extension/Provider，不绕开上述结果合同。当前运行时只交付 `PlayerSpells`；DungeonGuide 和 DungeonAlias 等能力必须等真实数据源或稳定适配器就绪后再注册，不能在生产包中使用 fixture 占位：

- 规划中的 `DungeonGuideProvider`：通过 SearchSource 收录怪物名和怪物技能名；普通 action 打开 Lychee 详情 Panel。若安装了 MRT 或其他指南，适配器只能调用其稳定公开 API 打开对应页面；不得操作其内部 frame。
- `PlayerSpells` Extension 的 `PlayerSpellProvider`：只建立一份当前角色已知且可用的法术快照，并通过一个 SearchSource 发布；`PlayerSpellAliases.lua` 只提供 Locale 别名投影，其中既包含“复仇之怒”对应“翅膀”等技能俗称，也包含已知传送法术对应“红玉”等副本简称。当前法术 SearchRecord 提供 `drag.type = "spell"` 和 `secure-spell` 真实点击施放，不注册 Command、CapabilityProvider、IntentHandler 或空详情 Panel。
- 规划中的 `DungeonAliasProvider`：通过 SearchSource 将 Boss 名或赛季别名（如 `M1`）映射为副本/Boss 记录，而不是为每个别名建立独立快捷键或特殊 UI。
- 副本传送搜索属于同一个 `PlayerSpells` Extension，不新增额外 Provider、独立目录或第二份法术索引。输入“红玉”等别名命中 canonical spell item，拖拽和真实点击施放仍复用同一 item interaction。

玩家法术索引必须以当前角色实时法术书为事实源。Host 在登录及法术/专精/天赋变化事件后批量刷新快照，读取 `C_SpellBook.GetNumSpellBookSkillLines()`、`GetSpellBookSkillLineInfo()` 和 `GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)`；按键查询只访问预构建快照与 alias index。静态法术数据只能用于 alias 定义；离线测试的 SpellBook fixture 必须留在 `tests/`，生产 Provider 不提供固定技能回退。

Provider 只维护可复用能力和数据查询；稳定实体通过 SearchSource 进入主输入框，只有运行时组合查询才使用 ambient Command；SearchRecord Action/Handler 决定普通选择后的 transition；Host 负责结果行和受保护输入。这些职责不因功能是内置或第三方而改变。

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
    stateSchema = {
        profileID = "string?",
    },
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

Host 在第一次打开时惰性调用一次 `create`，缓存该 panel 实例并在后续打开时复用。成功 `Mount` 后必有且仅有一次对应 `Unmount`；Extension 注销时在 Unmount 后调用一次可选 `Dispose`。`create`、`Mount`、`Update`、`Unmount` 或 `Dispose` 任一步报错时，Host 按固定顺序执行：记录 `PANEL_ERROR` -> 尽力调用 `Unmount` -> 隐藏该 Panel 的 `contentFrame` -> 注销该 Extension 的 Panel/查询/timer 驱动 -> 关闭 ViewHost 并释放 busy 状态。错误清理不得把异常重新抛回 Palette，也不得让其他 Extension 停止。

`stateSchema` 声明 Intent transition 可交给本 Panel 的状态形状。通过 Command 直接打开 Panel 时初始 state 为空；通过 Handler transition 打开时，Host 先验证同 Extension 所有权、session/generation/Context token 和 `transition.state`，再 Mount Panel，并调用一次 `Update({ reason = "transition", state = validatedState, ... })`。跨 Extension 的 `panelFactoryID` 或非法 state 返回 `INTENT_INVALID`；过期 session/generation 返回 `STALE_GENERATION`，两者都不调用 `create`、`Mount` 或 `Update`。

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
- Host 管理 Palette 根 frame、ViewHost 尺寸、层级、Esc、best-effort 焦点恢复和关闭。`width`、`height` 是只读布局约束；Panel 不得改动 Host 根 frame/父级、尺寸、锚点、层级、全局按键、主输入框或焦点所有权。
- Panel 按钮需要触发 Lychee 动作时使用 `dispatchIntent`，不能直接调用 Host Handler。战斗中 Palette 已关闭，任何迟到或绕过入口的受保护 Intent 都返回 `COMBAT_LOCKED`；9.1 节的安全按钮只在脱战会话中可见。
- `close`、`invalidate`、`requestFocus`、`dispatchIntent` 和 timer callback 都绑定当前 generation。Unmount 后控制方法返回 `INVALID_STATE`，`IsActive()` 返回 false。
- Palette 隐藏、Esc、进入战斗、超时、切换 Command、Extension 禁用/注销和 Panel 错误都会触发同一条 Unmount/任务清理路径。关闭后仅在旧焦点对象仍可访问时 best-effort 恢复，否则只清除 Lychee 输入焦点。
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
- `pending`：已原子提交，但 Lychee Host 尚未 ready，或 PublicAPI 已接受该版本而当前 Host revision 暂时不足。
- `registered`：Host 已建立索引，尚未启用。
- `enabled`：Command、Provider、Handler 和 Panel 可以参与运行。
- `slow`：仍是已注册实例，但调度被降频；达到熔断条件可进入 disabled。
- `disabled`：本会话不再调用；保留注册和诊断，可显式重新启用。
- `retiring`：新查询已停止，等待 generation、Panel 和 Host 托管任务清理。
- `removed`：从 registry 和索引移除，旧句柄失效。

同一 `Extension.id` 重载时不允许新句柄覆盖旧句柄。Lychee 先把旧 committed handle 标记为 `retiring`，停止新 Command/Provider 调度，令活动 generation 失效，并依次等待 resolver/deferred、Panel `Unmount`、托管 timer/ticker 和 Extension 驱动清理；只有旧句柄进入 `removed` 后，新的 draft 才能占用该 ID 并 Commit。旧句柄的迟到回调即使返回也会被丢弃，不能写入新句柄的索引、结果或 Panel。清理异常不能卡住替换：Host 记录 `CALLBACK_ERROR`/`PANEL_ERROR` 后继续完成 best-effort 清理，再释放 ID。

PublicAPI 不支持声明的 API major/minimum revision 时，`Commit()` 原子失败并返回 `UNSUPPORTED_API`。PublicAPI 支持但当前 Host revision 不足时，`Commit()` 成功并停留在 `pending/incompatible`，诊断码为 `INCOMPATIBLE_HOST`，不执行第三方回调。

Lychee ready 时按 Extension ID 稳定排序消费 pending。Lychee 已就绪时，新提交立即注册。生命周期回调由 PublicAPI 在局部错误边界中调用：

```lua
onHostAttached = function(hostInfo)
    -- hostInfo 含 API major/revision 和只读 feature flags。
end
onHostDetached = function(reason) end
onEnabled = function() end
onDisabled = function(reason) end
```

ready 回调顺序固定为 `onHostAttached -> onEnabled`；facade detach 时若当前 enabled，则按 `onDisabled(reason) -> onHostDetached(reason)` 执行。Lychee facade detach 后，Extension 停止所有 Host 托管任务并回到 pending；下一个兼容版本 ready 后可再次注册和启用。

`Unregister()` 幂等：第一次调用进入 retiring，后续调用返回同一状态。它只清理 Lychee 接入，不卸载第三方 AddOn，也不删除第三方 SavedVariables。生命周期回调报错只记录 `CALLBACK_ERROR`，状态机仍继续完成清理。

重载使用同一 retiring 流程；第三方不得通过再次 `RegisterExtension` 抢占仍在清理的 ID，也不得保存旧句柄并在新句柄提交后调用旧句柄的 `SetEnabled`、`Invalidate` 或 `QueryCapability`。

## 14. Binding、焦点与战斗策略

Lychee 只声明一个全局 Binding：`TOGGLELYCHEE`。`Lychee.toc` 必须把 `Bindings.xml` 列入加载文件；该 XML 文件内容为：

```xml
<Bindings>
    <Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">
        Lychee_Toggle();
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
    PaletteController:Toggle()
end
```

默认打开组合键为 `Alt + Space`（binding key 为 `ALT-SPACE`），但 Host 只允许在**首次初始化且脱战**时尝试一次：当 `GetBindingKey("TOGGLELYCHEE")` 没有返回 binding，且 `ALT-SPACE` 未绑定给其他 action，才执行：

```lua
SetBinding("ALT-SPACE", "TOGGLELYCHEE")
SaveBindings(GetCurrentBindingSet())
```

Host 在 SavedVariables 中记录一次性 `defaultBindingAttempted`。已有 `TOGGLELYCHEE` binding、`ALT-SPACE` 冲突、战斗中初始化或该标记已设置时均不得写入。玩家后来在 WoW 按键设置中改键或解绑后，Lychee 永不自动回写；Host 不使用 `SetOverrideBinding`，也不在每次登录重写 binding。

第三方 Extension 不得添加 `TOGGLELYCHEE` 的同名声明、额外 Lychee Binding、`SetBinding`/`SetOverrideBinding` 接管或独立全局快捷键。第三方 Panel 只在已 Mount 且可见期间使用 frame-local 键盘/鼠标脚本；Esc、Enter、Tab 和上下键冲突由 Host 状态机裁决。

### 14.1 战斗状态机

- `TOGGLELYCHEE` 的处理函数第一步检查 `InCombatLockdown()`。战斗中调用静默返回：不打开、不关闭、不改变文本或 selection、不读取/移动焦点、不增加 query generation、不启动 debounce/resolver/deferred/timer。
- Host 注册 `PLAYER_REGEN_DISABLED`。若 Palette 已打开，统一执行 `Close("combat")`：先让当前 Panel `Unmount("combat")`，取消 Panel 托管 Timer/Ticker、resolver deferred、debounce 和待发布结果，使当前 generation 失效，best-effort 清空 Lychee 输入焦点，然后关闭 Palette。
- 战斗关闭流程不执行 Intent、不准备/修改 secure descriptor 和 secure attributes。受限的 secure frame 变更保留 dirty 标记，等 `PLAYER_REGEN_ENABLED` 后再处理；关闭 Palette 本身不能依赖这些变更成功。
- `PLAYER_REGEN_ENABLED` 自动重新启用 `TOGGLELYCHEE` 的正常处理，并处理允许的 dirty cleanup/secure preparation。它不自动重新打开 Palette，也不恢复战斗前 query；用户下一次按键创建全新 generation。
- 其他代码入口如需切换 Palette，也必须委托 `PaletteController:Toggle()` 并复用同一 combat guard，不能绕过 Binding 策略。

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
| `SDK_UNAVAILABLE` | 第三方 AddOn 入口未发现 Lychee 暴露的兼容公共 API；仅用于一次性诊断，不阻止第三方自身功能 |
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
| `INVALID_INTERACTION` | dynamic item interaction、action ID、primary action 或动作组合不符合 schema |
| `DRAG_UNSUPPORTED` | Host 不支持或当前不允许声明的 drag type |
| `ACTION_UNAVAILABLE` | action 的目标、指南 adapter 或 spell 当前不可用 |
| `ACTION_REQUIRES_HARDWARE_CLICK` | 请求以 Enter/脚本路径触发 secure action，必须真实鼠标点击 |
| `PANEL_ERROR` | Panel create/Mount/Update/Unmount/Dispose 报错 |
| `CALLBACK_ERROR` | 普通或生命周期回调报错 |

错误码语义在同一 API major 内保持稳定。`retryable` 只描述重新发起是否可能成功，不代表 SDK 会无限自动重试。Host 只允许 10.2 节规定的有限退避次数；达到上限后等待下一次输入、显式 invalidation 或用户操作才产生新调用。

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

## 17. 完整示例

### 17.1 普通 row Command

```lua
local SDK = _G.Lychee
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

### 17.2 大秘境怪物 Provider + ambient Command + 详情 Panel

下面的组合是第三方实体搜索的完整模板。`SearchCreatureNameIndex` 和 `GetCreatureRecord` 代表第三方自己维护的预索引和数据表；索引在加载或数据变化时更新，不在每次输入时重建。

```lua
local SDK = _G.Lychee
if not SDK or not SDK:Supports(1, 1) then return end

local Extension, registerErr = SDK:RegisterExtension({
    id = "mythic-creatures",
    apiVersion = 1,
    minApiRevision = 1,
    title = "大秘境怪物资料",
    version = "1.0.0",
    invalidationKeys = { "creature-index" },
})
if not Extension then return end

local function RequireDeclaration(token)
    if token then return true end
    Extension:Abort()
    return false
end

-- Provider 发布可复用能力，但它自己不会出现在 Lychee 搜索结果中。
if not RequireDeclaration(Extension:RegisterCapabilityProvider({
    id = "creature-source",
    type = "mythic-creatures.creature-search",
    version = 1,
    priority = 0,
    requestSchema = {
        text = "string",
        limit = "integer",
    },
    resultSchema = {
        kind = "array",
        items = {
            creatureID = "integer",
            name = "string",
            dungeonName = "string",
            icon = "integer?",
        },
        maxItems = 20,
    },
    query = function(request)
        -- 必须查询已构建的轻量名称索引，不在这里全量扫描原始数据。
        return SearchCreatureNameIndex(request.text, request.limit)
    end,
})) then return end

if not RequireDeclaration(Extension:RegisterPanelFactory({
    id = "creature-detail",
    stateSchema = {
        creatureID = "integer",
    },
    create = function()
        local panel = {}

        function panel:Mount(context)
            self.context = context
            if not self.frame then
                self.frame = CreateFrame("Frame", nil, context.contentFrame)
                self.frame:SetAllPoints(context.contentFrame)
                self.title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
                self.title:SetPoint("TOPLEFT", 16, -16)
                self.body = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -12)
                self.body:SetJustifyH("LEFT")
            end
            self.frame:Show()
        end

        function panel:Update(update)
            if update.reason ~= "transition" then return end
            local record = GetCreatureRecord(update.state.creatureID)
            if not record then
                self.title:SetText("资料不可用")
                self.body:SetText("")
                return
            end
            self.title:SetText(record.name)
            self.body:SetText(record.summary)
        end

        function panel:Unmount()
            if self.frame then self.frame:Hide() end
            self.context = nil
        end

        function panel:Dispose()
            if self.frame then
                self.frame:SetScript("OnEvent", nil)
                self.frame:Hide()
            end
            self.context = nil
        end

        return panel
    end,
})) then return end

if not RequireDeclaration(Extension:RegisterIntentHandler({
    type = "mythic-creatures.open-creature-detail",
    version = 1,
    schema = {
        creatureID = "integer",
    },
    execute = function(intent)
        return {
            ok = true,
            closePalette = false,
            transition = {
                type = "custom-panel",
                panelFactoryID = "creature-detail",
                state = {
                    creatureID = intent.payload.creatureID,
                },
            },
        }
    end,
})) then return end

-- 只有这个 ambient dynamic-list Command 会让怪物名称进入主输入框搜索。
if not RequireDeclaration(Extension:RegisterCommand({
    id = "find-creature",
    title = "查找大秘境怪物",
    aliases = { "怪物", "小怪", "creature" },
    keywords = { "mythic", "dungeon" },
    presentation = "dynamic-list",
    match = {
        type = "ambient",
        minLength = 2,
        maxLength = 64,
        priority = 0,
    },
    resolve = function(query, context)
        local records, queryErr = Extension:QueryCapability({
            type = "mythic-creatures.creature-search",
            minVersion = 1,
            maxVersion = 1,
            request = {
                text = query.normalized,
                limit = query.limit,
            },
        }, context)
        if not records then
            return nil, queryErr
        end

        local items = {}
        for index = 1, #records do
            local record = records[index]
            items[index] = {
                id = "creature-" .. record.creatureID,
                text = record.name,
                subtext = record.dungeonName,
                icon = record.icon,
                enabled = true,
                payload = {
                    creatureID = record.creatureID,
                },
                interaction = {
                    primaryActionID = "open-detail",
                    actions = {
                        { id = "open-detail", title = "查看详情", kind = "intent" },
                    },
                },
            }
        end
        return items
    end,
    itemIntent = function(item, actionID)
        if actionID ~= "open-detail" then
            return nil, { code = "ACTION_UNAVAILABLE", retryable = false }
        end
        return {
            type = "mythic-creatures.open-creature-detail",
            version = 1,
            payload = {
                creatureID = item.payload.creatureID,
            },
        }
    end,
})) then return end

local committed, commitErr = Extension:Commit()
if not committed then
    -- Provider、Command、Handler 和 Panel 全部不可见，不会留下部分接入。
    return
end

-- 可选的第三方所有者控制；不能覆盖用户禁用或 Host 健康熔断。
committed:SetEnabled(true)

-- 插件关闭 Lychee 集成时调用；重复调用也是安全的。
-- committed:Unregister()
```

用户直接输入怪物名称后的固定链路是：ambient Command 通过长度和预算筛选 -> resolver 经 Broker 查询 Provider 预索引 -> Host 绘制 item -> `itemIntent` 生成结构化 Intent -> Handler 返回 transition -> Host 校验并由 ViewHost 挂载同 Extension 的 Panel。Provider、resolver 和 Handler 都不创建或接管 Palette UI。

实现阶段的 SDK fixture 必须验证：

1. 第三方先加载时，集成代码等待 Lychee ready 后完成 Commit；
2. Lychee 先加载时，第三方 Commit 后 Extension 立即注册；
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
17. 直接输入实体名时 ambient Command 返回动态项，不需要先输入 Command title/alias；短于 `minLength` 或长于 `maxLength` 时 resolver 调用数为零；
18. 多个 ambient Command 按 owner/user enable、availability、priority、稳定 ID 和全局调用预算调度；单 Command 结果不超过 `query.limit`，超出 `deadlineMS` 的返回被计入 slow/熔断；
19. 快速连续输入只发布最新 generation；旧同步结果、deferred 结果和 Context token 均被丢弃；
20. 只有 Provider 而没有 ambient Command 的 committed Extension 不产生搜索结果；Provider 不可用、索引未就绪或 resolver 报错只影响所属结果组；
21. 合法 item Intent transition 挂载同 Extension Panel；跨 Extension Panel、非法/secret/inaccessible state、过期 session/generation 均不创建或挂载 Panel；
22. Palette 关闭、进入战斗、`SetEnabled(false)` 或幂等 `Unregister()` 后，ambient resolver、deferred、Panel 和待处理 transition 均无效果；
23. 第三方先/后加载 Lychee 最终都得到相同 registered Extension；facade 缺席时一次性 `ADDON_LOADED` 监听触发幂等注册，第三方无需轮询或重复提交；
24. facade 缺席只记录一次 `SDK_UNAVAILABLE`；PublicAPI 不支持声明的 API major/minimum revision 时，`Commit()` 原子失败并只记录一次 `UNSUPPORTED_API`，两种路径都不影响第三方自身功能；
25. PublicAPI 支持声明、但当前 Host revision 不足时，`Commit()` 成功，Extension 进入 `pending/incompatible` 并报告 `INCOMPATIBLE_HOST`，不执行第三方回调；
26. 同一 Extension ID 重载时旧句柄先进入 `retiring`，停止新调度并清理 resolver、Panel、timer 和驱动；旧句柄到 `removed` 后新句柄才可 Commit，旧迟到回调不污染新句柄；
26. resolver 超时或连续 `PROVIDER_ERROR` 保留 dirty，进入 `slow`，按有界退避窗口重试；新 generation、关闭 Palette、停用和注销取消退避；
27. Intent 业务失败、抛错、非法结果和 transition 失败都发布统一错误行并释放 busy，错误不重复且不显示异常堆栈；
28. Panel create/Mount/Update/Unmount/Dispose 任一步报错都记录 `PANEL_ERROR`，尽力 Unmount、隐藏 contentFrame、注销该 Extension 驱动、关闭 ViewHost 和释放 busy，且不影响其他 Extension。
29. 单一普通 primary action（或未声明 interaction 的隐式 `default`）可由左键/Enter 触发；多 action 行只触发声明的 primary，次级 action 只能由 Host 显示的按钮触发，action ID 不从文字推断；
30. spell item 只从专用区域真实 `OnDragStart` 调用 `C_Spell.PickupSpell` 并可被标准动作条接收；普通点击、Enter、resolver 与 `itemIntent` 不触发 PickupSpell；
31. secure-spell 行/按钮只在脱战绑定，真实鼠标点击才可施放；Enter、IntentRouter 与 scripted `Button:Click()` 被拒绝且不能模拟点击；
32. Palette 关闭、进入战斗、Extension disable/unregister、指南适配器缺席或旧 generation 后，不遗留普通动作、拖拽 token、secure binding 或 Panel transition；
33. 怪物/怪物技能、玩家技能、Boss/赛季别名和已知副本传送技能四类内置搜索场景均通过同一 interaction 合同工作；副本传送与玩家技能共用 `PlayerSpells` Extension；
34. 首次脱战初始化仅在 `TOGGLELYCHEE` 未绑定且 `ALT-SPACE` 空闲时写入默认 binding；已有 action、按键冲突、战斗中初始化、已设置 `defaultBindingAttempted` 以及玩家后来改键或解绑时，均不覆盖或回写。

### 17.3 玩家法术结果：动作条拖拽与真实点击施放

`PlayerSpellProvider` 只应发布当前角色已知且可用的法术。当前内置实现直接提交 SearchRecord，不经过 Command resolver 或 CapabilityBroker；Host 负责在展示和执行时再次确认法术可用性、generation 与战斗状态：

```lua
local function BuildPlayerSpellRecord(spellID, name, icon, aliases)
    return {
        id = "spell:" .. spellID,
        kind = "spell",
        category = { id = "spells", title = { default = "Spells", zhCN = "技能" }, order = 10 },
        title = name,
        aliases = aliases,
        icon = icon,
        payload = { spellID = spellID },
        actions = {
            { id = "cast", title = "施放", kind = "secure-spell", spellID = spellID },
        },
        drag = { type = "spell", spellID = spellID },
    }
end
```

“施放”必须由真实鼠标左键点击 Host 的 secure 按钮，Enter 不模拟安全点击；拖拽必须从 Host 的专用区域开始。传送门仅是法术的别名索引，不另建动作协议。以后若实现真实详情页面，再为同一 Extension 增加 PanelFactory 和声明式 action，不预留空 Panel。

## 18. 接入检查清单

- [ ] TOC 使用 `## OptionalDeps: Lychee`，Lychee 缺席时只跳过集成接入。
- [ ] facade 缺席时只写一次 `SDK_UNAVAILABLE`；PublicAPI 不支持时记录 `UNSUPPORTED_API`；Host revision 暂时不足时 committed handle 进入 `pending/incompatible` 并报告 `INCOMPATIBLE_HOST`。
- [ ] Extension 在所有子声明成功后调用一次 `Commit()`。
- [ ] Lychee 先/后加载与第三方先/后加载都不需要轮询或重复注册。
- [ ] 同 ID 重载先等待旧句柄 `retiring -> removed` 和所有查询/Panel/timer/驱动清理，再接受新句柄。
- [ ] Extension、Command、Provider、Intent type 和 item 使用稳定 ID。
- [ ] 第三方 Intent/custom capability type 使用自己的 Extension ID 前缀。
- [ ] 普通动作使用结构化 Intent，payload 只含有界 plain data。
- [ ] Context、payload、request/result、item 和诊断字段先递归拒绝 secret/inaccessible value。
- [ ] dynamic-list 返回稳定 item ID，不创建结果行 frame。
- [ ] Provider 不作为搜索入口、不绘制 UI；需要实体搜索时，同一 Extension 还注册 ambient dynamic-list Command，并通过 Broker 调用 Provider。
- [ ] ambient 只用于 dynamic-list，声明合法长度边界，并遵守 enable、availability、调用数、结果数、时间和 generation 预算。
- [ ] resolver 超时/连续错误保留 dirty，进入 slow 并按退避窗口重试；取消路径不会留下 ticker 或任务。
- [ ] itemIntent 先生成 Intent；Handler 只返回声明式 transition，Panel 所有权和 state 校验后才挂载。
- [ ] dynamic item 的 interaction 只有稳定 plain-data action；左键/Enter 只请求 primary（未声明时为隐式 `default`），非 primary action 由 Host 可见按钮触发。
- [ ] spell 拖拽只从 Host 专用区域的真实 `OnDragStart` 调用 `C_Spell.PickupSpell`；普通动作路径绝不取起 spell。
- [ ] secure-spell 只由 Host 脱战配置并依赖真实鼠标点击；第三方不接触 SecureButton，Enter/脚本调用不模拟施放。
- [ ] Intent 错误统一发布错误行并释放 busy；Panel 错误记录 `PANEL_ERROR` 后执行 Unmount、隐藏 contentFrame、注销 Extension 驱动和 ViewHost 清理。
- [ ] Extension 句柄只控制 owner-enabled 位，`Unregister()` 可重复调用且不误删新句柄。
- [ ] custom-panel 只在 `contentFrame` 下创建子 frame 并复用实例。
- [ ] Panel 在所有退出路径停止自身事件并取消托管 Timer/Ticker；raw `C_Timer.After` 有 generation/active guard。
- [ ] Resolver、Provider 和 availability 没有执行副作用或无界同步工作。
- [ ] 插件没有在唯一的 `TOGGLELYCHEE` 之外为 Lychee 注册额外全局快捷键。
- [ ] 默认 `ALT-SPACE` 仅在首次脱战、`TOGGLELYCHEE` 未绑定且无冲突时写入；玩家随后改键或解绑后不回写。
- [ ] Host 的 `TOGGLELYCHEE` 在战斗中静默，战斗开始关闭已有 Palette，脱战后自动恢复入口。
- [ ] Secure Descriptor 只由 Host 脱战配置，执行依赖真实点击而不是脚本 `Click()`。
- [ ] AddonMessage 没有被用作本机 SDK RPC。
