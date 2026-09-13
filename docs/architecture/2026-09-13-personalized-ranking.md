# 候选截断前的个性化排序

范围：扩展 SDK 1.0.0 的可选查询能力，让固定项、最近使用与同词选择记忆在 Catalog 和动态 Provider 的候选截断前生效。没有时间戳、次数、频率统计、上下文监听或新增持久字段。

## 规则与所有权

- 文本/业务匹配先决定候选资格，排名函数接收 nil 时仍返回 nil。固定与最近使用不能恢复禁用、过滤或不存在的结果。
- 原始 confidence/evidence 保持不变。排序值为 confidence + 固定项 0.030 + 最近使用 0.001–0.008；同词记忆额外加 2，保留既有优先语义。
- Host 每次查询冻结角色偏好。每个 Provider 仅收到自己的 `ranking`（entryID → 0–38 的整数，最多 72 项）与既有 preferredEntryID；不暴露其他来源的偏好。
- `SDK.CreateRanker(request)` 校验并复制偏好，返回 `rank(entryID, confidence)`；每查询创建一次，只在命中后、截断前调用。返回排序值，不能当作 reply.confidence。无偏好时保持原排序。
- Catalog 自动使用相同规则。动态来源使用自己的有界 Top K 容器与公共 rank 函数。Host 使用原始私有快照重算最终排名，Provider 修改请求不能改变 Host 偏好。
- `SDK.SortHits(request, hits, limit)` 为有界批次提供同一排序规则：最多接收 276 条（20 条 Catalog 与 256 条动态回复合并），只创建引用原 hit 的新数组，排序后才裁剪。自带 Bootstrap 模板统一使用它；流式扫描仍须在每一层候选截断前调用 ranker，包括 LDT 每个怪物的代表技能选择。
- 首页最近使用仍只保存 8 个稳定引用；固定项仍最多 64。记录操作收拢到 UserPreferences，首页和搜索复用。兼容原 SV，无迁移和额外权威副本。

## 成本与生命周期

触发为活动查询或成功使用动作，无新增事件、timer、Frame 或后台工作。每查询遍历至多 64 固定项、8 最近使用、128 同词记忆；快照共至多 72 个加权身份和一个同词偏好。每来源、每候选查表与标量评分 O(1)，只对既有命中执行；候选对象仍有界，不枚举业务目录来恢复偏好。

快照归当前查询，异步发布使用同一份；完成/取消后随查询释放。ranker 只保留所属来源的偏好副本，Provider 结束查询释放，不进入持久缓存。全部现有性能硬门禁保持，新增压力场景 200 次满容量查询回收后增长 <16 KiB、单次离线 <10 ms；与相同场景关闭偏好的 CPU/分配/保留量对照。首次创建 ranker 与后续逐候选使用分开验证，后者不分配结果对象。

为容纳新增能力而不提高冷加载预算，共用内部普通数据复制、数组和错误构造函数，移除索引原型上从未使用的空目录状态；实际 Catalog 仍各自创建完整实例。清空搜索跳过偏好快照，恢复最近使用每批只获取一次上下文，空 Catalog 交付跳过无记录的契约比较。查询资源注册仅在替换旧键、发生清理回调后重复检查存活与重入；新键路径没有中间外部调用。无新增事件或缓存。

## 验证计划

独立全扫描参考排序覆盖 20 条截断外的多个固定项和最近使用、同词记忆、不同 Provider 相同 ID、中文英文、取消/迟到、偏好修改隔离、重载和角色隔离；校验容量、坏字段、secret/metatable/NaN。Catalog Search/Query、动态 ranker 及自带动态来源均覆盖。完整 tests/run.py、wowdoc validate、git diff --check 通过后提交并同步五包，记录哈希。实机帧时间、战斗和 taint 未测时明确列出。

实际结果见[验收记录](../validation/2026-09-13-personalized-ranking.md)。

## 修改前版本证据

sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，matchedTag=12.1.0，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

path=Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua，line=45，excerpt：`Name = "InCombatLockdown"`，返回 `inCombatLockdown`，bool，Nilable=false（45–52 行）。本次仅改变普通 Lua 排名和已有成功记录路由，保留现有战斗门禁；不增加受保护动作。

同一 source/product/ref/commit：path=Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua，line=263，excerpt：`Name = "issecretvalue"`，`SecretArguments = "AllowedWhenUntainted"`，返回 `isSecret` bool；line=65，excerpt：`Name = "canaccessvalue"`，同一 SecretArguments，返回 `canAccessValue` bool。公开 ranker 在做比较前检查不可访问标量；无这些 API 的客户端沿用普通 Lua 校验，不新增 API 依赖。
