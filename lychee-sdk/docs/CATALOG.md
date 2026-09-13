# 公共能力与目录所有权

SDK 1.0.0 / API 1.0.0。公共能力解决独立接入也需要的问题，不能要求使用荔枝项目的目录结构或启动模板。

| 能力 | 实际用途 / 最小输入输出 | 所有权与生命周期 |
|---|---|---|
| RegisterProvider | 声明查询、动作、范围和词典 → 注册句柄 | Host 保存声明和有界查询结果；注销撤销身份。 |
| CreateCatalog | 声明目录的身份/范围/能力，Update 普通记录 → Search 候选或 Query 回复 | 调用者持有目录；Host 不维护全量目录注册表。Clear 释放数据，Close 退休对象。 |
| Score | 请求、已筛选的普通条目、可选 scope → 评分候选 | 无业务缓存；调用方仍负责候选筛选。 |
| CreateRanker | 查询快照 → `rank(entryID, confidence)` | 每查询创建一次，只持有本来源的有界偏好副本；逐候选标量计算，用于截断前排序。 |
| SortHits | 请求、已评分候选、可选输出上限 → 排序后的新数组 | 批量合并使用同一排名；不改写输入顺序或候选内容，新数组共享调用者提供的 hit 对象。 |
| CompileLocales | 独立语言资源 → 翻译器 | 调用者持有；不依赖项目 Manifest。 |
| Resources | 有界事件、任务、计时器和清理函数 → 可取消句柄 | Provider/query/view 三类明确作用域；结束自动清理已登记资源。 |
| Storage | 自己的 root/ready 函数、版本和迁移 → 存储访问器 | 子插件拥有 SV；Host 不持有或扫描该业务根。 |
| WhenSavedVariablesReady | AddOn 名和回调 → Cancel 订阅 | 只等该 AddOn 就绪；最多 64 个待处理项，无常驻轮询。 |
| RuntimeIdentity.Current / Normalizer | 当前客户端快照 / 文本匹配工具 | 无 Provider 业务目录；调用方不访问 Host 私有状态。 |
| UI / Motion / View | 描述、容器、状态 → 可复用页面和动效 | 页面内容和业务绑定属于调用方；关闭解除活动引用。 |

项目的 Bootstrap、Activate、Manifest、Modules、CatalogProvider、CatalogLedger 是包内协作，不是 SDK。第三方不需要采用它们，也不需要统一自己的业务生命周期。不要为减少少量重复代码新增公共装配框架。

## Catalog 接口

`SDK.CreateCatalog({id,title?,scope?,i18n?,actions?,drags?,views?,active?,changed?})` 返回独立目录。配置先校验再复制；active() 是调用方可选可用性检查，changed() 是成功且有变化后的通知，通常调用注册句柄 Invalidate。通知可以读取已提交目录；不要在通知里无条件反复更新自身。

- `Update({replace=entries})` 或 `Update({upsert=entries,remove=ids})`：原子提交，最多 4096 条；失败保留旧数据，无变化不通知。
- `Search(request)`：返回公开候选副本；修改返回值或原输入不会改写已提交数据。
- `Query(request,reply)`：直接完成当前 Host 查询；不用先生成一整批公开副本。只能使用 query 回调取得的真实 reply；普通外部函数、取消后或已完成的回复返回 STALE_REQUEST。query 本身仍返回 nil 或取消函数。
- `Resolve(id)`：返回公开条目副本；Host 最近使用恢复仍需 Provider 声明 resolve 回调。
- `GetState()`：revision、entries 数量副本。
- `Clear()`：释放目录、索引和上次候选引用，可再次构建；`Close()` 永久退休，后续读取/更新返回 CATALOG_CLOSED。

Search/Query 的 normalized 必须为字符串且最多 1024 字节；可选 limit 为 1–256 整数、preferredEntryID 为最多 128 字节的字符串、filter 为普通表。输入同样拒绝 secret、不可访问表和 metatable。

`ranking?` 是本 Provider 的 entryID → 整数权重表，最多 72 项，每个 ID 遵循 Entry.id，权重 0–38。Host 从最多 64 固定项（30）和 8 最近使用（从新到旧 8–1）生成快照；重合项相加。没有使用次数或时间戳。Catalog Search/Query 自动在候选截断前应用它及 preferredEntryID，原 confidence/evidence 不变。

## 动态查询的排名

在 query 开头调用 `local rank, err = SDK.CreateRanker(request)`，校验失败返回 nil, Error。成功得到普通函数：`rank(entryID, confidence)` 返回排序值；confidence 为 nil 时返回 nil，其他有效输入是 0–1 的有限数字，entryID 为 1–128 字节字符串。非法或不可访问参数返回 nil, Error。返回值仅用于排名，不可写入回复的 confidence。

排名值 = confidence + ranking[entryID] × 0.001；preferredEntryID 命中再加 2，保留同一搜索词的上次选择优先行为。相同排名值先比较原 confidence，再沿用来源自己的稳定次序。Host 最终以自己的原始快照重算；修改 Provider 收到的请求不能修改 Host 偏好。已创建 ranker 不受原 request 后续修改影响，也不持有整个请求、context 或 Provider 目录。

动态来源先按业务/文本筛选，再对**每个命中的候选**调用 rank，按排序值维护前 request.limit 项，最后只物化选中项。不要先截断再调用 rank，也不要因被固定而跳过业务资格、来源过滤或条目可用性检查。一个对象存在多个可返回身份时，选择代表结果的内部截断也使用相同规则。参考 [DeferredProvider](../examples/DeferredProvider.lua)。

`SDK.Score` 继续只生成匹配分数与证据，不自动排序或过滤，无法找回调用方已经丢弃的候选。使用自有检索引擎的第三方来源需要在自身截断前接入 CreateRanker；使用 Catalog 的来源自动获得该行为。查询完成或取消后释放 ranker 和候选；不缓存跨查询偏好、不创建后台更新任务。

已拥有一批评分候选时，用 `SDK.SortHits(request,hits,limit?)` 先排序再截断。最多接收 276 项（20 个 Catalog 候选与最多 256 个动态候选的合并容量），可选输出 limit 为 1–256 整数；不传 limit 则保留全部。`reply` 仍最多 256 项，最终展示仍最多 20；不扩大查询协议容量。结构、有限 confidence、ID 和不可访问值在排序前校验；失败返回 nil, Error。相同排名先比较原 confidence、category.order（缺失按 0）及 entry.id。该函数只创建排序数组，共享调用方 hit 对象，不修改匹配证据，也不会找回此前丢弃的候选。

直接交付仍检查实际 Provider 的 scope/actions/drags/views。定义不一致时走普通回复校验，不能用另一个 Catalog 声明绕过动作权限。内部索引和传递凭证不公开；接入方不能依赖内部快路径、字段位置或投影的 metatable。

目录不是持久数据库，也不自动订阅事件。何时加载、增量更新、禁用释放、是否复用以及如何取消，均由拥有它的 Provider 决定。关闭面板时应释放查询候选；必要的轻量数据更新事件可保留。容量和性能验收引用[性能硬门禁](PERFORMANCE.md)，不用压缩字段位置换取耦合。
