---
generated_from_state_version: 25
---

# Verification

## Current result

- Result: **Passed**
- Assurance: **skill-coordinated**
- Goal cycle: 1
- Iteration: 6
- Verifier attempt: 1
- Completed: 2026-08-26T05:03:13.757Z
- Summary: PASS。独立验收 A1-A45 全部通过。A38 已具备 Home tile 全部目标 setter 的 change guard，空查询 Show 仅刷新一次；A45 已直接覆盖 PLAYER_REGEN_DISABLED 关闭已打开 Palette。五项 Runtime checks 均以退出码 0 通过。

## Acceptance

| ID | Result | Source | Criterion | Reason |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：内置技能、成就、任务、副本和第三方 fixture 都能以 SearchRecord 注册，并在同一个查询结果流中按 category 显示。 | 技能、成就、任务、副本和第三方 fixture 均以 SearchRecord 注册，并进入统一查询结果流。 |
| A2 | passed | brief.md | A2：输入当前 locale 的 canonical title、locale 别名、关键词或描述可命中同一个 stable record；不匹配 locale/build 的文本不会命中。 | title、locale alias、keyword、description 共用活动索引；测试覆盖中文命中、英文隔离、描述命中和 build 排除。 |
| A3 | passed | brief.md | A3：搜索返回 confidence、matchedField、matchedText 和 matchType；完全标题/别名优先于前缀、关键词、描述和模糊结果。 | 结果包含 confidence、matchedField、matchedText、matchType，评分层级保持精确标题/别名优先。 |
| A4 | passed | brief.md | A4：同一 stable record 被多个字段命中时只显示一次；相同分数按 source priority、category order、stable id 稳定排序。 | StaticIndex 按 stable ID 去重，并按 confidence、source priority、category order、stable ID 稳定排序。 |
| A5 | passed | brief.md | A5：输入逐字收窄时复用上一次候选集合；查询热路径不做全量 provider 扫描、frame 创建或无界模糊计算。 | 逐字收窄复用 previousCandidates；候选、结果和 fuzzy 均有限额，查询热路径不创建 Frame 或扫描 Provider。 |
| A6 | passed | brief.md | A6：source 更新、移除、禁用和注销只使所属索引项与结果失效，不影响其他 source。 | 每个 Source 使用独立 entryKeys；更新、移除、禁用和注销不重建或删除其他 Source 数据。 |
| A7 | passed | brief.md | A7：空输入打开启动页，显示最近/固定/分类/第三方入口；输入后切换搜索态，结果卡片显示类别标签、图标、描述和声明动作。 | 空输入显示可滚动 HomeView，搜索态显示类别、图标、描述、证据和声明动作；超过 16 个入口不会截断。 |
| A8 | passed | brief.md | A8：点击普通动作、打开 Panel、secure spell 和拖拽 spell 都经过 Host 的 session/generation/availability/combat 校验；战斗中返回 COMBAT_LOCKED。 | 普通动作、Panel、secure spell 和 drag 均经过 session、generation、Source state、availability、combat 校验。 |
| A9 | passed | brief.md | A9：第三方 fixture 使用 `_G.Lychee`、`OptionalDeps: Lychee` 语义注册 SearchSource，Lychee 不扫描插件目录猜测接入。 | fixture 使用 _G.Lychee、OptionalDeps: Lychee 和显式 Commit，未发现 AddOn 目录扫描或旧 facade。 |
| A10 | passed | brief.md | A10：离线 smoke、interaction smoke、contract checks、Lua 语法检查和 Retail wowdoc validate 通过；源代码提交后才同步正式服副本。 | 独立重跑 36 个 Lua 语法、三组 smoke、contract、Retail wowdoc validate 和 git diff --check，退出码均为 0；候选仍未提交或同步。 |
| A11 | passed | specs/search-platform/spec.md | Lychee 提供一个由 Host 统一管理的搜索平台。内置功能和第三方插件都提交相同的 SearchSource/SearchRecord 数据；Host 负责建立活动索引、匹配、置信度、去重、排序和结果渲染。Provider 不绘制根 UI，也不在每次按键时自己扫描数据。 | 内置和第三方数据统一经过 SearchSource、SearchRecord、Host StaticIndex、QueryOrchestrator 和 Host renderer。 |
| A12 | passed | specs/search-platform/spec.md | `SearchSource` 是数据来源和生命周期边界，可以属于 Buildin 或第三方 Extension。 | SearchSource 明确承担数据来源、revision、generation、启停、失效和注销边界。 |
| A13 | passed | specs/search-platform/spec.md | `SearchRecord` 是可搜索实体，不区分技能、成就、任务、副本还是第三方内容。 | 统一 SearchRecord schema 已用于 spell、achievement、quest、creature 和 extension。 |
| A14 | passed | specs/search-platform/spec.md | `SearchIndex` 是 Host 所有的预索引，Provider 不直接操作桶、评分或 UI。 | StaticIndex 仅由 Host 管理；公共 source handle 不暴露索引桶、评分或 UI 对象。 |
| A15 | passed | specs/search-platform/spec.md | `Action` 是结构化动作描述；普通 Intent、Panel、secure spell 和 drag 都由 Host 验证后执行。 | Action 是经 Boundary 校验的 plain-data 描述，覆盖 intent、open-panel、secure-spell 和 drag-spell。 |
| A16 | passed | specs/search-platform/spec.md | Source 必须声明稳定 ID、协议版本、优先级、scope、revision 和 snapshot/update 能力。提交后由 Host 分配 source generation。Source 更新通过 `BeginSnapshot`/`Upsert`/`Remove`/`CommitSnapshot` 或显式 `Invalidate(key)` 完成；Host 合并同帧更新，迟到 generation 直接丢弃。 | 公共 Source 强制 id、version、priority、scope、revision 和 snapshot/records；支持显式快照、同帧合并和 stale generation 丢弃。 |
| A17 | passed | specs/search-platform/spec.md | Source 不得注册 Lychee 级快捷键、取得 Palette 根 frame、创建 Host 结果行、返回函数/Frame/宏文本或在 resolver 中执行动作。第三方发现仍以 `_G.Lychee` facade 和明确 `Commit()` 为准，不以 AddOn 目录扫描或已加载状态为准。 | 公共协议不暴露 Palette 根 frame、结果行或宏文本；fixture 无 Lychee 级独立快捷键。 |
| A18 | passed | specs/search-platform/spec.md | `id` 是全局稳定实体 ID；同一技能的 canonical title、别名、关键词和描述都必须指向同一个 ID。`kind` 用于语义和 renderer，`category` 用于用户可见前置标签和类别筛选。类别文案、title、aliases、keywords、description 可以是 string 或带 locale/scope 的文本条目。 | stable id、kind、category 和 localized text 字段统一校验，同一实体的各搜索文本指向同一记录。 |
| A19 | passed | specs/search-platform/spec.md | Host 在登录或版本变化时读取 `GetLocale()` 和 `GetBuildInfo()` 的 locale、product、version、build、interface 字段，形成： | RuntimeIdentity 读取 locale、product、version、build、interface 并形成活动签名。 |
| A20 | passed | specs/search-platform/spec.md | 文本条目和记录 scope 允许 `locale`、`product`、`minInterface`、`maxInterface`、`minBuild`、`maxBuild`。建索引时只接受当前 locale、`default` 和当前 product/interface/build 范围；其他文本保留在 source 数据中但不进入活动桶。查询热路径不再次判断 scope。 | locale、product、interface 和 build scope 在建索引时过滤，查询热路径不重复判断。 |
| A21 | passed | specs/search-platform/spec.md | locale、Build、schema 或 source revision 改变时，Host 使活动索引失效并重建；SavedVariables 只能恢复 signature 完全一致的 plain-data 索引，并可做有限 live spot-check。 | 身份变化触发 Rebuild；SavedVariables 快照要求 schema 和完整 signature 匹配后才恢复。 |
| A22 | passed | specs/search-platform/spec.md | Host 为每条记录建立字段引用和倒排桶：canonical title、alias、keyword、description、category title。规范化使用当前 locale 的大小写、标点、空白和 Unicode 规则；中文保留连续文本，英文和数字生成 token；拼音、缩写和同义词作为可选派生字段。 | 索引覆盖 title、alias、keyword、description、category，并建立 token、prefix 和 1至3 gram 桶。 |
| A23 | passed | specs/search-platform/spec.md | 候选召回顺序： | 候选召回组合精确/前缀/token、gram、上一候选集合和受预算 fuzzy。 |
| A24 | passed | specs/search-platform/spec.md | exact/prefix token map； | exact、prefix 和 token map 在索引构建期生成并优先召回。 |
| A25 | passed | specs/search-platform/spec.md | 2/3-gram 倒排桶； | StaticIndex 为活动文本生成 1至3 gram 倒排桶。 |
| A26 | passed | specs/search-platform/spec.md | 上一代候选集的增量缩小； | 新查询以前一查询为前缀时复用 previousCandidates，测试直接断言 reusedPrevious。 |
| A27 | passed | specs/search-platform/spec.md | 仅在查询长度和预算允许时运行拼写/编辑距离候选。 | 编辑距离受文本长度、48 个候选和 1.5ms 时间预算约束。 |
| A28 | passed | specs/search-platform/spec.md | 索引构建可以分帧执行，结果保存 canonical record 引用而不是复制 payload。查询热路径不得枚举 AddOn、扫描全量 Provider、创建 Frame、启动无界 timer 或调用网络/生成式模型。隐藏 Palette 时取消待执行搜索。 | 查询结果保存 canonical record 引用；查询路径不枚举 AddOn、不扫描 Provider、不创建 Frame，Palette 隐藏会取消待执行搜索。 |
| A29 | passed | specs/search-platform/spec.md | 每个候选产生 `confidence`（0.0 到 1.0）和一条 evidence： | 每个命中携带 0到1 confidence 及完整 evidence。 |
| A30 | passed | specs/search-platform/spec.md | 建议匹配层级：exact canonical 1.00、exact alias 0.98、canonical prefix 0.90、alias prefix 0.86、全部 token 命中 0.82、substring 0.74、keyword 0.62、description 0.48、有限 fuzzy 0.30-0.55。实际实现可按字段长度和语言校准，但必须保持 exact > prefix > token > keyword/description > fuzzy 的单调关系。 | 实际评分保持 exact 高于 prefix/token，并高于 keyword、description 和 fuzzy。 |
| A31 | passed | specs/search-platform/spec.md | 最终排序依次比较 confidence、source priority、category order、record stable ID；用户置顶/最近使用只能作为同一匹配层级内的有限 boost，不能越过精确命中。一个 record 被多个字段命中时只保留最高 evidence。 | 最终排序实现 confidence、source priority、category order、stable ID；同 stable ID 仅保留最佳 evidence。 |
| A32 | passed | specs/search-platform/spec.md | Host 按 session、query generation、source state、availability 和 combat 状态重新校验结果。`open-panel` 通过同 Extension 的 PanelFactory；普通动作通过 IntentRouter；`secure-spell` 只能绑定 Host 自己的 SecureActionButton 并要求真实硬件点击；`drag-spell` 只能在脱战、当前玩家已知且可用时调用 `C_Spell.PickupSpell`。Provider 不直接执行这些动作。 | Host 重验 Source、availability、combat 和 generation；Panel、Intent、secure、drag 均走各自受控边界。 |
| A33 | passed | specs/search-platform/spec.md | Alt+Space 打开 Host-owned Palette。空输入显示 ZTools 风格 HomeView：最近使用、已固定、按 category 分组的入口和第三方 source 入口。最近/固定只保存稳定 ID，不保存完整 payload。 | Alt+Space 对应 Host Palette；HomeView 包含 recent、pinned、五类别和每个启用的第三方 Source，且只保存稳定 ID。 |
| A34 | passed | specs/search-platform/spec.md | 非空输入切换 SearchView：结果使用池化的 Host-owned tile/row renderer，至少显示 icon、category badge、localized title、description/subtext、confidence evidence 对应的轻量命中提示和有限 action slots。布局可以由 Host 在密集列表和两列网格间选择，但不回退为没有类别和动作区的旧式下拉列表。 | SearchView 预创建并复用结果行和动作槽，渲染 icon、category、localized title、description、source 和 evidence。 |
| A35 | passed | specs/search-platform/spec.md | 类别至少包括 `spells`、`achievements`、`quests`、`dungeons`、`extensions`，第三方自定义类别必须以其 Extension ID 为前缀。类别本身可作为 query filter，例如 `技能 翅膀`，但类别标签不替代稳定 record ID。 | 五个核心类别存在，第三方自定义类别强制 Extension ID 前缀，类别文本可参与多词查询。 |
| A36 | passed | specs/search-platform/spec.md | Source 注册、snapshot、upsert、remove、disable 和 unregister 都产生可追踪 revision；只失效所属记录。 | 注册、snapshot、upsert、remove、disable、invalidate 和 unregister 均产生可追踪 Source 状态变化。 |
| A37 | passed | specs/search-platform/spec.md | Palette 隐藏时无常驻 per-frame Lua 回调；事件驱动刷新，必要的 debounce/ticker 可取消且有 generation guard。 | Palette 无常驻 OnUpdate；共享 Scheduler 首订阅 Show、末订阅 Hide，并以 swap-remove 清理。 |
| A38 | passed | specs/search-platform/spec.md | 索引、结果卡片、图标和动作槽池化复用；setter 有 change guard；Provider 数据更新不重建无关类别。 | Home tile 按峰值增量扩容并复用；title、meta、icon texture、icon/tile visibility、content height 均有 change guard；空查询 Show 只刷新一次。 |
| A39 | passed | specs/search-platform/spec.md | 每轮查询有候选上限、结果上限和 fuzzy 时间预算；超预算只保留已完成的高置信度候选并记录稳定诊断码。 | 候选上限 200、结果上限 20、fuzzy 上限 48 和 1.5ms 预算均存在，超限记录稳定诊断码。 |
| A40 | passed | specs/search-platform/spec.md | 所有 Source/Record/Action 边界先执行 secret/inaccessible/plain-data/schema 校验，失败值不进索引、排序、缓存或日志。 | Boundary 拒绝 secret、inaccessible、函数、metatable、循环、无效数值和非法 schema；Action 另做 kind 专属校验。 |
| A41 | passed | specs/search-platform/spec.md | 当前角色实时已知技能及其描述可搜索；“翅膀”和“红玉”分别命中对应技能 ID。 | Provider 实时读取当前角色 SpellBook 和 C_Spell 描述；测试覆盖翅膀、红玉、实时技能及描述搜索。 |
| A42 | passed | specs/search-platform/spec.md | 不同 locale 的别名互相隔离；不同 interface/build scope 的记录不在当前客户端出现。 | 测试覆盖 zhCN/enUS alias 隔离及 minBuild scope 排除。 |
| A43 | passed | specs/search-platform/spec.md | 内置与第三方记录可以同时返回，类别标签和 stable ID 保持正确，重复别名不产生重复行。 | 内置和第三方记录可共同返回，stable ID 去重阻止重复别名产生重复行。 |
| A44 | passed | specs/search-platform/spec.md | Boss/M1、任务、成就和 MRT fixture 共享相同的索引和动作协议。 | M1、副本怪物、任务、成就和 MRT fixture 使用同一 SearchSource、索引与 Action 协议。 |
| A45 | passed | specs/search-platform/spec.md | 空输入 HomeView、输入 SearchView、点击普通动作、打开 Panel、secure 点击、spell 拖拽和战斗关闭均可由离线 interaction contract 覆盖；Retail API 兼容性通过 wowdoc validate 检查。 | interaction smoke 覆盖 Home/Search 切换、普通动作、Panel、secure guard、drag、stale generation，并在已打开 Palette 上直接触发 PLAYER_REGEN_DISABLED 后断言 controller 和 frame 均关闭；wowdoc validate valid=true。 |

