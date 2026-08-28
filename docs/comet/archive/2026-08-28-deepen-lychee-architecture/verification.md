---
generated_from_state_version: 13
---

# Verification

## Current result

- Result: **Passed**
- Assurance: **skill-coordinated**
- Goal cycle: 1
- Iteration: 3
- Verifier attempt: 1
- Completed: 2026-08-28T12:26:09.556Z
- Summary: 上一轮的 descriptor 突变、Command priority、Capability 版本范围、公共 handle 转发和文档旧模型问题均已修复，当前实现满足完整验收合同。

## Acceptance

| ID | Result | Source | Criterion | Reason |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：注册一个固定 Command 后，按标题或别名查询只返回一条可执行 Command 结果；不会再额外返回同 ID 的普通 SearchRecord，也不会重复扫描同一索引路径。 | 固定 Command 仅进入 Catalog 私有索引，标题和别名查询均为单一结果。 |
| A2 | passed | brief.md | A2：Extension disable、retiring 或 unregister 后，其固定 Command 和 ambient Command 均不可查询、不可调度；重新 enable 后按原优先级恢复且不产生重复投影。 | disable、retiring、unregister 同步影响 fixed/ambient，重新启用无重复投影。 |
| A3 | passed | brief.md | A3：声明式结果动作通过统一动作执行模块处理；普通 Intent、同 Extension Panel transition、spell drag 和 secure-spell 保持现有可观察行为，旧 session/generation、战斗、不可用目标和停用 Extension 均返回稳定错误且不产生副作用。 | ResultActionExecutor 统一处理 Intent、Panel、拖拽、secure-spell、战斗与过期结果。 |
| A4 | passed | brief.md | A4：搜索会话由单一模块推进 session/generation、防抖和取消；快速连续输入、关闭面板、输入法修订及迟到回调不会让旧结果覆盖新结果，也不会在 Palette 隐藏后继续发布结果。 | SearchSession 独占 session/generation、防抖、取消和迟到结果拒绝。 |
| A5 | passed | brief.md | A5：PlayerSpells 初始化成功后持有正式 SearchSource handle，法术书刷新通过该 handle 原子提交新快照；生产 PlayerSpells 文件中不存在对 StaticIndex、手拼 source ID 或私有 source generation 的直接访问。 | PlayerSpells 仅通过 committed SearchSource handle 原子提交实时快照。 |
| A6 | passed | brief.md | A6：CapabilityProvider 所属 Extension 停用、retiring 或 removed 时不会被调用；请求和结果分别通过已声明 Schema，非法输入/输出、回调异常、能力缺失与 Provider 不可用返回可区分的稳定错误。 | CapabilityBroker 覆盖生命周期、双 Schema、异常隔离和稳定错误。 |
| A7 | passed | brief.md | A7：公共 `_G.Lychee` Extension/Command/Capability/Intent/Panel/SearchSource 合同保持兼容；第三方 fixture 通过同一公共接口注册、查询、执行、停用和注销，SDK 文档与当前规格和实现一致。 | 公共 facade、fixture、SDK、规格和版本范围查询链路一致。 |
| A8 | passed | brief.md | A8：运行时无新增常驻 OnUpdate 或按键全表扫描；Lua 语法、全部 smoke、合同检查、Retail wowdoc validate 和 git diff --check 通过，提交后正式服副本与 `package/Lychee` 的运行时文件清单及 SHA-256 完全一致。 | 无新增常驻 OnUpdate 或按键全表扫描，全部静态检查通过。 |
| A9 | passed | specs/architecture-convergence/spec.md | Lychee 保持单一 Host AddOn 和 `_G.Lychee` 公共 facade。ExtensionRegistry 是 Extension 原子声明与生命周期的唯一事实源。SearchIndex 由 Host 独占；业务模块只通过 committed Extension handle 提供的 SearchSource handle 更新记录。 | 单 Host facade、Registry 事实源和 Host 独占实体索引边界成立。 |
| A10 | passed | specs/architecture-convergence/spec.md | 运行时使用以下职责边界： | Command、Capability、Session、Action 和 PlayerSpells 职责已拆入对应模块。 |
| A11 | passed | specs/architecture-convergence/spec.md | 公共 facade 不吸收这些实现细节。UI 模块只发出输入、显示、关闭、选择和拖拽事件；它不直接推进查询 generation，也不实现 Intent/Panel transition 路由。 | 公共 facade 保持窄接口，Palette 与 Bootstrap 未吸收内部规则。 |
| A12 | passed | specs/architecture-convergence/spec.md | CommandCatalog 完整拥有 Command 的规范化投影、稳定身份、优先级、启停状态、catalog 查询以及 ambient schedulable view。QueryOrchestrator 不读取 `Catalog.commands` 等内部可变表，也不把 Command 的索引投影作为普通 SearchRecord 再返回。 | Catalog 深快照 descriptor，Get、Query 和 ambient 返回值均与内部状态隔离。 |
| A13 | passed | specs/architecture-convergence/spec.md | 一个固定 Command 在任意查询中最多产生一条结果。Command 的 priority 必须按每条 Command 保留，不能由同 Extension 第一条 Command 的 source priority 覆盖。普通实体结果不能因为共享候选上限而把精确固定 Command 从 Command 查询中挤出。 | 每条 Command priority 独立快照，注册后突变不影响结果。 |
| A14 | passed | specs/architecture-convergence/spec.md | Extension disable、retiring、removed 和 unregister 必须同时影响 Command 查询与 ambient 调度。enable 恢复原声明，不重复写入索引。Command 移除只清理所属 Extension 的投影。 | Command disable、retiring、removed、unregister 和恢复时序正确。 |
| A15 | passed | specs/architecture-convergence/spec.md | CapabilityBroker 完整拥有 Provider 的 Extension 所有权、生命周期资格、capability type、version、priority、请求 Schema、结果 Schema、错误边界和确定性选择。 | Broker 校验整数版本范围并跳过高优先级不兼容 Provider。 |
| A16 | passed | specs/architecture-convergence/spec.md | 查询时先校验请求，再按已启用 Provider 的稳定 priority 和身份排序选择。停用、retiring 或 removed Extension 的 Provider 不得调用。Provider 返回值必须通过结果 Schema；回调异常、非法结果和能力不存在不得被当作成功结果。 | 公共 handle 原样转发 minVersion、maxVersion、request 和 context。 |
| A17 | passed | specs/architecture-convergence/spec.md | 稳定错误至少可区分：能力不存在、Extension/Provider 不可用、请求非法、结果非法和 Provider 回调失败。错误对象遵循现有公开错误格式，不泄漏 payload 或回调细节。 | 能力缺失、不可用、Schema、结果和回调错误可区分且不泄漏内部细节。 |
| A18 | passed | specs/architecture-convergence/spec.md | 本轮不规定跨查询缓存、自动重试或复杂 fallback。若最高优先级 Provider 明确不可用，是否尝试下一 Provider 只允许沿用当前已文档化行为，不新增用户可见策略。 | 未引入跨查询缓存、自动重试或新的用户可见 fallback。 |
| A19 | passed | specs/architecture-convergence/spec.md | SearchSession 是 session 和 query generation 的唯一所有者。它负责： | session 和 query generation 仅由 SearchSession 推进。 |
| A20 | passed | specs/architecture-convergence/spec.md | Palette 显示时开始会话，隐藏、进战或显式失效时结束会话； | Palette 显示、隐藏和进战正确启动或终止会话。 |
| A21 | passed | specs/architecture-convergence/spec.md | 输入修订、防抖、查询 token、取消和迟到回调丢弃； | 连续输入、IME、timer 取消和迟到回调均受 token guard 保护。 |
| A22 | passed | specs/architecture-convergence/spec.md | 调用 QueryOrchestrator 并只接纳当前会话的最新 generation； | SearchSession 调度 Orchestrator 且只接纳当前 token。 |
| A23 | passed | specs/architecture-convergence/spec.md | Extension/source 失效后拒绝关联结果； | SearchSource 变化立即使当前 generation 失效并清除旧结果。 |
| A24 | passed | specs/architecture-convergence/spec.md | 向 Palette 发布已接纳的结果状态。 | 已接纳结果只通过 SearchSession 发布给 Palette。 |
| A25 | passed | specs/architecture-convergence/spec.md | Palette 不直接写 QueryOrchestrator generation，Bootstrap 不读写 Palette 的 session/generation 内部字段。快速连续输入、IME composition、关闭后回调和旧 timer 都不能覆盖当前结果。隐藏时取消可取消 timer；不可取消回调使用 token guard 丢弃。 | Palette 与 Bootstrap 不直接推进会话代次，旧回调不能覆盖新结果。 |
| A26 | passed | specs/architecture-convergence/spec.md | ResultActionExecutor 处理 SearchRecord 与 Command item 的声明式动作。其输入包含当前结果、action ID、Extension 所有权和 SearchSession token；其输出使用现有成功值或稳定错误。 | Executor 输入包含结果、action、owner、session 和 source token。 |
| A27 | passed | specs/architecture-convergence/spec.md | 执行顺序固定为： | 动作校验和委托顺序符合规格。 |
| A28 | passed | specs/architecture-convergence/spec.md | 验证 Palette 可见、session/generation、source revision/generation 与 Extension enabled； | 可见性、会话、source revision/generation 和 Extension 状态均预先校验。 |
| A29 | passed | specs/architecture-convergence/spec.md | 验证战斗状态和声明式 availability； | 战斗与声明式 availability 在副作用前检查。 |
| A30 | passed | specs/architecture-convergence/spec.md | 找到稳定 action ID，不按标题或图标推断； | 动作按稳定 action ID 定位，不依赖显示文字或图标。 |
| A31 | passed | specs/architecture-convergence/spec.md | 对普通 Intent 调用 IntentRouter； | 普通 Intent 统一委托 IntentRouter。 |
| A32 | passed | specs/architecture-convergence/spec.md | 对合法 transition 验证同 Extension Panel 和 state Schema，再委托 ViewHost； | Panel transition 校验同 Extension 所有权和 state Schema 后交给 ViewHost。 |
| A33 | passed | specs/architecture-convergence/spec.md | 对 drag 委托 spell drag adapter； | spell drag 委托独立拖拽适配器。 |
| A34 | passed | specs/architecture-convergence/spec.md | 对 secure-spell 委托 SecureActionBroker，脚本或 Enter 路径返回 `ACTION_REQUIRES_HARDWARE_CLICK`； | secure-spell 委托 Broker，脚本路径返回硬件点击要求。 |
| A35 | passed | specs/architecture-convergence/spec.md | 按结果处理关闭 Palette 或保持当前视图。 | 动作结果按合同关闭 Palette 或保留当前视图。 |
| A36 | passed | specs/architecture-convergence/spec.md | Palette 负责行和动作槽的绘制以及把用户事件转交给 ResultActionExecutor。Bootstrap 只负责模块装配，不实现动作分支。ViewHost、IntentRouter 与 SecureActionBroker 继续作为下层深模块。 | Palette 只绘制和转交，Bootstrap 只装配。 |
| A37 | passed | specs/architecture-convergence/spec.md | PlayerSpells 使用当前角色实时 SpellBook 作为唯一事实源，别名定义只投影到已知法术。模块拥有事件注册、同帧刷新合并、描述数据请求、快照构建、SearchRecord 投影、提交和 teardown。 | PlayerSpells 使用实时 SpellBook 并通过事件合并刷新。 |
| A38 | passed | specs/architecture-convergence/spec.md | Extension draft 注册 SearchSource 并 Commit 后，PlayerSpells 保存 `handle:GetSearchSource("records")` 返回的窄 source handle。后续刷新只通过该 handle 的 `BeginSnapshot`、`CommitSnapshot`、`Upsert`、`Remove` 或 `Invalidate` 更新；不得直接访问 StaticIndex、手拼完整 source ID 或维护私有 source generation。 | 生产 PlayerSpells 不访问 StaticIndex、不手拼 source ID 或维护私有 generation。 |
| A39 | passed | specs/architecture-convergence/spec.md | 初次注册失败必须允许明确重试或完整清理，不能在失败前永久写入 initialized 状态。disable/unregister 后事件和待处理刷新不得继续修改索引。短暂 SpellBook API 失败保留上一份已提交快照，不发布空结果。 | 初始化失败可重试，停用/注销清理，短暂 API 失败保留旧快照。 |
| A40 | passed | specs/architecture-convergence/spec.md | `_G.Lychee`、Extension draft 以及 Command、CapabilityProvider、IntentHandler、PanelFactory、SearchSource 公共声明保持兼容。第三方仍通过 `## OptionalDeps: Lychee` 和同一 facade 接入，不新增 sibling SDK AddOn。 | 单 facade 与 OptionalDeps: Lychee 模型保持一致。 |
| A41 | passed | specs/architecture-convergence/spec.md | 第三方 fixture 必须覆盖注册、Commit、查询、普通动作、Panel、能力查询、disable/enable 和 Unregister。公共文档必须明确：稳定实体使用 SearchSource；固定入口和真实动态组合使用 Command；跨模块复用数据使用 CapabilityProvider。 | fixture 与文档统一为 SearchSource 实体、Command 入口、CapabilityProvider 复用能力。 |
| A42 | passed | specs/architecture-convergence/spec.md | Palette 隐藏、没有 pending query 或刷新时无常驻 Lua OnUpdate。 | Palette 隐藏且无任务时没有常驻 Lua 工作。 |
| A43 | passed | specs/architecture-convergence/spec.md | 固定 Command 查询不重复扫描同一索引，不为同一 Command 创建两种结果形状。 | 固定 Command 不扫描共享实体索引，也不产生双结果形状。 |
| A44 | passed | specs/architecture-convergence/spec.md | 搜索输入只查预构建索引；不新增按键时全表扫描。 | 输入查询读取预构建索引，不扫描 SpellBook 或原始业务库。 |
| A45 | passed | specs/architecture-convergence/spec.md | session/source/action token 使用稳定小表或复用状态，不在每帧创建对象。 | session/source/action token 为有界小表，无新增每帧分配路径。 |
| A46 | passed | specs/architecture-convergence/spec.md | PlayerSpells 只在事件后合并刷新，按键路径不访问 SpellBook。 | PlayerSpells 搜索热路径不访问 SpellBook。 |
| A47 | passed | specs/architecture-convergence/spec.md | secure-spell、drag、Binding、事件和 XML/TOC 使用 Retail 当前 wowdoc 证据；战斗中保持现有严格禁用策略。 | Retail 12.1.0 wowdoc 校验 27 个 Lua 文件且 valid=true。 |
| A48 | passed | specs/architecture-convergence/spec.md | 固定 Command：单结果、别名、每 Command priority、disable/enable、unregister、ambient 调度和实体共存。 | 固定 Command 的单结果、别名、priority、突变隔离和生命周期有直接测试。 |
| A49 | passed | specs/architecture-convergence/spec.md | CapabilityBroker：请求/结果 Schema、停用 Provider、确定性优先级、异常隔离、能力缺失和注销清理。 | Capability 的 Schema、生命周期、排序、版本范围、异常和注销有直接测试。 |
| A50 | passed | specs/architecture-convergence/spec.md | SearchSession：连续输入、IME 修订、timer 取消、隐藏、进战、迟到结果和 source 失效。 | SearchSession 的连续输入、取消、隐藏、战斗、迟到结果和 source 失效有测试。 |
| A51 | passed | specs/architecture-convergence/spec.md | ResultActionExecutor：普通 Intent、Panel transition、跨 Extension 拒绝、drag、secure-spell、战斗、availability 和旧 token。 | Intent owner、Panel、drag、secure、战斗、availability 和旧 token 有测试。 |
| A52 | passed | specs/architecture-convergence/spec.md | PlayerSpells：实时快照、别名/描述、失败保留、handle 提交、disable/unregister 清理。 | PlayerSpells 实时快照、别名、描述、失败保留、handle 更新和生命周期有测试。 |
| A53 | passed | specs/architecture-convergence/spec.md | 回归：Lua 5.1 语法、全部 smoke、合同检查、Retail wowdoc validate、git diff --check、正式服文件清单和 SHA-256。 | 36 个 Lua 文件、全部 smoke、合同、wowdoc 和 git diff --check 均通过。 |

