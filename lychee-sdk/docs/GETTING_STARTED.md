# 接入 Lychee SDK 1.0.0

使用 Provider API 1.0.0。不兼容 API 2；运行时入口是 `_G.Lychee`，开发包不是另一个 AddOn。先阅读[协议](PROTOCOLS.md)、[性能规范与审查](PERFORMANCE.md)和[能力边界](CATALOG.md)。

## 先选一条路径

| 需求 | 从哪里开始 | 暂时不用做什么 |
| --- | --- | --- |
| 已加载插件提供几条入口 | 下方最小接入；可运行 [ThirdPartyFixture](../examples/ThirdPartyFixture/ThirdPartyFixture.lua) | 不必声明冷加载，不必建立 Catalog |
| 独立 AddOn 仅在命中入口时加载 | 完整 [ColdProvider](../examples/ColdProvider/README.md) 与 [TOC 合同](LOADING.md) | 不必照搬 Host 工程或写一个 Lua manifest |
| 参数动作或自有大目录 | [Invocation](INVOCATIONS.md) / [Catalog](CATALOG.md) 的示例与合同 | 两者可独立使用，紧凑存储仍是可选项 |

第三条不是升级所有普通 Provider 的要求。先让最小条目和普通动作跑通，再为真实业务添加能力；`prepare` 仅用于确实需要的数据准备，不能为了使用冷加载而强加一个异步层。

## 最小可用接入

独立的 Lychee 扩展在自己的 TOC 声明 `## Dependencies: Lychee`，拥有自己的代码、SavedVariables、媒体和许可。已有插件只把 Lychee 作为可选集成时可用 `OptionalDeps`，并在缺少 Host 时保留自身功能。以下是已加载插件的最小注册路径，只使用公开 SDK，不需要荔枝的目录、Manifest、Modules 或启动模板：

```lua
local api = _G.Lychee
if not api or not api:Supports("1.0.0") then return end
api:RegisterReady(function()
    local handle, err = api:RegisterProvider({
        id="example.settings", apiVersion="1.0.0", version="1.0.0",
        title="Example", scope={products={"retail"}}, i18n={enUS={}},
        entries={{id="settings",title="Example settings",actions={"open"}}},
        actions={open={title="Open",run=function()
            print("Example opened") -- 换成已验证的普通业务动作。
            return {ok=true,close=true}
        end}},
    })
    if not handle then error(err.code) end
end)
```

这个来源不需要实现 query、prepare、Invocation 或存储编码。Host 校验并索引有界普通条目；业务事实仍由 Provider 所有，变化后用 `handle:Update` 提交。第三方不读 Host 私有表。若自己已有查询逻辑，可只实现 `query/resolve`，返回普通条目或评分候选。

`query` 返回 nil 或取消函数，不能 `return reply(...)`：回复返回布尔状态，不是取消函数。同步和异步查询都最多成功回复一次；失败使用 `context.fail`，不能用空结果掩盖失败。

## 按需加载与客户端

新包需要加载前被搜索发现时，按 [LOADING](LOADING.md) 在原生 TOC 声明版本化 `X-Lychee-*` 元数据，并声明 `LoadOnDemand`。一个包可以注册多个 Provider；加载后的 `addon`、范围、路由和资源必须与冷声明一致。Host 不执行 Lua Manifest 来发现来源，也不自动启用原生禁用的插件。无冷声明的旧 1.0.0 包仍可使用上面的加载后注册路径。

使用新增能力前，先检查 `SDK.SupportsFeature` 是否存在，再检查所需的 `discovery`、`preparation` 或 `invocation` 能力。`Supports("1.0.0")` 只代表 API 版本匹配。`SDK.GetClient()` 返回隔离的 `{product,interface,build,locale}` 快照；Provider 根据这些事实选择自己已验证的实现和范围，不能仅扩大 products 数组就宣称支持新客户端。详细规则见 [CLIENT_VARIANTS](CLIENT_VARIANTS.md)。

等待 `RegisterReady` 和本包 `SDK.WhenSavedVariablesReady` 后注册；二者都可能同步回调。查询共用一个从用户请求开始的截止时间，发现、加载、存档、准备和 query 不各自重新计时。可选 `prepare` 只准备本包数据，不写业务、不发布搜索结果；参数调用的只读准备使用独立的 [Invocation](INVOCATIONS.md) 合同。

## 谁保存数据

普通 entries 模式允许 Host 索引有界条目副本，不能据此把业务数据库交给 Host。自有 query 模式只交当前查询候选；需要自己拥有搜索目录时选择 [CreateCatalog](CATALOG.md)。动态数据也可自行筛选、评分，只要满足相同结果合同。

