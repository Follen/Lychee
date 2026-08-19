# LycheeSDK 集成协议

## 本 change 的交付形式

本规格通过 `docs/SDK.md` 交付第三方接入设计，不创建 `LycheeSDK` AddOn 文件。文档必须给出可直接照写的 TOC、注册 API、返回值、错误码、两种交互模式、生命周期、版本兼容、性能要求和完整示例。

## 目标

`LycheeSDK` 是独立 sibling AddOn，负责把其他 WoW 插件接入 Lychee。它只提供进程内 Lua API 和生命周期句柄，不模拟桌面应用的 IPC，不使用聊天频道传输注册信息。

接入动作必须由第三方主动发起：第三方在自己的加载流程中向 `LycheeSDK` 注册 Extension、Command、Provider、Handler 和可选 Panel，并调用 `Commit()`。Lychee 不扫描目录来自动生成接入。只有 Provider 的 Extension 不会产生搜索结果；需要让第三方数据响应 Lychee 主输入框时，同一 Extension 必须注册引用该 Provider 的 `ambient` `dynamic-list` Command。

## AddOn 加载契约

第三方插件的 TOC 至少声明：

```toc
## OptionalDeps: LycheeSDK
```

可选的诊断元数据：

```toc
## X-Lychee-API: 1
## X-Lychee-Extension: sample-extension
## X-Lychee-Commands: 2
## X-Lychee-Keywords: sample,search
```

`OptionalDeps` 用于请求在双方均可用时先加载 `LycheeSDK`，但不能单独证明 SDK 已存在、已加载或注册成功，也不要求用户必须安装 Lychee。插件主 chunk 必须检查 `_G.LycheeSDK` 并兼容两种结果：

1. `LycheeSDK` 已加载：立即注册 Extension。
2. `LycheeSDK` 未安装或未能加载：记录一次诊断信息，跳过 Lychee frame 和事件，插件自身功能继续工作。

SDK 主 chunk 只建立稳定全局表和轻量 registry，不创建 Palette、不注册全局快捷键、不访问第三方 SavedVariables。

## 运行时发现顺序

```text
第三方 TOC OptionalDeps
  -> LycheeSDK 主 chunk 建立全局表
  -> 第三方创建 Extension draft 并注册子声明
  -> 第三方调用 Commit() 原子发布
  -> SDK 校验并写入 pending registry
  -> Lychee Host PLAYER_LOGIN/显式 attach
  -> Host 消费 pending registry
  -> Extension 进入 registered/enabled
```

Host 的唯一事实源是 SDK registry，而不是每次输入时重新扫描 AddOn 列表。Lychee 可以在登录或诊断页缓存以下官方信息用于展示：

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
local sdk = _G.LycheeSDK
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
    itemIntent = function(item, context) end,
})