## Checks

| Check | Command | Working directory | Status | Exit | Duration |
| --- | --- | --- | --- | ---: | ---: |
| Lua 5.1 syntax for runtime tests and SDK | -NoProfile -Command $ErrorActionPreference='Stop'; $files = Get-ChildItem package/Lychee,tests,lychee-sdk -Recurse -File -Filter *.lua; foreach ($file in $files) { & luac -p $file.FullName; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }; Write-Output ('PASS lua syntax: ' + $files.Count + ' files') | . | passed | 0 | 550 ms |
| Runtime smoke | tests/smoke.lua | . | passed | 0 | 31 ms |
| Interaction and action execution smoke | tests/interaction_smoke.lua | . | passed | 0 | 36 ms |
| Search platform smoke | tests/search_platform_smoke.lua | . | passed | 0 | 29 ms |
| Search session smoke | tests/search_session_smoke.lua | . | passed | 0 | 24 ms |
| Command catalog smoke | tests/command_catalog_smoke.lua | . | passed | 0 | 26 ms |
| Capability broker smoke | tests/capability_broker_smoke.lua | . | passed | 0 | 27 ms |
| Architecture contract guards | -NoProfile -ExecutionPolicy Bypass -File tests/check_contract.ps1 | . | passed | 0 | 361 ms |
| Retail 12.1.0 wowdoc validation | -NoProfile -Command wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref 12.1.0; exit $LASTEXITCODE | . | passed | 0 | 303 ms |
| Git whitespace validation | diff --check | . | passed | 0 | 59 ms |
| Architecture forbidden-access audit | -NoProfile -Command $ErrorActionPreference='Stop'; $checks = @(@{Path='package/Lychee/Search/QueryOrchestrator.lua'; Pattern='Catalog\.commands\|self\.generation\|_BeginGeneration\|function\s+Q:Invalidate'}, @{Path='package/Lychee/Builtin/PlayerSpells'; Pattern='StaticIndex\|sourceGeneration\|builtin\.player-spells:records'}, @{Path='package/Lychee/Bootstrap.lua'; Pattern='palette\.(generation\|session)\|palette:(Execute\|Run\|Dispatch)'}, @{Path='package/Lychee/UI/Palette.lua'; Pattern='secure%-spell\|open%-detail\|builtin%-panel'}); foreach ($check in $checks) { $hits = Get-ChildItem -LiteralPath $check.Path -File -Recurse \| Select-String -Pattern $check.Pattern; if ($hits) { $hits \| ForEach-Object { Write-Error ($_.Path + ':' + $_.LineNumber + ': ' + $_.Line) }; exit 1 } }; $legacy = rg -n 'Command 是唯一\|用户输入只匹配 Command\|实体必须.*ambient\|需要实体搜索时.*ambient\|必须注册引用该 Provider\|新增数据源时注册 Provider\|Provider\s*->\s*Command\|可搜索入口是两份显式声明\|ambient.*Command 负责直接命中名称' docs/comet/specs docs/ARCHITECTURE.md docs/SDK.md lychee-sdk; if ($LASTEXITCODE -eq 0) { $legacy; exit 1 }; if ($LASTEXITCODE -ne 1) { exit $LASTEXITCODE }; Write-Output 'PASS architecture forbidden-access audit' | . | passed | 0 | 241 ms |

