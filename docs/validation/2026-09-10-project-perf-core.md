# Core 全量性能审查与优化

基线：`4e12531`。范围：`package/Lychee/Core/*.lua` 共 10 个文件。按照根目录 `PERFORMANCE.md`，只修改有复现或分配测量依据的路径。所有数字来自 Windows / Lua 5.1 离线替身，**不是 WoW 插件内存、帧时间或战斗 CPU 实测**。

## 发现和修复

| 级别 | 发现与证据 | 处理 |
| --- | --- | --- |
| P1 | Scheduler 在回调中 Add 会延长本轮；重入会再次执行自己；回调替换自身后返回 false 会删除新任务 | 本轮 key/version 快照，下轮执行新订阅，重入短路，旧完成只移除同版本任务 |
| P1 | 直接调用 Providers:Search 200 次有 200 个未完成 jobs；旧 Provider revision 的 reply 仍可提交 | 在 Provider 边界取消上轮，取消回调重入使用捕获的 epoch，reply 校验 revision / dynamicEpoch 并结束失效 job |
| P2 | Registry:RegisterReady 的 Cancel 只清 callback，2,000 次后留 2,000 个空壳，GC 后约 156 KiB | Cancel 定向移除待执行条目并保持注册顺序；SetReady 仍先分离队列，支持回调中取消别人 |
| P2 | Boundary 逐条构造不变 allowed-key、action-kind、text-field 和默认 options 表 | 仅把不可变规则移至模块局部常量；每次校验的 seen 表仍独立，保持重入与 secret 检查 |

Scheduler 故障 callback 仍向 WoW 报错，但先移除故障订阅并清理快照和重入标记，避免同一订阅每帧重复失败。调度数组与快照上限为 256，Add 超限显式返回 `false, "TASK_LIMIT"`；满额替换仍允许。256 是与现有单扩展 256 declarations 同量级的内部防御容量，不是玩家操作队列；SDK 没有 Scheduler 入口且当前没有生产订阅调用点（全仓检索），因此不会丢弃已存在的玩家动作，也不宣称实时 CPU 收益。首个订阅才创建 Frame，最后一个移除时 Hide。

## 覆盖清单

| 文件 | 审查结论 |
| --- | --- |
| Boundary.lua | 已优化固定规则分配；保留逐值 secret/access 校验、深度和字段限制、递归环检测。未引入全局 seen/scratch |
| Scheduler.lua | 已修复 Add/Remove/替换/Clear/重入/异常；swap-remove 仍 O(1)，本轮最多执行入口时的 256 项 |
| ProviderRuntime.lua | 已修复查询积压和迟到回复。静态数据上限 4096、动态单次 256、诊断 32；resolved 弱值由可见 item 强持有。Update 原本已增量 ApplyDelta 且采用 canonical 记录，未改回全目录重建 |
| ExtensionRegistry.lua | 已清理取消的 ready 订阅；注册事务回滚、owner/user enable、注销清理索引/能力/面板均复核。SearchSource token 自动提交检查 currentEntry 与 generation；外部记录仍校验后复制 |
| CommandCatalog.lua | 无查询字符串缓存；静态索引有启停/注销；返回 command/payload 副本用于调用方所有权，不合并为共享 scratch。ambient 列表按注册声明有限，用户输入不增加条目 |
| CapabilityBroker.lua | 注册时复制 schema、一次排序；查询只遍历目标 capability 的 provider 并保留 fallback；无历史查询缓存。任意第三方同步 callback 不能被宿主抢占，未添加无证据的结果缓存 |
| ContextStore.lua | 仅具名 slice/version；相同 data 引用 Set 短路；Snapshot 是新容器，避免重入覆盖。当前无 Context:On 动态注册调用点。监听生命周期按当前固定宿主模块分析，未宣称对任意新调用天然有界 |
| UserPreferences.lua | Pin/Restore 正常 API 上限 64；Resolve 可能受外部 context 影响，不跨调用强行缓存；旧字符串迁移保留未解析值是恢复契约，不删除。手改 SavedVariables 可超过 64，不能宣称原始输入天然有界，见例外 |
| IntentRouter.lua | handler 按 capability type/extension 注册并注销；执行只访问目标类型，检查 owner/战斗/schema；不引入权限/动作结果缓存 |
| ResultActionExecutor.lua | visible/session/generation/owner/Provider current 检查完整；动作菜单捕获 item 身份；drag 与 secure 目标已有变化检查。没有新增 timer、常驻工作或全目录扫描 |

