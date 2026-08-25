# Outcome

让 Lychee 下拉结果成为可交互的实体入口：每个结果可声明主点击动作、有限的次级动作和可选拖拽 payload。用户可直接点击打开详情或由真实鼠标点击施放已知法术，也可从专用拖拽区域把法术拖到动作条。

# Scope

- 修改 Command Platform 与 LycheeSDK 的完整设计规格，以及归档后的 `docs/ARCHITECTURE.md`、`docs/SDK.md`。
- 定义结果 item 的 `interaction` 描述符、主动作、次级动作、动作路由、拖拽描述符和 Host 绘制/生命周期边界。
- 明确普通 Intent、详情 Panel、MRT 等可选指南适配器、法术拖拽和安全法术按钮在同一结果行中的组合方式。
- 为内置 Extension 给出四类 fixture：大秘境怪物/技能资料、玩家法术、Boss/赛季别名、已知副本传送技能。
- 记录 Retail API 证据：`C_Spell.PickupSpell` 用于真实 `OnDragStart`；脚本 `Button:Click()` 不能模拟受保护点击。

# Non-goals

- 本 change 不创建 Lua/XML/TOC 运行时代码、不修改正式服目录。
- 不在战斗中打开 Palette、拖拽、配置 secure 属性或施放技能。
- 不承诺通过 Enter、普通 Lua 回调或脚本 `Button:Click()` 施放受保护法术。
- 不把 Palette 根 frame、SecureButton 或任意 Lua 回调交给内部 Provider 或第三方 Extension。
- 不保证第三方指南插件（包括 MRT）存在或提供稳定公开跳转 API。

# Acceptance examples

- A1：`docs/ARCHITECTURE.md` 明确下拉结果 item 可声明 `interaction`，由 Host 统一绘制主动作、次级动作和可选拖拽区域；Provider/Extension 不创建结果行 frame 或直接绑鼠标脚本。
- A2：每个可激活动作具有稳定 action ID 和有界 plain-data 描述；普通点击、键盘 Enter 与次级按钮均先生成结构化 Intent，再由 IntentRouter 调用白名单 Handler。
- A3：结果只有一个主动作时，左键点击和 Enter 均执行该动作；多个动作时，左键/Enter 只执行显式 primary action，其他动作通过 Host 绘制的明确按钮触发，不能靠显示文字猜测回调。
- A4：打开详情、打开已加载的指南页面和其他普通动作均由 Handler 返回声明式 transition 或执行结果；MRT 等外部 UI 只经可选适配器的稳定公开接口接入，缺席或不可用时只影响该动作。
- A5：法术结果可以声明受限 `drag = { type = "spell", spellID = number }`；Host 只在用户真实从专用拖拽区域发起 `OnDragStart` 时调用 `C_Spell.PickupSpell(spellID)`，随后由动作条接收鼠标光标内容。
- A6：拖拽和安全施放不接受任意函数、Frame、宏文本或任意安全属性；Host 校验 spell ID、玩家可用性、非被动状态、Extension/会话/generation 和战斗状态，失败不改变鼠标光标并返回稳定错误码。
- A7：可以施放的结果由 Host 在脱战且绑定数据已验证时配置为 Host-owned `SecureActionButtonTemplate`；用户真实左键点击该安全结果/按钮才可施放。Enter、IntentRouter、普通 Lua 回调和 scripted `Button:Click()` 都不能模拟该点击。
- A8：Palette 的战斗策略不变：战斗中 `TOGGLELYCHEE` 静默，进战关闭 Palette；所有行动作、拖拽、transition 和安全按钮准备均停止或返回 `COMBAT_LOCKED`。
- A9：交互描述符跟随 stable item ID、result generation 和 Extension 状态；输入变化、关闭、进战、禁用或注销后，旧行的普通动作、拖拽和 secure click 均不能执行或污染新会话。
- A10：定义四类内置 Extension 组合：怪物/怪物技能名称打开资料或可选 MRT 适配器、玩家技能搜索和动作条拖拽、Boss/赛季别名打开攻略、已知副本传送技能的搜索/拖拽/真实点击施放。
- A11：内置 Provider 与第三方 Extension 使用同一 `Command -> Provider -> item interaction -> Intent/Panel` 模型；内置模块只通过 Host 的注册 facade 发布，不拥有第二套结果行或安全执行通道。
- A12：SDK 文档给出可直接照写的 `interaction.actions`、`itemIntent(item, actionID, context)` 和 spell drag 示例，并定义 API revision、schema 拒绝条件、错误码和清理路径。
- A13：动态结果仍满足既有性能合同：池化行、稳定 action slot 上限、按 item/action key 增量更新；动作不会在 resolver 内执行，拖拽/安全属性仅在行绑定且 Palette 可见时处理。
- A14：验证矩阵覆盖：主点击与 Enter、次级动作、拖拽到动作条、真实点击施放与脚本点击拒绝、MRT 适配器缺席、旧 generation、关闭/进战/禁用/注销清理及四类内置 Provider。
- A15：`TOGGLELYCHEE` 的首次默认绑定为 `ALT-SPACE`；仅当该 action 尚未绑定且 `ALT-SPACE` 未被其他 action 占用时写入。之后玩家在 WoW 按键设置中的改动永不被 Lychee 回写或覆盖。

