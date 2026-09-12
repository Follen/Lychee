# 公共能力与目录所有权

SDK 1.0.0 / API 3。公共能力解决独立接入也需要的问题，不能要求使用荔枝项目的目录结构或启动模板。

| 能力 | 实际用途 / 最小输入输出 | 所有权与生命周期 |
|---|---|---|
| RegisterProvider | 声明查询、动作、范围和词典 → 注册句柄 | Host 保存声明和有界查询结果；注销撤销身份。 |
| CreateCatalog | 声明目录的身份/范围/能力，Update 普通记录 → Search 候选或 Query 回复 | 调用者持有目录；Host 不维护全量目录注册表。Clear 释放数据，Close 退休对象。 |
| Score | 请求、已筛选的普通条目、可选 scope → 评分候选 | 无业务缓存；调用方仍负责候选筛选。 |
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

直接交付仍检查实际 Provider 的 scope/actions/drags/views。定义不一致时走普通回复校验，不能用另一个 Catalog 声明绕过动作权限。内部索引和传递凭证不公开；接入方不能依赖内部快路径、字段位置或投影的 metatable。

目录不是持久数据库，也不自动订阅事件。何时加载、增量更新、禁用释放、是否复用以及如何取消，均由拥有它的 Provider 决定。关闭面板时应释放查询候选；必要的轻量数据更新事件可保留。容量和性能验收引用[性能硬门禁](PERFORMANCE.md)，不用压缩字段位置换取耦合。