每个结果最多包含当前展示和动作所需数据。旧 Entry 使用 `resolve(entryID,context)` 恢复；新稳定引用区分 `legacy-entry`、`target`、`command` 和 `invocation`。具体 Invocation 保存完整动作/版本、目标/版本及规范化参数，恢复时可异步等待目标和能力就绪，不重新搜索同名对象，也不在恢复时执行。固定、历史和别名保存有界引用而非业务目录；不能用 entryID 排名提示替代完整引用身份。一次性动作可设 `rememberable=false`，细节见 [Invocation 的恢复合同](INVOCATIONS.md#storedref-分支)。

## 搜索入口

`searchGlobal` 默认 true；`searchPrefixes` 和 `searchKeywords` 各最多 8 项，支持空数组。前缀 `example:内容` 限定来源，触发词 `example` 将请求转换为该来源的空查询。声明 `searchGlobal=false` 时须保留至少一种路由。用户可以覆盖这些配置，也可以关闭整个来源的“参与搜索”；后者排除普通搜索、前缀和关键词等搜索入口，但不撤销固定/最近项的显式恢复，不停止后台或已提交业务操作，不调用 `onDisable`。

## 生命周期和数据库

必要的数据更新事件由包所有者管理，查询任务放在 query 的资源作用域，页面订阅放在当前 view 的 `context.resources`。已提交 Invocation 属于 Provider 操作作用域；关闭页面撤掉 UI 监听，不等于撤销已发生的业务。采用 SDK 资源工具不免除业务分批和容量责任；见[生命周期](RUNTIME_LIFECYCLE.md)。

数据库由自己的 TOC 声明并由自己的 AddOn 所有。等待自身 SavedVariables 就绪后，将根函数交给 [Storage](STORAGE.md)。角色设置用 `SavedVariablesPerCharacter`；关闭面板不删除设置。第三方优先使用自己的独立 Storage；现有句柄 Settings 是有界角色设置入口，不用于存放目录或第三方业务数据库。

加载后接入例子见 [ThirdPartyFixture](../examples/ThirdPartyFixture/ThirdPartyFixture.lua)；可安装的冷加载包见 [ColdProvider](../examples/ColdProvider/README.md)，声明格式见 [LOADING](LOADING.md)，托管任务见 [ManagedProvider](../examples/ManagedProvider.lua)，页面见 [ComponentPanel](../examples/ComponentPanel/ComponentPanel.lua)。本包图标用公开资源描述，媒体随本包发行；不引用 Host 私有媒体路径。

## 搜索目录怎样选

| 你的数据 | 建议入口 | 需要实现什么 |
| --- | --- | --- |
| 几条到几百条简单入口 | Provider.entries | 注册普通 Entry，事件变化时 handle:Update，无需 query。 |
| 自己持有可增量搜索目录 | 可选 Catalog entries | Catalog:Update，query 调用 Catalog:Query，resolve 调用 Catalog:Resolve。 |
| 按命中生成Entry经测量有收益 | Catalog documents（可选） | 提交原本参与搜索的字段，readEntry按ID读取本包事实并生成当前Entry；不执行动作。比较热查询耗时与分配，不能只看保留内存。 |
| 已有查询/数据层 | 自有query/resolve | 保持统一排名、截止、取消和失败合同，不必迁移底层数据。 |

可选目录的字段与流程见 [CATALOG](CATALOG.md)。新能力使用前检查search-documents和query-failure；可选紧凑存储另检查compact-storage。普通作者不需要学习posting编码、Host内部类或项目装配。需要独立嵌入数据容器时读 [COMPACT_STORAGE](COMPACT_STORAGE.md)。

准备数据、参与搜索、执行动作和窗口关闭分别处理。关闭“参与搜索”只排除搜索；所有者停用/注销另行结束资源。明确恢复仍查本包事实。reader返回nil表示确实不存在，临时失败返回nil,Error；query使用context.fail报告不完整，不用空列表吞掉异常。异步Catalog:Query的布尔返回不能作为Provider.query的返回值，调用后检查同步错误并通过context.fail报告。

## 接入测试至少覆盖什么

直接向公开接口传原始定义，验证缺失必填字段和旧 API 被拒绝；不要让测试包装器补齐字段后宣称校验有效。覆盖连续输入取消、迟到回复、所有者停用/重新启用、搜索关闭仍可显式调用、动作身份失效、外部修改隔离、失败后重试，以及关闭后的资源回收。Catalog 与自己管理的动态 query 应接受同样的结果契约。

有数据库时测试自身存档恢复前后、根替换、角色隔离、迁移失败和未来 schema 保留；有页面时测试 Mount 失败、按下后重绑、关闭/重开和对象复用。原生 API 替身只提供外部输入，不实现 SDK 内部算法。离线通过后仍需目标客户端验证战斗、安全点击和显示效果；固定场景预算见[性能约束](PERFORMANCE.md)。