# Constraints and invariants

- Command 仍是唯一搜索入口；Provider 仍只提供数据和索引，不能因声明 interaction 自动成为搜索入口。
- `interaction`、action payload、drag payload 与 transition state 全部先通过 secret/inaccessible/plain-data 校验。
- 动作所有权固定为产生 item 的 Command 所属 Extension；跨 Extension Handler、Panel 或 secure descriptor 一律拒绝。
- 结果的普通主动作与安全主动作互斥：安全动作只接受真实鼠标点击，不允许 Enter 代替。
- 当前只定义 `spell` 拖拽和 Host-owned secure spell action；未来新增类型必须通过新的 API revision 与 Host 白名单。
- Retail 12.1.0、`wow-ui-source` 提交 `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`：`C_Spell.PickupSpell` 定义于 `SpellDocumentation.lua:928`，暴雪在 `SpellFlyout.lua:71-76` 的 `OnDragStart` 调用它；`Button:Click()` 在 `SimpleButtonAPIDocumentation.lua:42-45` 标记 `ScriptedInput` 限制。

# Decisions

- 下拉行采用“主动作 + 明确次级按钮 + 专用拖拽区域”而不是右键菜单或一行自动猜测行为。原因是技能既可打开资料又可拖拽/施放，操作含义必须可见且稳定。
- 普通主动作可由左键或 Enter 触发；安全法术主动作必须由用户真实左键点击预配置的 Host 安全行/按钮触发。原因是 WoW 不允许脚本点击伪造硬件输入。
- 详情和外部指南页面都统一走 IntentHandler；MRT 是可选 adapter，不把其内部 frame 当作 Lychee 的稳定 API。
- 交互描述符属于动态 item，不是 Provider；同一 Provider 可被不同 Command 用不同动作方式展示。
- 默认唤起键是 `Alt + Space`（binding token：`ALT-SPACE`）。首次初始化只在脱战执行一次：`TOGGLELYCHEE` 没有现有绑定且 `ALT-SPACE` 空闲时才调用 `SetBinding("ALT-SPACE", "TOGGLELYCHEE")` 和 `SaveBindings(GetCurrentBindingSet())`；任何已有 action 或占用冲突都不覆盖，并由设置页交给玩家处理。

# Open questions

- [blocking] CONFIRM: 本次交付只更新架构、SDK 和 Comet 规格；默认交互为“普通主动作可左键/Enter，多个普通动作显示按钮，法术从专用区域拖拽，安全施放只允许真实鼠标点击”；默认唤起键为 `Alt + Space`，但绝不覆盖玩家已有绑定；并保留战斗中 Palette 完全不可用。确认后进入 Build。

# Verification expectations

- Markdown 标题、链接、代码围栏和跨文档术语检查通过。
- 对照当前正式 `command-platform`、`sdk-integration` 规格，确认所有既有 ambient、Provider、Intent、Panel、战斗、secret 与生命周期合同仍保留。
- `git diff --check` 通过；独立 Verifier 逐项验收 A1-A15。
