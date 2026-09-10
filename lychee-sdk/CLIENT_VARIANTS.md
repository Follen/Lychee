# 同一 Provider 的客户端与 build 差异约定

本文件是 Provider API 2.2 的实现约定，适用于内置与第三方 Provider。它不增加新的 Host 注册字段或 API。

## 支持范围与业务实现

`scope.products` 及 interface/build 上下界只负责可用性过滤，不负责选择业务代码。同一个 Provider 可以在不同客户端返回不同条目、采用不同数据源、事件、查询、动作或视图；不要求用一组回调覆盖所有客户端。

相同业务入口保持相同 Provider ID，例如装备方案一直是 `my-addon.equipment`。只有本身可独立启停、定位不同的业务才拆成不同 Provider，不能仅因为客户端 API 不同就拆出四个设置开关。

Provider 自己拥有兼容层。Host 只接收本次客户端选出的完整普通 descriptor，并继续执行原来的校验、搜索、交互和生命周期约束。禁止依赖 `LycheeInternal`；当前公共 SDK 没有 `GetClient` 或 `RegisterVariant`，接入代码不能假定存在这些方法。

## 选择规则

1. 区分 product（retail/classic/titan/anniversary）、Interface 编号和数字 build 编号。不能把它们混成一个版本值，也不能用本地化显示名、字符串字典序或语言来判断客户端。
2. 优先由对应客户端 TOC 只加载相关适配模块。共用代码可共用；跨客户端业务不同的代码放在各自模块。小差异可在初始化时选择局部函数，不强制拆文件。
3. 同一 product 内需要按 Interface/build 分段时，在注册前选择一次实现。范围为包含两端的数值区间；每个实现写出自己的范围和必需能力。API 存在性检查用于能力确认，不能单独证明业务语义兼容。延迟加载尚未就绪须与永久不支持区分：由相关就绪事件触发有界重试，不永久负缓存，也不轮询重试。
4. 已发布支持范围内，当前客户端必须恰好匹配一个实现。零匹配则不启用该 Provider，并提供开发诊断；多匹配是配置错误，拒绝启用。禁止依赖声明顺序或偷偷回退到其他客户端实现。
5. 选择出的实现所提交的 `scope` 必须准确对应它能执行的范围。例如正式服和经典服有不同版本区间，应分别在选中实现的 descriptor 中声明，不把两种版本强行塞进同一个全局 min/max。文档／测试矩阵描述这个 Provider 的整体支持并集，当前注册描述当前实现的真实支持范围。
6. 同一 ID 在一个 Host 内只注册一次。不能同时注册四个同 ID descriptor，期待 Host 自动挑选；也不能把尚未支持的 `variants`、`implementations` 等字段塞入 RegisterProvider。
7. 会话中不轮询客户端身份。只有确有运行时能力变化时才设计切换；切换先取消并清理旧实现、注销旧句柄，再注册新实现，旧异步回调不得写入新实例。

推荐目录形状（示意，不是必须的目录名）：

```text
MyAddon_Mainline.toc -> Shared.lua + RetailAdapter.lua + Register.lua
MyAddon_Mists.toc    -> Shared.lua + MistsAdapter.lua  + Register.lua
MyAddon_Wrath.toc    -> Shared.lua + TitanAdapter.lua  + Register.lua
MyAddon_TBC.toc      -> Shared.lua + AnniversaryAdapter.lua + Register.lua
```

Register.lua 只调用插件已选中的适配模块。以下 `client`、`SelectAdapter` 和 `CreateDefinition` 都由接入插件实现，不是 Lychee API：

```lua
local function RegisterForClient(SDK, client, SelectAdapter)
    if not SDK or not SDK:Supports(2, 2) then
        return nil, { code = "UNSUPPORTED_API" }
    end
    -- SelectAdapter verifies product, numeric ranges and capabilities.
    -- It must reject both no match and overlapping matches.
    local adapter, err = SelectAdapter(client)
    if not adapter then return nil, err end

    -- This factory builds only declarations and closures. No UI/events/timers.
    local definition = adapter:CreateDefinition(client)
    definition.id = "my-addon.equipment" -- same business identity in all clients
    definition.apiVersion = 2
    definition.minApiRevision = 2
    -- definition contains this adapter's version, title, scope, i18n,
    -- entries/query, actions/views and onEnable cleanup as needed.
    return SDK:RegisterProvider(definition)
end
```

