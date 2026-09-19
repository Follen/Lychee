# 搜索入口与可选目录

SDK 1.0.0 / API 1.0.0。当前分支保留单插件版索引，不迁入十包版整套搜索引擎。所有接口都使用公开具名数据；内部字段、索引对象和传递凭证不是协议。

## 选择最简单的入口

| 场景 | 入口 | 数据所有权 |
| --- | --- | --- |
| 少量简单入口 | RegisterProvider 的 entries；变化时 handle:Update | Host 保存有界、校验后的搜索条目；业务事实归 Provider。 |
| 有界目录、完整动作构造昂贵 | RegisterProvider 的 entryMode="documents" + readEntry | Host 只保存搜索文档；完整 Entry 只活在候选/动作引用中。 |
| 已有自有检索逻辑 | query / resolve | 只交当前查询候选，Host 不取得业务 DB。 |
| 希望自己持有可增量搜索目录 | SDK.CreateCatalog，默认 mode="entries" | 调用者持有目录，Host 没有 Catalog 总注册表。 |
| Entry 构造昂贵且测量证明收益 | 可选 mode="documents" + readEntry | 先索引搜索字段，命中后从本插件事实生成 Entry。 |
| 有明确容量和隔离要求的存储 | 可选 CompactStore | 本插件持有实例；没有自动 SV、业务失效推断或 Host 数据库。 |

别因为目录规模大就默认选择 documents 或紧凑编码。比较同样查询的召回、构建、热查询耗时、临时分配与关闭后的保留内存；复杂度本身不是优化收益。

## Catalog 方法

`SDK.CreateCatalog({id,title?,scope?,i18n?,actions?,drags?,views?,active?,changed?,mode?,readEntry?,compact?})` 返回调用者拥有的目录，错误返回 nil,Error。配置必须是可访问的普通数据。

| 方法 | 合同 |
| --- | --- |
| Update({replace=records}) | 原子替换；不能与 upsert/remove 混用，失败保留旧代。 |
| Update({upsert=records,remove=ids}) | 原子增删；ID 唯一，不允许同批写入与删除冲突。 |
| Search(request) | 同步返回候选副本或 nil,Error，不执行动作。 |
| Query(request,reply,context) | 按合同返回有界候选；documents 可利用 query 资源分批。 |
| Resolve(id) | 恢复当前 Entry；documents reader 可恢复不在搜索目录中的明确 ID。 |
| Invalidate() | 使当前查询与生成代失效；不替 Provider 获取业务事实。 |
| GetState() | 只读标量摘要，逻辑 bytes 不是 Lua 堆统计。 |
| Clear() / Close() | 清搜索数据 / 永久退休；业务数据库由 Provider 自己处理。 |

默认容量 4096；更大 documents 目录必须显式声明 compact 容量并验收。最大回复 256 条，最终展示仍最多 20 条。changed 在成功提交后的变化通知中执行；通知抛错不代表提交回滚，应查询当前代次，不盲目重复操作。

```lua
query = function(request, reply, context)
    local ok, err = catalog:Query(request, reply, context)
    if not ok and err then context.fail(err) end
end,
resolve = function(id) return catalog:Resolve(id) end,
```

不能 `return catalog:Query(...)`：其布尔值不是 Provider 取消函数。Catalog 输出仍经过公开 Provider 回复边界，不承诺零复制内部通道。关闭、取消、更新、Clear 和 Close 都必须释放当前任务与候选引用。

## documents 与 reader

SearchDocument 只含 `id/title/aliases/keywords/description/category/scope/subtitle/subtext`。ID 和非空标题必填。不要把动作、Frame、回调或业务数据库塞入文档，也不要删掉原有可搜索字段来降低内存。

`readEntry(id,{ref,revision,reason,resources?})` 同步返回当前 Entry 或 nil,Error，不执行动作，不 yield。ID 必须一致，动作和页面必须属于该目录声明。nil 表示事实确实缺失；临时读取失败应返回 Error，不能当成成功零结果。SDK 只按命中生成有界候选，容量耗尽但无法确认完整结果时报告 RESULT_LIMIT。

从搜索文档移除 ID 不等于删除业务对象；明确恢复仍由 reader 判断。Provider 负责事件、事实变更和 Invalidate。Catalog 不自动订阅业务事件或持久化。

