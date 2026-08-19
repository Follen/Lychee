# Outcome

Lychee 的 `dynamic-list` Command 支持主动内容匹配。用户无需先输入命令名，可以直接输入怪物、物品等实体名称；Host 只调度声明了主动匹配且满足规则的 Command，Command resolver 通过 CapabilityProvider 查询自己的预索引数据，Lychee 统一绘制结果。点选结果后仍经过 IntentRouter，并可由 Handler 返回声明式详情视图转换，在 Lychee 的 ViewHost 中展示已注册 Panel。

# Scope

- 更新 `docs/ARCHITECTURE.md`，定义默认 catalog 匹配与 `ambient` 主动匹配、查询调度、性能预算、Provider 边界和详情 Panel 转换。
- 更新 `docs/SDK.md`，给出第三方可照写的 `match`、`dynamic-list`、`itemIntent`、`ExecutionResult.transition` 和大秘境怪物示例。
- 更新 `command-platform` 与 `sdk-integration` 完整目标规格。
- 记录 ZTools `mainPush` 的可借鉴结论，但使用适合 WoW AddOn 的同步、预索引和协作式调度模型。

# Non-goals

- 不实现 Lua/XML/TOC、SDK 或 UI 运行时代码。
- 不新增独立的 Content Index 公共 registry；数据索引由 Provider 或其所属模块内部维护。
- 不允许 Provider 直接向搜索结果推送 frame、接管 Palette，或绕过 Command/Intent。
- 不照搬 Electron IPC、WebContentsView、Promise 或桌面插件进程模型。
- 不在本 change 中定义具体怪物数据集、数据采集方式或详情视觉稿。

# Acceptance examples

- A1：`docs/ARCHITECTURE.md` 明确 Command 是唯一搜索入口，Provider 数据不会自动进入全局搜索；`ambient` 只是 Command 的主动匹配模式，不是第二套搜索对象。
- A2：文档给出“输入大秘境小怪名称 -> ambient Command 命中 -> resolver 查询怪物 Provider 索引 -> Host 绘制 -> item Intent -> ViewHost 详情 Panel”的完整链路。
- A3：Command 匹配合同至少区分默认 `catalog` 和显式 `ambient`，并规定 `minLength`、`maxLength`、availability、启用状态与静态预筛选要求。
- A4：只有 `dynamic-list` 可以声明 `ambient`；row/custom-panel 仍通过标题、别名和关键词进入静态 Catalog，注册期拒绝不合法组合。
- A5：主动 resolver 受单一 debounce、generation/context token、全局调用数、单 Command 结果数和协作式耗时预算约束；Palette 隐藏时没有后台查询。
- A6：SDK 文档提供可直接照写的怪物 Provider、ambient dynamic-list Command、item Intent、IntentHandler 和 PanelFactory 组合示例。
- A7：点选动态项必须先生成并路由 Intent；Handler 只能返回声明式 `transition = { type = "custom-panel", panelFactoryID, state }`，Host 校验同 Extension 所有权后挂载 Panel。
- A8：`transition.state` 与动态 item 一样经过 plain-data、secret/inaccessible、大小和深度校验，失败不挂载 Panel。
- A9：文档明确内部功能和第三方功能使用同一主动匹配、Provider、Intent 和 ViewHost 合同。
- A10：验证矩阵覆盖直接实体名、短输入不调度、快速连续输入、多个 ambient Command、Provider 不可用、详情转换失败和 Palette 关闭清理。
- A11：文档明确第三方必须主动向 `LycheeSDK` 注册并 `Commit()` Extension；仅注册 Provider 不会进入搜索，第三方还必须在同一 Extension 中注册引用该 Provider 的 ambient Command。SDK/Host 任意加载顺序均可接入，返回句柄支持启停和幂等注销。

# Constraints and invariants

- Command/CapabilityProvider/IntentHandler/PanelFactory 分层保持不变。
- 已提交 SDK registry、CommandCatalog、QueryOrchestrator、IntentRouter 和 ViewHost 仍分别是唯一事实源。
- ambient resolver 不扫描 AddOn，不创建 frame，不注册常驻事件，不执行动作；只读取 query、ContextSnapshot 和预索引/缓存数据。
- 第三方返回值必须通过现有递归访问与 schema 校验，不进入日志或 SavedVariables 的 secret/inaccessible 值边界不变。
- 战斗中 Palette 和所有 Lychee Intent 仍按现有 `COMBAT_LOCKED` 契约处理。
- 本 change 只有文档，不复制到正式服 AddOns 目录。

# Decisions

- 采用 ZTools `mainPush` 的“Command 先声明参与范围，命中后动态查询数据，Host 统一画结果”的思想，不采用插件无条件向 UI 推送结果的接口。
- v1 主动匹配名称为 `match.type = "ambient"`；默认未声明时为 `catalog`。
- ambient 只允许用于 `dynamic-list`，并要求显式长度边界；具体内容索引属于 Provider/模块私有实现。
- 动态项进入详情使用 IntentHandler 的声明式 `ExecutionResult.transition`，不让 resolver 或 Provider 直接打开 Panel。
- Host 对 ambient Command 提供用户启停和稳定调度优先级；禁用项不参与查询。
- 第三方接入不依赖 Lychee 扫描插件目录。第三方主动向 `LycheeSDK` 提交完整 Extension；`Commit()` 是 Command、Provider、Handler 和 Panel 对 Host 可见的唯一时点，Extension 句柄是后续状态查询、启停和注销入口。

# Open questions

- 无。

# Verification expectations

- Markdown 一级标题、代码围栏、相对链接和关键术语检查通过。
- `ARCHITECTURE.md`、`SDK.md` 与两个完整目标规格的字段名和行为一致。
- 搜索旧表述，确认不存在“用户输入只能匹配静态命令名”或“Provider 自动成为搜索结果”等冲突。
- `git diff --check` 通过，Git 变更仅限本 change 文档和 Comet 正式产物。