## Checks

| Check | Command | Working directory | Status | Exit | Duration |
| --- | --- | --- | --- | ---: | ---: |
| Lua syntax | -NoProfile -ExecutionPolicy Bypass -Command $files = Get-ChildItem package/Lychee -Recurse -Filter *.lua \| ForEach-Object { $_.FullName }; $files += @('tests/smoke.lua','tests/interaction_smoke.lua','tests/search_platform_smoke.lua'); foreach ($f in $files) { & luac -p $f; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } | . | passed | 0 | 489 ms |
| All smoke tests | -NoProfile -ExecutionPolicy Bypass -Command lua tests/smoke.lua; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; lua tests/interaction_smoke.lua; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; lua tests/search_platform_smoke.lua | . | passed | 0 | 232 ms |
| Contract checks | -NoProfile -ExecutionPolicy Bypass -File tests/check_contract.ps1 | . | passed | 0 | 300 ms |
| Retail wowdoc validation | -NoProfile -ExecutionPolicy Bypass -Command wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest; exit $LASTEXITCODE | . | passed | 0 | 320 ms |
| Git diff check | diff --check | . | passed | 0 | 66 ms |

## Blockers

_None._

## Risks and skipped work

- 离线 Frame mock 不替代 Retail 客户端中的滚动视觉、真实硬件 secure click、实际法术拖拽和 Alt+Space 持久绑定验证。
- StaticIndex 的 CommitSnapshot/Rebuild 当前同步执行；虽然查询热路径已有预算和上限，多个大型 Source 同时更新仍应在客户端做峰值帧时间采样。
- HomeView 核心类别标题当前主要为中文常量，后续面向非 zhCN 客户端时应补齐完整 UI 文案本地化。