local committed, commitErr = extension:Commit()
```

`RegisterExtension` 返回 draft；各 `Register*` 只写入 draft，`Commit()` 一次性校验交叉引用、版本、schema 和声明数量。注册校验必须拒绝并报告：空 ID、非法字符、重复 Extension/Command/Capability ID、未支持的 API 版本、presentation 与 resolver/factory 不匹配、缺少稳定标题或超出声明数量上限。失败不发布部分对象，重复注册不能静默覆盖已启用的 Extension。

`Commit()` 成功后返回同一个稳定 Extension 句柄；第三方用该句柄读取只读状态、设置 owner-enabled 位和调用幂等 `Unregister()`。第三方不得直接修改 SDK registry，也不需要因 Host 尚未加载而自行轮询或重复注册。

## pending registry 与 Host attach

SDK registry 分为 `pending` 和 `attached` 两个集合：

- SDK 先加载、Host 后加载：committed 句柄进入 `pending`；Host attach 时按 Extension ID 稳定排序、逐项校验并转移到 `attached`。
- Host 已加载、第三方后加载：Commit 后立即尝试 attach；失败仍留在 `pending`，等待下一次显式 attach。
- 同一 Extension 重载：旧句柄先进入 `retiring`，其索引和驱动清理完成后才接受新句柄。
- Host detach 或 Lychee 关闭：调用每个句柄的 `OnHostDetached`，停止查询、Panel、ticker、timer 和事件引用，但不删除第三方自己的数据。

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

第三方 `dynamic-list` resolver 接收规范化 query 和只读 `ContextSnapshot`，返回结构化 item 数组。Context、payload 和返回值必须先经过递归边界检查：`issecretvalue(value)` 为 true、`canaccessvalue(value)` 为 false，或 table 的 `canaccesstable(value)` 为 false 时，SDK 拒绝该值并返回稳定错误码；这些值不得进入索引、Intent、日志或 SavedVariables。

```lua
{ id = "item-1", text = "...", subtext = "...", icon = "...", enabled = true, payload = opaque }
```

Lychee 负责单一输入 debounce、行池、键盘上下、鼠标点击、滚动、选中态、查询 generation 和过期结果丢弃。第三方只处理 payload 对应的 Intent，不创建 Palette 行 frame。Resolver 可以通过 CapabilityBroker 查询 Provider；Provider 自己维护实体名称的预索引/缓存，但不会自动成为搜索入口，也不向 Palette 推送 frame。

因此第三方可复用能力与可搜索入口是两份显式声明：`RegisterCapabilityProvider(...)` 让能力可被 Broker 调用，`RegisterCommand(...)` 决定该能力何时参与主输入框查询。两者只有在所属 Extension `Commit()` 成功后才同时可见；注销 Extension 时二者作为一个所有权单元退出。

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

大秘境怪物接入的组合固定为：ambient `dynamic-list` Command 负责直接命中名称，creature CapabilityProvider 负责查询预索引数据，`itemIntent` 生成打开详情 Intent，IntentHandler 返回上述 transition，PanelFactory 负责详情内容。

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

## Host 快捷键边界

Lychee Host 只注册 `TOGGLELYCHEE`：`Bindings.xml` 必须声明 `<Binding name="TOGGLELYCHEE" category="BINDING_HEADER_LYCHEE">`，调用稳定全局 Toggle 函数，并提供 `BINDING_HEADER_LYCHEE` 和 `BINDING_NAME_TOGGLELYCHEE` 本地化文案。第三方 Extension 不注册 Lychee 快捷键。Toggle 入口在 `InCombatLockdown()` 为 true 时静默返回，不打开、不关闭、不移动焦点、不启动查询；`PLAYER_REGEN_DISABLED` 会关闭已打开的 Palette 并触发 `Unmount`/任务清理，脱战后原 Binding 自动恢复可用。

## 生命周期、错误与隔离

Extension 状态：`draft -> pending -> registered -> enabled -> slow/disabled -> retiring -> removed`。每个 resolver、Intent、Panel callback 都包在局部错误边界内；错误只禁用对应 Extension 的任务和索引，不得让 Palette 卡死或无法关闭。

- resolver 超时或连续错误：丢弃本次结果，保留 dirty，按退避窗口重试并标记 `slow`；
- Intent 错误：停止当前动作，显示统一错误行，释放 busy 状态；
- Panel 错误：调用 `Unmount`、隐藏 content frame、注销该 Extension 驱动；
- 注销：先标记 `retiring`，等待当前 generation 完成或失效后再移除索引；
- SDK 缺失：第三方不创建 Lychee 相关对象；
- API 不兼容：注册失败并返回稳定错误码，不执行部分注册。

## 通信边界

`C_ChatInfo.RegisterAddonMessagePrefix` 和 `C_ChatInfo.SendAddonMessage` 面向客户端间 AddOn 消息，需要频道/目标和文本 payload，受通信节流约束。它们不参与 LycheeSDK 注册、命令查询或本机 Intent 调用。Lychee 与第三方的本机通信只经过 Lua SDK 句柄、结构化参数和 Host 回调。

## 性能约束

- 注册和 AddOn 元数据扫描只发生在加载/登录/诊断入口，不发生在每次按键。
- registry、Command Catalog 和 alias 索引使用稳定数组 + ID 索引；重复注册/注销不触发全量 UI 重建。
- ambient dynamic-list 只在用户启用、长度/availability 命中并位于 Host 全局调用预算内时执行；短输入不调度。
- dynamic-list 结果带 generation，旧结果不进入渲染；每 Command 结果数受限，列表行使用池化 frame。
- Provider/模块在注册或数据变化时维护实体索引，resolver 不在每次输入时全表扫描。
- custom-panel 隐藏时必须清理 ticker、timer、事件和 frame 引用；Palette 隐藏时无常驻 Lua `OnUpdate`。
- SDK 主 chunk 只做常量和 registry 初始化，不在加载期深扫描第三方代码。

## 验证夹具

必须覆盖：

1. SDK 先加载、Host 后 attach，committed pending registry 被完整消费；
2. Host 先加载、第三方后 Commit，Extension 立即 attach；
3. 未 Commit draft 不可见，重复 ID、版本不兼容、声明数量超限时原子失败；
4. LoD 插件由关键词候选显式加载，加载但未 Commit 时显示诊断状态；
5. dynamic-list 旧 generation 不覆盖新输入；
6. custom-panel 的实例复用、Mount/Update/Unmount/Dispose、Esc 和托管资源清理；
7. 一个第三方回调报错时，其他 Extension 和 Palette 仍可用；
8. 代码路径没有使用 `SendAddonMessage` 作为本机 SDK RPC；
9. `SecureActionButtonTemplate` 创建、脱战 descriptor 配置，以及所有战斗中 Lychee Intent、scripted click/Enter 的 `COMBAT_LOCKED` 行为；
10. 战斗中 `TOGGLELYCHEE` 静默失效且不启动查询，进战关闭已打开 Palette，脱战后同一 Binding 恢复；
11. secret/inaccessible Context、payload 和返回值被递归拒绝，且不进入索引、Intent、日志或 SavedVariables；
12. `IsAddOnLoaded` 的 loading/loaded 双状态、Panel 可取消 timer/ticker 与 `After` generation guard；
13. 直接输入实体名时 ambient Command 返回动态项，不需要先输入命令标题；短于 `minLength` 时不调用 resolver；
14. 多个 ambient Command 按启用状态和稳定预算调度，快速连续输入的旧结果不覆盖新结果；
15. Provider 不可用、索引未就绪或 resolver 超预算时只影响所属结果组；
16. item Intent 的合法 transition 挂载同 Extension Panel，跨 Extension、非法 state 或过期 session 转换被拒绝；
17. Palette 关闭、进入战斗、Extension disable/unregister 后 ambient 查询与待处理 transition 均无效果。
