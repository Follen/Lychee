---
generated_from_state_version: 23
---

# Verification

## Current result

- Result: **Passed**
- Assurance: **skill-coordinated**
- Goal cycle: 2
- Iteration: 4
- Verifier attempt: 1
- Completed: 2026-08-25T17:50:29.280Z
- Summary: 第四轮候选完成全部离线验收；保留真实 WoW 客户端安全 API 和快捷键行为的手工验证限制。

## Acceptance

| ID | Result | Source | Criterion | Reason |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：`package/Lychee/Lychee.toc`、`Bindings.xml` 和入口 Lua 可被静态检查识别；加载后创建 `_G.Lychee`，不依赖 sibling SDK AddOn。 | TOC、Bindings.xml、入口 Lua 和单一 _G.Lychee facade 检查通过。 |
| A2 | passed | brief.md | A2：第三方 fixture 使用 `## OptionalDeps: Lychee` 和 `_G.Lychee` 完成一次 `RegisterExtension -> Register* -> Commit`；facade 缺席时只注册一次 `ADDON_LOADED` 监听，迟到加载后幂等完成注册。 | 第三方 fixture 使用 OptionalDeps: Lychee/_G.Lychee，完成 RegisterExtension、Register*、Commit，且 QueryCapability 闭包在 committed handle 上工作。 |
| A3 | passed | brief.md | A3：ExtensionRegistry 正确处理 `draft -> pending -> registered -> enabled -> retiring -> removed`；重复 ID、非法 schema、未知 API major 返回稳定错误，不发布半成品。 | Registry 事务状态、边界校验、回滚和注销行为通过原有 smoke。 |
| A4 | passed | brief.md | A4：CommandCatalog 只收录 Command；catalog/ambient 查询共享 generation/debounce，旧 generation 结果不会覆盖新查询，Provider 不会自动成为搜索入口。 | Provider 不进入 Catalog；generation/debounce guard 保证旧查询不能覆盖新结果。 |
| A5 | passed | brief.md | A5：Locale/alias 索引只在注册或数据更新时构建；当前 locale 与 `default` 生效，`复仇之怒` 的 `翅膀`、传送法术的 `红玉` 命中同一个 canonical item，不复制结果。 | PlayerSpells 与 DungeonGuide 均在数据刷新时建立 UTF-8 gram 候选桶，查询不再全量扫描 alias，canonical alias smoke 通过。 |
| A6 | passed | brief.md | A5a：登录及 `SPELLS_CHANGED`、`LEARNED_SPELL_IN_TAB`、`PLAYER_SPECIALIZATION_CHANGED`、`TRAIT_CONFIG_UPDATED` 事件后，Provider 使用 `C_SpellBook` skill-line/item API 重建当前角色法术快照；查询不读取静态技能清单或全表扫描。 | PlayerSpells 使用 C_SpellBook 实时快照和四类刷新事件，瞬时失败保留旧快照，查询走预索引。 |
| A7 | passed | brief.md | A6：`PlayerSpells` 只有一份 Provider/法术索引；技能详情、动作条拖拽和 secure-spell 交互共用同一 item ID 与生命周期。 | 详情、drag、secure-spell 共用同一实时 spell item ID。 |
| A8 | passed | brief.md | A7：Host 统一创建/复用结果行和 Panel；结果支持 primary click/Enter、显式次级 action、专用 spell drag 和受限 secure-spell，第三方不能取得 Palette 根 frame 或 SecureButton。 | ViewHost 将 transition state 传入 create/Mount，正确调用 instance Unmount/Dispose；结果行 click/drag/secure 均检查 session、generation、extension 生命周期并主动清理。 |
| A9 | passed | brief.md | A8：`Lychee_Toggle` 委托 `PaletteController:Toggle()`；首次脱战且无冲突时尝试 `ALT-SPACE`，战斗中静默，`PLAYER_REGEN_DISABLED` 关闭已打开 Palette，脱战后恢复。 | Toggle 委托 Host-private PaletteController，战斗 guard、进战关闭和脱战绑定重试存在。 |
| A10 | passed | brief.md | A9：隐藏 Palette 没有常驻 Lua OnUpdate；共享 ticker 无订阅者时隐藏；结果行、交互槽和临时表池化；setter 通过 change guard，关闭/卸载清理 ticker、timer、事件和引用。 | Scheduler 无订阅隐藏且 swap-remove；QueryOrchestrator 支持 NewTimer Cancel、token/generation 失效；结果行和 setter 有池化/change guard。 |
| A11 | passed | brief.md | A10：静态/离线测试覆盖 schema、Locale/alias、generation、状态机、战斗 guard、secure-spell 拒绝 scripted click、拖拽 payload 校验、第三方 fixture 注册和性能静态规则。 | 原有 smoke 加 interaction_smoke 可执行覆盖 schema、alias、generation、combat、secure scripted click、drag payload、Scheduler、Panel cleanup、stale row 和第三方 fixture。 |
| A12 | passed | brief.md | A11：`git diff --check`、Lua/XML/TOC 静态检查通过；提交只包含运行时代码、SDK 开发包和必要测试，不包含 `analyze/`、`.comet/` 或归档。 | luac、smoke、interaction smoke、contract checks、git diff --check 均通过；HEAD d322c6d 只包含运行时、SDK fixture 和测试。 |

