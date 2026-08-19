# Outcome

交付 Lychee 命令平台的完整设计文档，使后续实现可以依据明确的模块边界、SDK 注册协议、搜索链路、两种第三方交互模式、快捷键和性能约束落地；本 change 不编写运行时代码。

# Scope

- 定义 `Extension -> Command / CapabilityProvider / IntentHandler / PanelFactory` 分层；`CommandSource` 只作为 Extension 发布 Command 的逻辑角色，不是公共对象或第二套 API。
- 定义普通结果行、动态列表和交互视图的呈现生命周期。
- 定义输入匹配、查询代次、结果选择和受控执行链路。
- 设计独立 sibling AddOn `LycheeSDK`，供其他 WoW 插件注册命令和能力。
- 使用单一全局 Binding `TOGGLELYCHEE` 在脱战时呼出 Palette；战斗中该 Binding 静默失效。
- 记录用户提供的透明 PNG 的品牌使用和后续构建约束。

# Non-goals

- 不提供第三方独立全局快捷键。
- 不提供运行时插件下载、安装、市场或网络模型。
- 不允许 Provider 直接绘制 Lychee UI 或获得 Palette 内部 frame。
- 不引入 Ace3 全家桶。
- 不创建 Lychee/LycheeSDK Lua、XML、TOC 或媒体运行时产物。
- 不复制任何文件到正式服 AddOns 目录。
- 不实现首批内置游戏功能。

# Acceptance examples

- A1：`docs/ARCHITECTURE.md` 完整规定 Command、CapabilityProvider、IntentHandler、搜索、UI、快捷键、生命周期和性能边界。
- A2：`docs/SDK.md` 给出第三方可直接照写的 TOC、注册、动态列表、能力调用、Intent 和 custom-panel 契约。
- A3：文档明确 SDK registry 是运行时接入唯一事实源，AddOn 枚举只用于诊断/LoD，AddOnMessage 不承担本机 SDK RPC。
- A4：文档明确内部功能和第三方能力进入同一注册表、搜索器和结果渲染器。
- A5：文档明确 `dynamic-list` 与受控 `custom-panel` 两种模式的所有权、生命周期和错误隔离。
- A6：文档明确唯一 `TOGGLELYCHEE` Binding、完整 `Bindings.xml`/本地化契约、best-effort 输入焦点恢复，以及战斗中静默失效、进战自动关闭、脱战恢复。
- A7：文档包含 API 版本、稳定 ID、pending/attach、卸载、错误码和兼容策略。
- A8：文档包含后续实现顺序、验证矩阵和性能门槛，足以约束后续 Build change。

# Constraints and invariants

- 正式服目录为 `D:\Game\World of Warcraft\_retail_\Interface\AddOns`。
- `Lychee` 与 `LycheeSDK` 作为两个 sibling AddOn 发布。
- 全局快捷键只有 `TOGGLELYCHEE`；`InCombatLockdown()` 为 true 时不得打开、关闭或聚焦 Palette，也不得启动查询，进入战斗时已打开的 Palette 必须走统一关闭路径。
- Command 决定可搜索入口和呈现方式；CapabilityProvider 只提供数据；IntentHandler 负责受控执行。
- 搜索采用确定性 normalization、alias/pinyin、候选检索和稳定排序，不依赖运行时 AI。
- 动态结果必须带查询 generation，返回时校验当前 generation。
- 第三方代码错误只隔离对应 Extension，不影响 Palette 可关闭性。
- 参考 EllesmereUI 的轻量生命周期、直接事件和自停驱动，不依赖 Ace3 framework。
- `AGENTS.md`、`analyze/` 和本机 `.comet/runtime/` 不进入运行时包。

# Decisions

