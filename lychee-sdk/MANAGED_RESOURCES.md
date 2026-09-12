# SDK revision 7：托管资源、设置与缓存

检查 `Lychee:Supports(2,7)`，Provider 声明 `minApiRevision=7`。公共普通记录、动作与现有更新协议不变。运行时只依赖 `_G.Lychee`，不得使用 `LycheeInternal`。旧 revision 1–6 的接入继续有效。

## 三种生命周期

| 取得方式 | 所属期间 | 自动结束 |
|---|---|---|
| `handle:Resources()` | 当前 Provider 启用期间 | 禁用、注销；重新启用得到新的作用域 |
| `context.resources`（query） | 单次查询 | 完成、换词、关闭、超时、错误、禁用、注销 |
| `context.resources`（view create/Mount/Update） | 单次页面挂载 | 替换、关闭、创建失败、禁用、注销 |

关闭面板不停止 Provider 的必要数据更新事件。仅通过 SDK 登记的资源受托管；直接创建的第三方计时器、事件和对象仍由作者负责。

## 资源作用域

| 调用 | 行为 |
|---|---|
| `Own(key, cleanup)` | 登记清理函数，返回 Cancel 句柄；同 key 替换旧登记。cleanup(reason) 最多调用一次。 |
| `After(key, seconds, callback)` | 可替换的一次性延迟。相同 key 合并为最新任务；0 表示下一次 timer 调度。0–3600 秒。 |
| `Run(key, work, handlers)` | 分批协程。work 可 `coroutine.yield()`，下一批用一次性 timer 续跑；返回 Cancel 句柄。 |
| `OnEvent(event, callback)` | 订阅普通事件，callback(event, ...)；同作用域同事件替换。返回 Cancel 句柄。 |
| `Cache(key, options?)` | 创建有界普通数据缓存；同 key 替换旧缓存。 |
| `IsActive()` | 当前作用域仍有效。 |
| `GetDiagnostics()` | 返回计数副本：active、resources、providerResources、errors、limit。 |

`Run` 的 handlers 只允许 `complete(value)`、`error(errorValue)`、`combat()`。work 返回值交给 complete；存在 combat 回调时，分批续跑前发现战斗就结束该任务并调用 combat。未声明 combat 时不自动改变业务的战斗策略。工作函数必须自行按数量/时间预算让出执行；SDK 不抢占同步 Lua，也不自动重试动作。

每个 Provider 跨 Provider/query/view 作用域合计最多 64 个登记（子作用域本身也占一个名额）。同类型 key 长度最多 96 字节；不同类型之间独立。关闭、替换、任务结束先摘除旧登记，再调用外部清理或结果回调；重入创建的新登记不会被旧调用覆盖。任务资源耗尽返回 RESOURCE_LIMIT，调用方必须处理，不能静默遗漏功能。scope 方法失败返回 nil, Error。

事件使用按需创建的共享 frame，无订阅时取消事件和脚本；没有新增常驻 OnUpdate。这是普通事件订阅，不把未过滤的高频 unit 事件包装成低成本能力。高频业务仍需限定事件与参数、合并刷新并遵守性能约束。

## 设置与缓存分开

`handle:Settings()` 返回当前角色、当前 Provider 命名空间的设置句柄：

- `Get(key, default?)`：返回副本；不存在时返回 default 的副本，不自动落盘。
- `Set(key, value)`：保存副本，nil 删除该设置；失败不覆盖旧值。
- 禁用和关闭不删除设置。注销使旧设置句柄失效；同 ID 新实例可以读取已保存的选择。
- 不开放账号范围写入，不自动迁移第三方自己的数据库。设置保存后如何更新业务目录由 Provider 决定。

`scope:Cache(key, {entries=32, bytes=32768})` 返回 `Get`、`Set`、`Clear`、`GetDiagnostics`。按写入顺序淘汰旧值，读取返回副本，不改变淘汰顺序。条数可配置 1–128，逻辑字节预算 1–65536；默认不预分配全部容量。单个值超预算时拒绝，保留旧缓存。作用域结束后清空并使旧缓存失效。

设置和缓存只接收普通数据：拒绝函数、frame/userdata、metatable、循环、不可访问/secret 值、NaN/无穷值；表键仅字符串或数字；复制过程中累计预算，超限立即停止。单值深度最多 6、最多 256 个遍历节点、逻辑大小最多 16384 字节。设置每 Provider 最多 64 键、总逻辑大小最多 65536 字节。逻辑大小按字符串字节数及每个其他节点 16 字节估算，用于稳定容量门禁，不等于 WoW 实际堆大小。

## 宿主强制门禁

- 当前身份、scope、用户禁用选择、查询代次、结果上限和输入隔离仍由 Host 检查，使用任务工具不能跳过。
- Update 保留原子提交、失败保留旧目录、无变化不提交的契约；不新增另一套目录更新入口。
- 普通动作、视图 state、硬件点击和受保护动作继续走统一执行器；没有通用安全脚本能力。
- 托管队列有限，取消后迟到回调不提交；页面创建到一半失败也清理已登记资源。
- 诊断按需读取，不扫描第三方内存，不承诺能控制未登记资源或抢占第三方同步代码。详细游戏性能测量继续使用显式启用的诊断包。

示例：[ManagedProvider.lua](examples/ManagedProvider.lua)。测试覆盖见 [SDK 托管测试](../tests/sdk_resources.lua)、[测试装配与门禁](../tests/README.md)。