## 成本、所有权与边界

- Boundary：每次注册、增量更新、动作边界触发，成本 O(输入字段数)。固定规则为模块所有者的有限只读表；seen 仍是每次调用独立短期表，不跨回调共享。保留外部 SDK 输入与执行参数的复制隔离。
- Provider：一次活动搜索代次最多每个符合条件的 Provider 一个 job，即 O(活动 Provider 数)，每个回复最多 256 records；连续查询不增加代次数。取消/禁用/注销结束 timer 与 cancel，过期 timer 再调用时短路。合法第三方持有 reply 闭包的寿命由第三方决定，不能声称全部释放。
- Scheduler：有界 256 个任务，当前 tick 最多入口数量；快照数组重复复用、每格消费后清空，异常时清尾。相同 key 替换增加 version，旧 false 不会误删 replacement；失效任务不会执行。增加一次 O(N) 快照和逐 callback pcall，换取确定的轮次与故障退出。
- Registry ready Cancel：保留顺序所以删除成本 O(待执行 ready 订阅)，发生于启动/取消低频路径；本次修复取消空壳，不设改变 SDK 接收能力的新总注册限额。活动订阅由实际 SDK 注册者数量决定，不随已取消请求增长。
- 当前 Provider 单条更新依旧是已有增量路径；本轮降低重复验证中不变规则表的分配，没有移除安全复制，也没有声称改变全目录算法复杂度。

## 前后测量

原始输出：

- [交替运行的 Core 测量](../architecture/2026-09-10-project-perf-core-measurements.json)
- [仅替换 Core、其他模块固定基线的 Provider 测量](../architecture/2026-09-10-project-perf-core-provider-isolated.json)
- [旧版本请求积压复现](../architecture/2026-09-10-project-perf-core-provider-reproduction.json)

两次 baseline/working 交替；每次 Boundary/Provider 各 5 个样本。Boundary 先预热 100 次，随后每样本 10,000 次固定记录校验；关闭 GC 只用于累计分配测量，之后恢复。Provider 固定 500 条目录，每样本 100 次单条更新。Lua os.clock 分辨率约毫秒，不将小差异解释成稳定速度收益。

| 测量 | 基线 | 修改后 |
| --- | --- | --- |
| Boundary 10,000 校验累计分配（交替原始输出稳态） | 23,594 KiB | 3,750.5 KiB（约降低 84%） |
| Boundary 时间，10 样本中位数 / 最大 | 133 / 140 ms | 114.5 / 153 ms |
| Provider 单条更新 100 次，Core 隔离对照稳态分配 | 840.72 KiB | 600.10 KiB（约降低 29%） |
| Provider 同组时间中位数 / 最大 | 4 / 5 ms | 4 / 5 ms |
| Scheduler 256 空回调 × 1,000 ticks，总时间 | 16–17 ms | 34 ms |
| Scheduler 同组累计分配 | 0 KiB | 0 KiB |
| 2,000 ready 注册后取消，待执行空壳 | 2,000 | 0 |
| 2,000 ready 注册后取消，GC 后保留增量 | 156.06 KiB | 无正增长（原始约 -0.9 KiB，包含其他短期对象回收） |
| 连续直接搜索 200 次未回复，jobs | 200 | 1 |

Boundary 单独后续运行稳态约 3,125.5 KiB，属于 Lua 表内存布局/进程差异；报告采用保存的交替组 3,750.5 KiB，不择优挑选数字。Boundary 最大值没有下降，不能声称尾延迟改善。Provider 收益是分配下降，计时持平。

Scheduler 正确性增加约 0.017–0.018 ms/tick（256 空 callback），修改后平均约 0.034 ms/tick；这不是最大单 tick 或真实游戏帧时间。单个第三方同步 callback 无法抢占，256 数量限制不能替代 callback 内部时间预算。未新增 profiling 或 GC 到运行时代码。

## 验证命令与实际结果

新增测试：

```text
lua tests/performance_core.lua
lua tests/perf_core_provider.lua
```