## Checks

_No Runtime checks were recorded._

## Blockers

_None._

## Risks and skipped work

- 真实 WoW 客户端中的 SecureActionButton 硬件点击、C_Spell.PickupSpell、战斗锁定、焦点和 ALT-SPACE 冲突仍需 /reload 手工验证。

## Previous iterations

| Goal cycle | Iteration | Attempt | Outcome | Unresolved | Summary | Completed |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | 需求修订：PlayerSpells 必须以当前角色实时法术书为事实源，使用 C_SpellBook skill-line/item API，并由 SPELLS_CHANGED、LEARNED_SPELL_IN_TAB、PLAYER_SPECIALIZATION_CHANGED、TRAIT_CONFIG_UPDATED 事件触发快照重建；静态表仅保留 alias 定义和离线 fallback。实现、正式文档与 smoke 已同步。 | 2026-08-25T16:33:39.931Z |
| 2 | 1 | 1 | execution-error | — | Verifier was not dispatched before the previous session ended, and candidate 7fe8bc4b-1bbe-41d2-9b5a-d1e483da737b is stale after commit 06ae8e8 separated builtin business data from provider logic. | 2026-08-25T16:45:20.631Z |
| 2 | 1 | 2 | fail | A3, A4, A5, A6, A8, A9, A10, A11 | Static checks pass, but registration atomicity, Panel transitions, secure-spell initialization, canonical spell data, search performance, binding retry, lifecycle cleanup, and tests require another Build iteration. | 2026-08-25T16:55:03.641Z |
| 2 | 2 | 1 | fail | A2, A10, A12 | The previous candidate passed implementation inspection except for public Host-handle exposure, incomplete required test evidence, and uncommitted changes; those are addressed in the next Build state. | 2026-08-25T17:21:18.366Z |
| 2 | 3 | 1 | execution-error | — | Native Verifier response was invalid: Native Verifier acceptance coverage is invalid (duplicate: none; unknown: none; missing: A12) | 2026-08-25T17:30:13.233Z |
| 2 | 3 | 2 | fail | A5, A8, A10, A11 | 需回到 Build 修复 DungeonGuide 预索引、Panel state、可取消 timer、注销清理并补充 A10 行为测试。 | 2026-08-25T17:35:29.130Z |
| 2 | 4 | 1 | pass | — | 第四轮候选完成全部离线验收；保留真实 WoW 客户端安全 API 和快捷键行为的手工验证限制。 | 2026-08-25T17:50:29.280Z |

## Conclusion

第四轮候选完成全部离线验收；保留真实 WoW 客户端安全 API 和快捷键行为的手工验证限制。