不同业务逻辑的例子：同一个装备 Provider 在支持原生装备方案的客户端调用原生方案接口；另一个客户端若支持插件自建方案，可以读取插件自己的方案数据并使用不同动作。不能因为它们都叫“装备方案”就假定 ID、payload 或动作权限相同，也不能因此无证据地扩大内置装备方案 Provider 的支持范围。

## 公共结果与身份

- 各实现最终都输出现有 Entry/Action/View 协议。业务差异留在 Provider 内，不要求 Host 新增按游戏类别判断的分支。
- 只有确实指向同一业务对象的条目才复用 entry ID。不同系统的相同数字 ID 应命名空间化，例如 `native-set:7` 与 `addon-set:7`；不能让最近使用／固定项指向不同对象。
- resolve 必须按当前实现重新解析记录，校验对象仍存在且当前动作可用。其他客户端或旧 schema 的历史条目无法映射时返回不可解析，不能猜测替代对象。
- 跨客户端共享配置／缓存时至少隔离 product 与适配器数据 schema；语言、角色以及影响数据含义的 interface/build 同样纳入身份。适配器逻辑或 payload 含义变化时升级 schema，不能直接复用旧缓存。
- 保护动作仍通过 Host 支持的安全动作声明；不能把原本受保护的动作换成普通回调以绕过限制。

## i18n 与生命周期

每个选中实现仍须注册该 Provider 自己的 i18n。相同含义的 key 和翻译可共享；业务含义不同则使用不同 key。注册前合成所选资源，所有引用 key 必须在 enUS 基线中存在；不合并进 Host 字典，也不在运行时反复重建翻译表。动态 ActionResult.message 使用 handle:Text 得到字符串。

适配器模块加载、分支选择和 CreateDefinition 只构建静态声明／回调，不能创建业务 UI、扫描目录或订阅事件。只在 onEnable 启动当前实现；其他实现零事件、零定时任务、零业务 UI。onEnable 返回的清理函数负责取消订阅、任务和临时引用，避免又在 onDisable 重复释放。查询取消、战斗暂停、禁用、注销、迟到结果和重新启用都沿用 PERFORMANCE.md 门禁。

## 验收矩阵

每个实际声明支持的 product ×版本区间都单独验证，不用一个客户端通过代替其他客户端。至少覆盖：

- 每个区间的最小／最大值、相邻边界、未知客户端、缺失必需能力、零匹配和重叠匹配。
- 只选择一个实现、只注册一个 Provider，未选中实现未创建 Frame／事件／任务。
- 当前实现返回正确条目和动作；条目缺失、旧历史记录、异步取消、启停和安全动作约束。
- 中英文资源完整性、按 product/schema 隔离缓存、错误分支不污染其他版本数据。
- 对实际使用的 WoW API 记录对应 wowdoc product/ref/commit 证据；分别报告离线测试与客户端实机验证。

现有内置 Provider 已有差异实现实例：PlayerSpells 在现代与旧式技能书接口之间选择扫描路径，GameMenus 按客户端提供不同入口。之后新增或扩大支持范围时，必须按上述规则继续维护，而不是仅修改 products 数组。

## Lychee 内置实现的维护入口

上述公开约定保持不变。Lychee 仓库内的内置功能使用 `tools/client_manifest.json` 统一维护产品范围、必需能力和文件归属，由工具生成加载清单与运行时支持表；对应实现和语言资源放在 `package/Lychee/Builtin/<功能>/`。这是 Host 仓库内部的构建约定，第三方无需依赖 `LycheeInternal`、`Builtin.Support` 或此清单，仍使用自己的实现选择并注册普通 Provider。具体步骤见 [项目结构](../docs/PROJECT_STRUCTURE.md)。
