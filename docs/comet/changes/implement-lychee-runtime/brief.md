# Outcome

在当前仓库落地可加载的 Lychee Host AddOn 与独立第三方开发包：Host 位于 `package/Lychee/`，SDK 开发包位于 `lychee-sdk/`。实现必须遵循现有 `docs/ARCHITECTURE.md`、`docs/SDK.md` 和生效 Comet 规格，形成单一 `_G.Lychee` facade、统一 Command/Provider/Intent/Panel 链路、可交互搜索结果、第三方接入生命周期和战斗保护策略。

# Scope

- 创建 `package/Lychee/`：TOC、Bindings.xml、Bootstrap、Core、Search、UI、Secure、PublicAPI、Builtin 和 Media 最小可运行骨架。
- 创建 `lychee-sdk/`：第三方接入 README、TOC/Lua 示例、API stubs 和可复制 fixture；SDK 通过 Lychee Host 的 `_G.Lychee` facade 工作，不创建 sibling AddOn。
- 实现 ExtensionRegistry、CommandCatalog、CapabilityBroker、QueryOrchestrator、IntentRouter、ViewHost、结果行池、共享 ticker、ContextStore 和 Diagnostics 的窄接口。
- 实现 Locale/别名规范化与预索引；`PlayerSpells` 只维护一份法术索引，技能俗称和副本传送别名投影到同一 canonical spell item。
- 实现结果 item 的普通点击、Enter、次级动作、spell drag 和 Host-owned secure-spell 描述/生命周期。
- 实现 `TOGGLELYCHEE`、`Alt + Space` 首次绑定尝试和战斗中静默/进战关闭策略。
- 实现至少四类内置搜索场景 fixture：怪物/怪物技能、玩家技能、Boss/赛季别名、副本传送别名。
- 增加离线 Lua 静态检查、schema/索引/状态机单元测试或可执行 fixture；记录 Ellesmere 性能准则对应的零空闲成本、池化、change guard 和事件驱动检查。

# Non-goals

- 不创建独立 `LycheeSDK` AddOn；`lychee-sdk/` 是开发包、stubs、文档和 fixture。
- 不接入网络、聊天 RPC、生成式搜索或运行时全表扫描。
- 不在战斗中打开 Palette、执行 Intent、拖拽、配置 secure attributes 或施放技能。
- 不复制正式服目录，除非后续明确要求并且实现已提交通过验证。
- 不修改 `docs/comet/archive/**`。

# Acceptance examples

- A1：`package/Lychee/Lychee.toc`、`Bindings.xml` 和入口 Lua 可被静态检查识别；加载后创建 `_G.Lychee`，不依赖 sibling SDK AddOn。
- A2：第三方 fixture 使用 `## OptionalDeps: Lychee` 和 `_G.Lychee` 完成一次 `RegisterExtension -> Register* -> Commit`；facade 缺席时只注册一次 `ADDON_LOADED` 监听，迟到加载后幂等完成注册。
- A3：ExtensionRegistry 正确处理 `draft -> pending -> registered -> enabled -> retiring -> removed`；重复 ID、非法 schema、未知 API major 返回稳定错误，不发布半成品。
- A4：CommandCatalog 只收录 Command；catalog/ambient 查询共享 generation/debounce，旧 generation 结果不会覆盖新查询，Provider 不会自动成为搜索入口。
- A5：Locale/alias 索引只在注册或数据更新时构建；当前 locale 与 `default` 生效，`复仇之怒` 的 `翅膀`、传送法术的 `红玉` 命中同一个 canonical item，不复制结果。
- A6：`PlayerSpells` 只有一份 Provider/法术索引；技能详情、动作条拖拽和 secure-spell 交互共用同一 item ID 与生命周期。
- A7：Host 统一创建/复用结果行和 Panel；结果支持 primary click/Enter、显式次级 action、专用 spell drag 和受限 secure-spell，第三方不能取得 Palette 根 frame 或 SecureButton。
- A8：`Lychee_Toggle` 委托 `PaletteController:Toggle()`；首次脱战且无冲突时尝试 `ALT-SPACE`，战斗中静默，`PLAYER_REGEN_DISABLED` 关闭已打开 Palette，脱战后恢复。
- A9：隐藏 Palette 没有常驻 Lua OnUpdate；共享 ticker 无订阅者时隐藏；结果行、交互槽和临时表池化；setter 通过 change guard，关闭/卸载清理 ticker、timer、事件和引用。
- A10：静态/离线测试覆盖 schema、Locale/alias、generation、状态机、战斗 guard、secure-spell 拒绝 scripted click、拖拽 payload 校验、第三方 fixture 注册和性能静态规则。
- A11：`git diff --check`、Lua/XML/TOC 静态检查通过；提交只包含运行时代码、SDK 开发包和必要测试，不包含 `analyze/`、`.comet/` 或归档。

# Constraints and invariants

- 以 `docs/ARCHITECTURE.md` 与 `docs/SDK.md` 为正式合同；生效规格同步，归档只读。
- Ellesmere 性能优先：事件驱动优先、隐藏时零空闲成本、共享 ticker、连续数组/swap-remove、对象池、缓存 key、setter change guard、局部增量更新、延迟 GC。
- 所有外部输入与 SDK 边界值先做 secret/inaccessible/plain-data/schema 验证；错误只影响所属 Extension。
- Command 是唯一搜索入口；Provider 维护预索引和能力，不创建 UI、不注册全局快捷键。
- 受保护动作只允许 Host-owned secure descriptor 和真实硬件点击；战斗中统一 `COMBAT_LOCKED`。
- 每次代码修改必须运行静态检查并提交 Git；本 change 不复制正式服，除非用户后续明确要求。

# Decisions

- 运行时 Host 根目录采用 `package/Lychee/`；第三方开发包采用 `lychee-sdk/`，名称与 Host AddOn 解耦但不作为运行时 AddOn。
- 内置模块先实现可运行最小垂直切片，保持文件边界与正式架构树一致；复杂外部指南 adapter 先以稳定接口占位，不操作第三方内部 frame。
- WoW API 不可在本机完整执行时，使用离线 Lua fixture、schema 测试和静态契约检查验证；真实游戏行为保留明确手工验证记录入口。

# Open questions

无阻塞问题。实现阶段按现有正式合同推进；任何会改变用户可见行为的新增决定需返回 Shape 更新 brief。

# Verification expectations

- `git diff --check`。
- 运行仓库可用的 Lua 语法/静态检查与 SDK fixture 测试。
- 检查 TOC/XML 引用、`_G.Lychee` facade、`OptionalDeps: Lychee`、无 `LycheeSDK` sibling 模型。
- 检查 active specs 与正式文档的 Locale/alias、PlayerSpells、Toggle、生命周期和 API 错误语义一致。
- 记录未能在无 WoW 客户端环境验证的 secure click、真实拖拽和战斗锁定行为，不将静态通过冒充游戏内通过。
