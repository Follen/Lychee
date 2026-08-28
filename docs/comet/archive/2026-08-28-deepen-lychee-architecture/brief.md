# Outcome

Lychee 的固定 Command、结果动作、搜索会话、实时玩家法术数据源和 CapabilityProvider 生命周期各自形成职责明确的深模块。搜索结果不重复，停用状态不会从旁路泄漏，UI 不再承担动作路由与查询代际规则，PlayerSpells 不再直接操作 StaticIndex。

# Scope

- 固定 Command 的规范化、索引投影、启停、排序、查询和 ambient 调度视图收敛到 CommandCatalog 的正式接口。
- 结果动作的时效、可用性、战斗策略、Intent、Panel transition、拖拽和 secure-spell 委托收敛到独立动作执行模块。
- 搜索会话统一拥有 session、generation、输入修订、防抖、取消、结果接纳和过期拒绝。
- PlayerSpells 通过 Extension 提交后取得的 SearchSource handle 发布快照，不直接调用 StaticIndex。
- CapabilityBroker 执行 Provider 所有权/启停资格、优先级、请求 Schema、结果 Schema、错误隔离和稳定错误合同。
- 同步运行时加载顺序、SDK 示例/说明、架构文档、当前 Comet 规格与测试。

# Non-goals

- 不新增任务、怪物、成就、副本 CD 等业务 Provider。
- 不改变当前 Palette 的视觉设计、结果行布局或默认快捷键。
- 不新增搜索评分、拼音、模糊匹配或缓存算法。
- CapabilityBroker 本轮不实现复杂 fallback、跨查询缓存或新的用户配置。
- 不删除 Command、CapabilityProvider、IntentHandler、PanelFactory 或 SearchSource 公共合同。

# Acceptance examples

- A1：注册一个固定 Command 后，按标题或别名查询只返回一条可执行 Command 结果；不会再额外返回同 ID 的普通 SearchRecord，也不会重复扫描同一索引路径。
- A2：Extension disable、retiring 或 unregister 后，其固定 Command 和 ambient Command 均不可查询、不可调度；重新 enable 后按原优先级恢复且不产生重复投影。
- A3：声明式结果动作通过统一动作执行模块处理；普通 Intent、同 Extension Panel transition、spell drag 和 secure-spell 保持现有可观察行为，旧 session/generation、战斗、不可用目标和停用 Extension 均返回稳定错误且不产生副作用。
- A4：搜索会话由单一模块推进 session/generation、防抖和取消；快速连续输入、关闭面板、输入法修订及迟到回调不会让旧结果覆盖新结果，也不会在 Palette 隐藏后继续发布结果。
- A5：PlayerSpells 初始化成功后持有正式 SearchSource handle，法术书刷新通过该 handle 原子提交新快照；生产 PlayerSpells 文件中不存在对 StaticIndex、手拼 source ID 或私有 source generation 的直接访问。
- A6：CapabilityProvider 所属 Extension 停用、retiring 或 removed 时不会被调用；请求和结果分别通过已声明 Schema，非法输入/输出、回调异常、能力缺失与 Provider 不可用返回可区分的稳定错误。
- A7：公共 `_G.Lychee` Extension/Command/Capability/Intent/Panel/SearchSource 合同保持兼容；第三方 fixture 通过同一公共接口注册、查询、执行、停用和注销，SDK 文档与当前规格和实现一致。
- A8：运行时无新增常驻 OnUpdate 或按键全表扫描；Lua 语法、全部 smoke、合同检查、Retail wowdoc validate 和 git diff --check 通过，提交后正式服副本与 `package/Lychee` 的运行时文件清单及 SHA-256 完全一致。

# Constraints and invariants

- 遵循 AGENTS.md 的性能优先准则：隐藏时零空闲工作、事件驱动、同帧更新合并、稳定数组/索引、无重复 setter 或热路径临时全表构建。
- 修改 WoW API、事件、Frame、SecureAction、XML 或 TOC 前先用 wowdoc 核验 Retail 当前版本；修改后执行 wowdoc validate。
- ExtensionRegistry 仍是原子发布、回滚、启停和注销的事实源；公共 facade 保持窄接口。
- SearchIndex 仍只由 Host 拥有；业务模块只通过 SearchSource handle 更新。
- ViewHost、IntentRouter 和 SecureActionBroker 保留各自现有职责，统一动作执行模块只负责编排和策略。
- 所有代码改动必须在验证通过后提交 Git，随后才复制到正式服目录并做完整哈希校验。

# Decisions

- 采用架构审查的五项建议，但按依赖顺序实现：Command 搜索、动作执行、搜索会话、PlayerSpells、CapabilityBroker。
- CapabilityBroker 本轮只补齐已经声明的运行合同，不增加缓存和复杂 fallback。
- 当前 UI 视觉和用户输入语义保持不变；这是架构与正确性收敛，不是产品功能扩展。
- 使用当前 `main` 工作区完成 change，不创建额外分支或 worktree。

# Open questions

- 无。

# Verification expectations

- 为固定 Command 单结果、独立优先级、停用/恢复、ambient 调度添加直接测试。
- 为 CapabilityProvider 停用资格、Schema、回调错误和注销添加直接测试。
- 为统一动作执行覆盖普通 Intent、Panel、drag、secure-spell、战斗、旧 generation 和 Extension 生命周期。
- 为搜索会话覆盖快速输入、取消、隐藏和迟到结果。
- 为 PlayerSpells 覆盖真实快照刷新、刷新失败保留旧快照、SearchSource handle 更新和注销清理。
- 执行全量 Lua 语法、smoke、interaction、search platform、合同、wowdoc 和差异检查。
