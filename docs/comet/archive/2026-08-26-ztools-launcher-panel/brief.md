# Outcome

把 Lychee 从“输入框下拉结果”升级为统一搜索平台：Buildin 与第三方插件用同一套 SearchSource/SearchRecord 协议收录数据，Host 统一完成索引、匹配、评分、排序和动作渲染；用户通过 Alt+Space 打开的完整启动面板搜索和执行能力。

# Scope

- SearchSource 注册、版本、生命周期、revision 和 locale/product/interface/build scope。
- SearchRecord 统一字段：stable id、kind、category、localized title、aliases、keywords、description、icon、actions、availability 和 source metadata。
- Host-owned 预索引：规范化、分词、2/3-gram 候选、精确/前缀/包含/缩写/拼音入口、有限模糊匹配、缓存、增量缩小、去重和稳定排序。
- 可解释置信度：返回 confidence、matchedField、matchedText、matchType；同一实体的别名只产生一个结果。
- locale/build 身份：当前 GetLocale、GetBuildInfo、product、interface、source revision 进入 index signature；只有当前 scope 的文本进入活动索引。
- Provider 只提交/更新记录；动作使用声明式 Action/Intent/Panel/secure-spell/drag 描述，Host 统一校验和执行。
- ZTools 风格 Palette：空输入显示最近、固定、类别和第三方入口的图标启动页；有输入显示带类别标签、图标、描述和动作区的结果卡片/网格，不再使用旧式纯下拉行。
- 保留当前 WoW 约束：Alt+Space 单一快捷键、战斗中关闭 Palette、secure 动作需要真实硬件点击、拖拽只允许已知技能、无隐藏常驻 OnUpdate。

# Non-goals

- 本 change 不实现 MRT、Details、WeakAuras 等具体第三方业务数据；只实现它们接入所需的 Host 协议和示例 fixture。
- 不允许 Provider 绘制根面板、接管输入焦点、注册 Lychee 级快捷键或提供任意 Lua 源码执行。
- 不在每次按键时枚举 AddOn、扫描全量技能书或重建索引。
- 不把不同 locale 或不兼容 Build 的别名混进当前活动索引。
- 不改写 docs/comet/archive 的历史快照。

# Acceptance examples

- A1：内置技能、成就、任务、副本和第三方 fixture 都能以 SearchRecord 注册，并在同一个查询结果流中按 category 显示。
- A2：输入当前 locale 的 canonical title、locale 别名、关键词或描述可命中同一个 stable record；不匹配 locale/build 的文本不会命中。
- A3：搜索返回 confidence、matchedField、matchedText 和 matchType；完全标题/别名优先于前缀、关键词、描述和模糊结果。
- A4：同一 stable record 被多个字段命中时只显示一次；相同分数按 source priority、category order、stable id 稳定排序。
- A5：输入逐字收窄时复用上一次候选集合；查询热路径不做全量 provider 扫描、frame 创建或无界模糊计算。
- A6：source 更新、移除、禁用和注销只使所属索引项与结果失效，不影响其他 source。
- A7：空输入打开启动页，显示最近/固定/分类/第三方入口；输入后切换搜索态，结果卡片显示类别标签、图标、描述和声明动作。
- A8：点击普通动作、打开 Panel、secure spell 和拖拽 spell 都经过 Host 的 session/generation/availability/combat 校验；战斗中返回 COMBAT_LOCKED。
- A9：第三方 fixture 使用 `_G.Lychee`、`OptionalDeps: Lychee` 语义注册 SearchSource，Lychee 不扫描插件目录猜测接入。
- A10：离线 smoke、interaction smoke、contract checks、Lua 语法检查和 Retail wowdoc validate 通过；源代码提交后才同步正式服副本。

# Constraints and invariants

- 一个 Lychee Host AddOn，SDK 是 `_G.Lychee` 公共 facade，不创建 sibling SDK AddOn。
- 记录字段必须是受边界校验的 plain data；secret/inaccessible 值不得进入索引、排序、动作、日志或 SavedVariables。
- 索引 signature 至少包含 schema version、product、interface/build、locale 和 source revision。
- Host 拥有搜索索引、Palette 根 frame、焦点、generation、secure button 和动作槽；Provider 拥有数据源和更新时机。
- 运行时热路径零空闲成本；事件/显式失效驱动刷新，结果和 frame 池化复用。
- 查询输出引用 canonical record，不复制大 payload；每轮有候选、结果和模糊预算。

# Decisions

- 采用“统一 SearchSource -> SearchRecord -> Host SearchIndex -> SearchResult -> Action/Panel”链路；Command 不再是每类实体各自实现搜索算法的入口。
- 类别是记录的一等字段，至少有 spells、achievements、quests、dungeons、extensions 五类；类别文案和图标可本地化。
- 空输入使用 ZTools 风格启动页；搜索态使用 Host 统一结果卡片，允许列表/网格布局提示但不允许 Provider 自绘。
- EasyFind 只借鉴其 locale/build 缓存签名、统一字段匹配、增量缩小、编辑距离缓存、分帧索引和结果引用策略；不复制其桌面 UI 或 Electron 依赖。

# Open questions

无。用户已确认完整范围：搜索引擎协议和实际搜索与 ZTools 风格启动面板在同一个 change 内交付。

# Verification expectations

- 每个 A 项在 Verify 中逐项给出 passed/failed/blocked 结论。
- 离线测试覆盖中文别名“翅膀”“红玉”、英文 alias、描述命中、Build/locale 排除、第三方 source、类别 badge、去重和置信度排序。
- UI 测试覆盖空输入启动页、输入切换、键盘导航、动作按钮、拖拽区域、战斗关闭、旧 generation 丢弃和池化行复用。
- 性能检查记录索引构建和稳态查询的候选数、耗时、分配/对象变化，并确认 Palette 隐藏时没有常驻每帧回调。