## Blockers

_None._

## Risks and skipped work

- Git 提交、正式服复制及完整 SHA-256 对比尚待 Comet 接受和归档后执行。
- 真实客户端中的硬件点击、拖拽和 /reload 仍需最终游戏内验证。

## Previous iterations

| Goal cycle | Iteration | Attempt | Outcome | Unresolved | Summary | Completed |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | fail | A2, A4, A7, A14, A19, A23, A41, A51 | 主要模块拆分已完成，但 retiring 时序、generation 所有权、source invalidation、Intent owner 边界、第三方 fixture 和文档旧模型仍需回到 Build 收敛。 | 2026-08-28T11:42:46.848Z |
| 1 | 2 | 1 | fail | A7, A12, A13, A15, A16, A41 | 第二轮修复了 retiring、generation、source invalidation、Intent owner 和 fixture 问题，但 Catalog 声明仍可被提交后突变，Capability 版本选择未实现，文档仍残留稳定实体走 ambient Command/Provider 的旧模型。 | 2026-08-28T12:09:43.490Z |
| 1 | 3 | 1 | pass | — | 上一轮的 descriptor 突变、Command priority、Capability 版本范围、公共 handle 转发和文档旧模型问题均已修复，当前实现满足完整验收合同。 | 2026-08-28T12:26:09.556Z |

## Conclusion

上一轮的 descriptor 突变、Command priority、Capability 版本范围、公共 handle 转发和文档旧模型问题均已修复，当前实现满足完整验收合同。
