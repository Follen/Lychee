# Lychee 架构收敛完整目标规格

> 历史规格：保留已归档 change 的设计快照，包含当前已移除或调整的接口，不作为 SDK 1.0.0 或当前运行代码的实现要求。现行入口见 [架构](../../../ARCHITECTURE.md)、[设计规范](../../../../DESIGN.md) 和 [SDK](../../../../lychee-sdk/README.md)。

## 1. 模块所有权

Lychee 保持单一 Host AddOn 和 `_G.Lychee` 公共 facade。ExtensionRegistry 是 Extension 原子声明与生命周期的唯一事实源。SearchIndex 由 Host 独占；业务模块只通过 committed Extension handle 提供的 SearchSource handle 更新记录。

运行时使用以下职责边界：

```text
ExtensionRegistry
  -> CommandCatalog
  -> CapabilityBroker
  -> IntentRouter
  -> Panel registry / ViewHost
  -> SearchSource handle / SearchIndex

SearchSession
  -> QueryOrchestrator
  -> accepted result state
  -> Palette rendering

ResultActionExecutor
  -> IntentRouter
  -> ViewHost
  -> SecureActionBroker
  -> spell drag adapter
```

公共 facade 不吸收这些实现细节。UI 模块只发出输入、显示、关闭、选择和拖拽事件；它不直接推进查询 generation，也不实现 Intent/Panel transition 路由。

## 2. 固定 Command 搜索

CommandCatalog 完整拥有 Command 的规范化投影、稳定身份、优先级、启停状态、catalog 查询以及 ambient schedulable view。QueryOrchestrator 不读取 `Catalog.commands` 等内部可变表，也不把 Command 的索引投影作为普通 SearchRecord 再返回。

一个固定 Command 在任意查询中最多产生一条结果。Command 的 priority 必须按每条 Command 保留，不能由同 Extension 第一条 Command 的 source priority 覆盖。普通实体结果不能因为共享候选上限而把精确固定 Command 从 Command 查询中挤出。

Extension disable、retiring、removed 和 unregister 必须同时影响 Command 查询与 ambient 调度。enable 恢复原声明，不重复写入索引。Command 移除只清理所属 Extension 的投影。

## 3. CapabilityBroker

CapabilityBroker 完整拥有 Provider 的 Extension 所有权、生命周期资格、capability type、version、priority、请求 Schema、结果 Schema、错误边界和确定性选择。

查询时先校验请求，再按已启用 Provider 的稳定 priority 和身份排序选择。停用、retiring 或 removed Extension 的 Provider 不得调用。Provider 返回值必须通过结果 Schema；回调异常、非法结果和能力不存在不得被当作成功结果。

稳定错误至少可区分：能力不存在、Extension/Provider 不可用、请求非法、结果非法和 Provider 回调失败。错误对象遵循现有公开错误格式，不泄漏 payload 或回调细节。

本轮不规定跨查询缓存、自动重试或复杂 fallback。若最高优先级 Provider 明确不可用，是否尝试下一 Provider 只允许沿用当前已文档化行为，不新增用户可见策略。

## 4. 搜索会话

SearchSession 是 session 和 query generation 的唯一所有者。它负责：

- Palette 显示时开始会话，隐藏、进战或显式失效时结束会话；
- 输入修订、防抖、查询 token、取消和迟到回调丢弃；
- 调用 QueryOrchestrator 并只接纳当前会话的最新 generation；
- Extension/source 失效后拒绝关联结果；
- 向 Palette 发布已接纳的结果状态。

Palette 不直接写 QueryOrchestrator generation，Bootstrap 不读写 Palette 的 session/generation 内部字段。快速连续输入、IME composition、关闭后回调和旧 timer 都不能覆盖当前结果。隐藏时取消可取消 timer；不可取消回调使用 token guard 丢弃。

## 5. 结果动作执行

