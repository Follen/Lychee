# 搜索入口与可选目录

SDK 1.0.0 / API 1.0.0。当前分支保留单插件版索引，不迁入十包版整套搜索引擎。所有接口都使用公开具名数据；内部字段、索引对象和传递凭证不是协议。

## 选择最简单的入口

| 场景 | 入口 | 数据所有权 |
| --- | --- | --- |
| 少量简单入口 | RegisterProvider 的 entries；变化时 handle:Update | Host 保存有界、校验后的搜索条目；业务事实归 Provider。 |
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

`SDK.Score(request,entries,scope?)` 对有限条目计算匹配；`SDK.CreateRanker(request)` 返回本次查询排名函数；`SDK.SortHits(request,hits,limit?)` 返回排序数组。自己筛选候选时先排序再截断，不能以固定偏好绕过业务资格。偏好仅用于排序，动作身份仍由完整目标、动作、版本与参数决定。

`context.deadline` 是 SDK.Now() 的绝对秒，发现、加载、准备、查询共享截止，不能每个阶段续五秒。`context.fail(Error)` 表示本来源不完整；`reply({})` 才表示成功零结果。回调完成或取消后释放 request/context/ranker，不缓存跨查询偏好。具体错误边界见[协议](PROTOCOLS.md)。

关闭“参与搜索”只撤搜索工作，不等于所有者停用，不能阻断固定项的明确恢复或必要后台通信。资源和存储分别见[生命周期](RUNTIME_LIFECYCLE.md)及[存储](STORAGE.md)。