## 查询、排名和失败

`SDK.Score(request,entries,scope?)` 对有限条目计算匹配；`SDK.CreateRanker(request)` 返回本次查询排名函数；`SDK.SortHits(request,hits,limit?)` 返回排序数组。自己筛选候选时先排序再截断，不能以固定偏好绕过业务资格。preferredEntryID/ranking 只携带本 Provider 普通条目的偏好；具体参数调用不会被压成同 entryID 的统一加权。Host 收到候选后按完整引用处理参数偏好，但不能恢复 Provider 已经截掉的候选。动作身份仍由完整目标、动作、版本与参数决定。

`context.deadline` 是 SDK.Now() 的绝对秒，发现、加载、准备、查询共享截止，不能每个阶段续五秒。`context.fail(Error)` 表示本来源不完整；`reply({})` 才表示成功零结果。回调完成或取消后释放 request/context/ranker，不缓存跨查询偏好。具体错误边界见[协议](PROTOCOLS.md)。

关闭“参与搜索”只撤搜索工作，不等于所有者停用，不能阻断固定项的明确恢复或必要后台通信。资源和存储分别见[生命周期](RUNTIME_LIFECYCLE.md)及[存储](STORAGE.md)。

## 在 Host 索引中延迟生成动作

SDK / Provider API 固定为 **1.0.0**。`RegisterProvider` 可选 `entryMode="documents"`，必须同时提供 `readEntry`；默认 `entries` 模式保持完整 Entry 接入。两种模式的 `handle:Update` 方法相同，分别接收 SearchDocument 或 Entry，不能混用。容量仍为 4096 条。

```lua
local facts = { volume = { name = "Volume" } } -- Provider owns business facts
local handle = assert(Lychee:RegisterProvider({
    id = "example.settings", title = "Example", apiVersion = "1.0.0", version = "1.0.0",
    entryMode = "documents",
    entries = {{ id = "volume", title = facts.volume.name }},
    actions = { open = { title = "Open", run = function(entry)
        -- Open this Provider's own setting using entry.payload.key.
        return { ok = true }
    end } },
    readEntry = function(id, context)
        local fact = facts[id]
        if not fact then return nil end
        return { id = id, title = fact.name, payload = { key = id }, actions = { "open" } }
    end,
}))
```

Host 使用原有索引、排名和筛选，在最终静态候选上调用 reader；不会先为整库生成动作，也不会额外创建一套 Catalog。`readEntry(id,{ref,revision,reason})` 同步、无副作用、不 yield，不扫描整库、不写设置。reason 为 query 或 resolve。一次查询通常最多读取 20 个静态候选；一次搜索若因动态来源完成而重新合并，可能再次读取。调用次数不是长期缓存承诺。

reader 返回的 ID 必须一致，完整 Entry 仍经过输入隔离、动作与作用域校验。错误返回 nil,Error；抛错、非法结果、目录版本改变或所有者注销都会拒绝本次读取。命中文档却读不到 Entry 时，本次搜索标记不完整；不会静默显示为成功零结果。当前静态候选窗口不为缺失记录无限补扫。Provider 应通过 Update 删除确定失效的文档，暂时不可用返回明确错误。

Host 只用弱引用登记物化记录的合法身份，不持有全量动作缓存；当前可见行、正在执行的动作或调用方仍可保有记录。Update/Invalidate 使旧身份失效。明确恢复可以读取不在搜索文档中的 ID；关闭“参与搜索”不阻止明确恢复。所有者停用或注销仍拒绝读取。

小目录、简单且已经共享动作的 Entry 通常更省 CPU；不要仅为统一风格迁移。documents 用减少常驻动作换取每个候选的读取与校验开销，必须测冷/热延迟和分配。不要同时向 Host 和 CreateCatalog 提交同一套文档。调用方确需自持目录、独立检索时才用 CreateCatalog。

CreateCatalog 的 documents 查询先取 request.limit 个命中；仅在缺失或完整引用去重导致不足时补查，最多检查 256 个完整候选，无法确认完整性时报 RESULT_LIMIT。托管查询按 1ms 或 256 个检查点让出；暂停时间不消耗模糊匹配 CPU 时间预算。单个第三方 reader 或原生 API 不可抢占。