默认模式同时执行分配预算和全部正确性回归，**不需要 `--check`**：每个 10,000 次 Boundary 校验样本须低于 8,192 KiB；每个 100 次 Provider 单条更新样本须低于 768 KiB。阈值依据为保存的当前冷/稳态最大约 3,752.5 / 625.5 KiB，分别留下约 4,439 / 142.5 KiB 余量，容忍 Lua 分配布局差异；原基线约 23 MiB / 866 KiB 会失败。不对毫秒级抖动设置 CPU 硬阈值。

预算回归实测：archive `4e12531` 的两个默认测试均在预算断言退出 1（Boundary 22,969 KiB，Provider 866.13 KiB）；当前代码均退出 0（本轮最大 Boundary 3,752.24 KiB、Provider 597.38 KiB），且后续全部正确性断言保留并通过。原始 [预算红绿结果](../architecture/2026-09-10-project-perf-core-budget-results.json)。`--measure` 在旧版和新版均仅测量、不执行预算及期望旧版失败的回归，适合持续对照。

实际结果：PASS。前者先在旧调度器复现 Add 本轮生效，再在修复后复现 Ready 空壳；后者旧版打印 pending jobs=200 后失败，修改后 pending jobs=1 并通过旧版本回复、取消重入、注销清理断言。调度器覆盖 Add、同 key 替换、回调移除其他任务、Clear 后重建、重入、异常恢复、满额拒绝和满额替换。

既有 `provider_sdk_smoke`、`framework_sdk_smoke`、`command_catalog_smoke`、`capability_broker_smoke`、`search_session_smoke`、`interaction_smoke` 全部 PASS，包含 SDK 外部修改隔离、原 canonical 所有权和增量更新事务检查。Core 所有 Lua 文件 `luac -p` 通过，`git diff --check` 通过。`wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest` 返回 `valid=true`、`checkedLua=39`、`diagnostics=null`，见 [原始验证输出](../architecture/2026-09-10-project-perf-core-validate.json)。

测量参数：`LYCHEE_PERF_ROOT` 指向基线 `package/Lychee/`，默认当前运行时；Provider 还可设置 `LYCHEE_PERF_CORE_ROOT=package/Lychee/`，保证非 Core 固定基线。`--measure` 只运行可比较测量，不执行期望旧版失败的回归。

## WoW 版本证据

执行 `wowdoc source check --source wow-ui-source --product retail`：本地与远端均为 `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。所有查询 sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit 同上。

完整 path、line、excerpt 位于 [wowdoc 证据](../architecture/2026-09-10-project-perf-core-wowdoc.json)：

- `UITimerDocumentation.lua:39`：NewTimer 参数 seconds / TickerCallback，返回 cbObject；保留已有 NewTimer/Cancel 使用，不新加计时接口。
- `FrameScriptDocumentation.lua:263`：issecretvalue；`:65`：canaccessvalue；`:48`：canaccesstable。边界优化未移除或缓存这些安全检查结果。
- `Blizzard_AccountStoreCardTemplates.lua:96`：原生 OnUpdate(dt) 源码回调证据；调度器保留现有 Frame/OnUpdate/Hide 接口。

## 未完成与风险

登录、站立空闲、单目标战斗、多目标/团本、姓名板峰值、设置页开关的真实 CPU/帧时间/taint/secret 环境尚未实机测量。离线替身只能证明逻辑和 Lua 分配，不冒充这些场景已通过。最终完整契约测试、提交与正式服同步由主 Agent 集成执行。

并未为任意第三方同步 callback 加抢占机制，也没有全局限制所有合法注册的 Provider 数量；job 数按活动 Provider 数线性有界。长期保留的 SDK handle/第三方 reply 可以合法持有对象，不能称为彻底卸载。回滚应使用最终集成提交的 git revert，再遵循仓库的验证、提交、覆盖同步流程。

异常 SavedVariables 例外：用户直接改写 `palette.pinned` 可以绕过正常 API 的 64 条上限，MigratePins 和设置数据列表仍可能处理超额旧记录。没有自动裁剪、删除或静默隐藏用户固定项；仅靠修改返回数组截断会妨碍用户查看/移除旧数据。本轮明确记录这一剩余限制，后续需要带可见提示的有界迁移与分页读取，而不能用丢弃数据冒充优化。正常 64 条以内路径不受影响。