- D1：Command 和 CapabilityProvider 分层，不再使用单一 Provider 同时承担搜索入口、数据能力和 UI。
- D2：Provider 不绘制 UI；普通和动态结果由 Lychee 统一绘制。
- D3：复杂交互由 Command presentation 决定，并由 Lychee 管理焦点、显示、隐藏和清理。
- D4：内部能力与第三方能力使用同一标准数据模型，仅权限和优先级不同。
- D5：借鉴 ZTools 的 Command Catalog、mainPush generation 和插件 view 生命周期，但不照搬 Electron、多进程或运行时安装器。
- D6：Logo 使用用户提供的 500x500 透明 PNG；源文件 SHA-256 为 `96887564230FA250D2AF4B151DEC219E9A166F245771C4414135F498E9E4E7E3`。
- D7：change 使用当前工作区和 `main` 分支，不创建额外 branch/worktree。
- D8：第三方交互同时支持两种 presentation：`dynamic-list` 由 Lychee 统一绘制；`custom-panel` 由 Lychee 提供受控 ViewHost，第三方只绘制自己的 Panel 内容。
- D9：第三方通过 `## OptionalDeps: LycheeSDK` 请求在双方均可用时先加载 SDK，但不得把 TOC 元数据当作 SDK 已存在或注册成功的证明；第三方主 chunk 必须检查 `_G.LycheeSDK`，再创建 draft、调用 `Register*` 和 `Commit()`。SDK 在 Host attach 前保存 committed pending registry，Host attach 后消费并校验。
- D10：运行时 registry 是 SDK 接入的唯一事实源；`C_AddOns.GetNumAddOns`、`GetAddOnInfo`、`GetAddOnMetadata` 和 `GetAddOnDependencies` 只用于诊断、兼容性扫描和展示，不在每次输入时扫描。
- D11：不使用 `C_ChatInfo.SendAddonMessage` 做本机插件间 RPC。该 API 是客户端间频道/目标消息通道，具有前缀、payload 和节流语义；本机接入使用 Lua 全局 SDK 表和结构化注册句柄。
- D12：WoW 官方加载事实以 `C_AddOns.IsAddOnLoaded`、`C_AddOns.LoadAddOn` 和 TOC 元数据为依据；`IsAddOnLoaded` 的第一返回值表示 loaded-or-loading，只有第二返回值表示加载完成。按需加载只是生命周期动作，不替代 SDK 注册协议。
- D13：本 change 只交付设计文档；正式交付位于 `docs/ARCHITECTURE.md` 和 `docs/SDK.md`。运行时代码、Logo 媒体、游戏内验证和正式服同步由后续实现 change 处理。
- D14：内置命令和复杂面板也作为 Builtin Extension 注册，进入同一 CommandCatalog、CapabilityBroker、IntentRouter 和 ViewHost 生命周期。内部面板可使用明确列出的额外 Host service，但不接管 Palette 根 frame 或绕过焦点、关闭和清理状态机。
- D15：Context、payload 和第三方返回值进入索引、Intent、日志或 SavedVariables 前必须递归拒绝 secret 或当前调用方不可访问的值；边界检查使用 `issecretvalue`、`canaccessvalue` 和 `canaccesstable`，失败返回稳定错误码。
- D16：Panel 托管延迟任务使用可取消的 `C_Timer.NewTimer`/`NewTicker` 句柄；无返回句柄的 `C_Timer.After` 只能配合 generation/active guard，不能承诺真正取消。
- D17：受保护 Intent 采用 `SecureActionButtonTemplate` 和声明式 descriptor，但 Lychee 选择更严格的产品策略：战斗中 Palette 不可用，所有 Lychee Intent 返回 `COMBAT_LOCKED`，不保留战斗内真实点击入口。

# Confirmed scope

- [resolved] 本 change 仅交付 `docs/ARCHITECTURE.md` 与 `docs/SDK.md`，覆盖当前 Decisions 和验收示例，不产生运行时插件文件。

# Verification expectations

- 检查两份正式文档覆盖全部 Decisions、核心模型、SDK 发现、交互模式、性能约束和验证要求。
- 检查术语一致性，旧 `Provider/Entry` 模型不再作为顶层公开契约。
- 检查所有 Lua/TOC 示例字段彼此一致，并明确哪些是后续 Build 的拟定 API。
- 运行 Markdown 链接/标题检查（工具可用时）、`git diff --check` 和文件清单检查。
- 确认本 change 没有 Lua/XML/TOC/媒体运行时改动，也没有正式服复制动作。