## Previous iterations

| Goal cycle | Iteration | Attempt | Outcome | Unresolved | Summary | Completed |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | fail | A1, A4, A5, A7, A11, A15, A16, A19, A21, A22, A23, A24, A26, A28, A30, A31, A33, A34, A35, A36, A37, A38, A39, A40, A43, A44, A45 | 基础检查通过，但统一内置 SearchSource、增量索引与候选复用、排序层级、Home/Search 完整数据、动作 schema、类别覆盖和测试覆盖仍未满足完整 A1-A45 合同。 | 2026-08-25T19:47:54.302Z |
| 1 | 2 | 1 | fail | A3, A4, A8, A11, A15, A16, A21, A30, A32, A35, A36, A38, A39, A40, A43, A45 | 基础检查通过，但重复结果、评分、公开增量 SDK、动作执行、索引恢复、第三方类别约束、局部索引和 fuzzy 时间预算仍不满足合同，应返回 Build。 | 2026-08-26T03:16:44.318Z |
| 1 | 3 | 1 | execution-error | — | Native Verifier response was invalid: Native Verifier risks must be text entries | 2026-08-26T04:14:18.471Z |
| 1 | 3 | 2 | fail | A7, A8, A11, A15, A16, A32, A33, A34, A40, A45 | FAIL。索引、评分、locale/build 过滤、增量 source、持久化、SDK handle、基础 UI 与性能预算总体成立，全部 Runtime 检查通过。仍需修复 localized array 显示、source generation/revision 与 availability 的全动作重验、kind-specific Action schema、SearchSource 必填元数据与同帧合并、每 SearchSource Home entry，并消除 indexed/ambient 双路径重复后补齐回归测试。 | 2026-08-26T04:22:35.106Z |
| 1 | 4 | 1 | fail | A7, A33, A45 | FAIL。搜索协议、索引、评分、locale/build、动作重验、同帧 source 更新和现有检查均通过；剩余问题是 HomeView 仍用固定 16 个 tile，无法保证最近/固定/类别及每个第三方 SearchSource 都可见，且测试没有覆盖该溢出路径。 | 2026-08-26T04:39:39.425Z |
| 1 | 5 | 1 | fail | A38, A45 | FAIL。上一轮 A7/A33 的固定 16 tile 截断已修复，recent/pinned、五类别和 22 个第三方 Source 均可访问；localized action.title 已解析为字符串并被 UI 渲染。全部静态与离线门禁独立通过。剩余 A38：Home tile setter 缺少 change guard；A45：interaction smoke 未直接覆盖 PLAYER_REGEN_DISABLED 关闭 Palette。 | 2026-08-26T04:51:46.227Z |
| 1 | 5 | 1 | recovery | — | 继续修复 A38 HomeView setter change guard 和重复刷新，以及 A45 PLAYER_REGEN_DISABLED 战斗关闭交互测试；需求与验收标准不变。 | 2026-08-26T04:51:58.178Z |
| 1 | 6 | 1 | pass | — | PASS。独立验收 A1-A45 全部通过。A38 已具备 Home tile 全部目标 setter 的 change guard，空查询 Show 仅刷新一次；A45 已直接覆盖 PLAYER_REGEN_DISABLED 关闭已打开 Palette。五项 Runtime checks 均以退出码 0 通过。 | 2026-08-26T05:03:13.757Z |

## Conclusion

PASS。独立验收 A1-A45 全部通过。A38 已具备 Home tile 全部目标 setter 的 change guard，空查询 Show 仅刷新一次；A45 已直接覆盖 PLAYER_REGEN_DISABLED 关闭已打开 Palette。五项 Runtime checks 均以退出码 0 通过。