ResultActionExecutor 处理 SearchRecord 与 Command item 的声明式动作。其输入包含当前结果、action ID、Extension 所有权和 SearchSession token；其输出使用现有成功值或稳定错误。

执行顺序固定为：

1. 验证 Palette 可见、session/generation、source revision/generation 与 Extension enabled；
2. 验证战斗状态和声明式 availability；
3. 找到稳定 action ID，不按标题或图标推断；
4. 对普通 Intent 调用 IntentRouter；
5. 对合法 transition 验证同 Extension Panel 和 state Schema，再委托 ViewHost；
6. 对 drag 委托 spell drag adapter；
7. 对 secure-spell 委托 SecureActionBroker，脚本或 Enter 路径返回 `ACTION_REQUIRES_HARDWARE_CLICK`；
8. 按结果处理关闭 Palette 或保持当前视图。

Palette 负责行和动作槽的绘制以及把用户事件转交给 ResultActionExecutor。Bootstrap 只负责模块装配，不实现动作分支。ViewHost、IntentRouter 与 SecureActionBroker 继续作为下层深模块。

## 6. PlayerSpells 实时数据源

PlayerSpells 使用当前角色实时 SpellBook 作为唯一事实源，别名定义只投影到已知法术。模块拥有事件注册、同帧刷新合并、描述数据请求、快照构建、SearchRecord 投影、提交和 teardown。

Extension draft 注册 SearchSource 并 Commit 后，PlayerSpells 保存 `handle:GetSearchSource("records")` 返回的窄 source handle。后续刷新只通过该 handle 的 `BeginSnapshot`、`CommitSnapshot`、`Upsert`、`Remove` 或 `Invalidate` 更新；不得直接访问 StaticIndex、手拼完整 source ID 或维护私有 source generation。

初次注册失败必须允许明确重试或完整清理，不能在失败前永久写入 initialized 状态。disable/unregister 后事件和待处理刷新不得继续修改索引。短暂 SpellBook API 失败保留上一份已提交快照，不发布空结果。

## 7. SDK 与兼容性

`_G.Lychee`、Extension draft 以及 Command、CapabilityProvider、IntentHandler、PanelFactory、SearchSource 公共声明保持兼容。第三方仍通过 `## OptionalDeps: Lychee` 和同一 facade 接入，不新增 sibling SDK AddOn。

第三方 fixture 必须覆盖注册、Commit、查询、普通动作、Panel、能力查询、disable/enable 和 Unregister。公共文档必须明确：稳定实体使用 SearchSource；固定入口和真实动态组合使用 Command；跨模块复用数据使用 CapabilityProvider。

## 8. 性能与 WoW 约束

- Palette 隐藏、没有 pending query 或刷新时无常驻 Lua OnUpdate。
- 固定 Command 查询不重复扫描同一索引，不为同一 Command 创建两种结果形状。
- 搜索输入只查预构建索引；不新增按键时全表扫描。
- session/source/action token 使用稳定小表或复用状态，不在每帧创建对象。
- PlayerSpells 只在事件后合并刷新，按键路径不访问 SpellBook。
- secure-spell、drag、Binding、事件和 XML/TOC 使用 Retail 当前 wowdoc 证据；战斗中保持现有严格禁用策略。

## 9. 验证矩阵

- 固定 Command：单结果、别名、每 Command priority、disable/enable、unregister、ambient 调度和实体共存。
- CapabilityBroker：请求/结果 Schema、停用 Provider、确定性优先级、异常隔离、能力缺失和注销清理。
- SearchSession：连续输入、IME 修订、timer 取消、隐藏、进战、迟到结果和 source 失效。
- ResultActionExecutor：普通 Intent、Panel transition、跨 Extension 拒绝、drag、secure-spell、战斗、availability 和旧 token。
- PlayerSpells：实时快照、别名/描述、失败保留、handle 提交、disable/unregister 清理。
- 回归：Lua 5.1 语法、全部 smoke、合同检查、Retail wowdoc validate、git diff --check、正式服文件清单和 SHA-256。
