# Lychee 通用搜索框架

当前契约：Provider API 2 / revision 1。字段定义见 [PROTOCOLS.md](PROTOCOLS.md)，接入见 [SDK.md](SDK.md)。

## 产品模型

Provider 是搜索能力的提供者，可以来自 Lychee 自身或第三方 AddOn。条目可以是可执行入口、实体、当前状态或只读信息。业务类别是展示元数据；点击、拖动和视图由显式声明决定，不由 `kind` 推导。

Host 持有搜索会话、索引、排序、结果行、最近使用和受保护执行器。Provider 持有业务数据、普通回调及可选视图内容。结果布局由 Host 统一决定；第三方不能通过 SDK 获取 Palette 根 frame 或 SecureButton。

## 模块与数据流

```text
Lychee:RegisterProvider(definition)
  -> ProviderRuntime: validation, copying, instances, query tasks, resolution
  -> ExtensionRegistry: registration and enabled/removed lifecycle
  -> StaticIndex: compiled entries, matching, incremental replacement
  -> QueryOrchestrator + SearchSession: merging, ranking, cancellation
  -> ResultList / recent tiles: one presentation and interaction model
  -> ResultActionExecutor
       ordinary callback -> ProviderRuntime
       managed view      -> ViewHost
       protected spell   -> SecureActionBroker + Policy
       declared drag     -> Host cursor adapter / Provider callback
```

`CommandCatalog`、`CapabilityBroker`、`IntentRouter` 保留为 Host 内部模块与独立测试对象，不是 API 2 的第三方接入模型。SDK 不公开旧的 Extension draft 或多角色注册流程，也不维护一套旧协议适配层。

ProviderRuntime 是统一边界，不建立第二套索引或第二套启用状态。公共句柄只提供 Update、SetEnabled、GetState、Unregister；内部 generation 和 source token 不交给调用方。

## 数据与身份

每个 Provider 有全局 ID；条目 ID 在 Provider 内稳定且唯一。对外稳定引用为 `{providerID,entryID}`。实例、索引版本、查询 epoch 是临时有效性凭据，不能充当持久化身份。两个 Provider 可以使用相同条目 ID，不会互相去重或覆盖历史。

注册、更新、动态回复、动作结果均经过边界校验。Host 复制输入，不给调用方原表附加私有字段；普通回调接收条目和 context 的副本。整批验证成功后才发布。非法声明、超量、重复 ID、未声明动作或未知执行器返回结构化错误。

静态条目通过 Update 更新。编译索引仅移除/重建实际变化的条目，同一帧的来源通知合并为一次当前查询刷新；已有画面保留到替换结果就绪。显示行复用，文本、颜色、纹理和尺寸使用现有 change guard。

## 查询生命周期

静态目录不需要 query。动态 Provider 通过 `query(request,reply,context)` 提供候选，reply 最多成功一次，可以同步调用或延迟调用。返回的取消函数在完成、关闭、换词、超时、禁用或注销时调用，最多一次。Host 等待上限为五秒；这不意味着能抢占正在运行的同步 Lua。

结果统一在 Host 去重、排序、限量并展示。scope 和筛选对静态/动态来源都生效。晚到回复、旧实例句柄、旧条目版本和旧菜单回调无法操作新会话或同 ID 的新注册实例。诊断只保留有界的 Provider ID、错误码和阶段，不保存完整业务 payload 或异常栈。

动态最近使用通过独立 `resolve(entryID,context)` 获取当前条目。没有 resolve 的瞬时查询条目不写入历史；静态目录无需实现 resolve。当前版本不提供异步恢复或流式回复。

## 动作与视图

普通业务通过注册的命名 `run` 回调扩展，不为每种业务新增 action kind。结果只引用回调 ID，不携带闭包。普通回调可返回成功/业务错误、关闭搜索或打开本 Provider 的托管视图。

受保护动作使用 Host 已支持的描述符。目前提供技能施放；必须通过真正的硬件点击，不把普通回调包装成安全脚本。其他受保护类型需独立查档、实现适配器和实机验证后才能加入协议。

拖动与点击相互独立。原生 spell cursor 与 Provider 自有非保护拖动各有声明，没有声明就不注册拖动。菜单可访问全部声明动作；搜索行、最近使用图标和安全覆盖层使用同一执行校验。

ViewHost 提供内容容器并管理 create、Mount(initialState)、Update(state)、Unmount、Dispose。Provider 负责释放自己建立的事件、计时器等活动；可复用 frame，不能让隐藏视图持续工作。

## 内置 Provider

`Builtin/Init.lua` 在登录后注册玩家技能、纹章、游戏菜单与首领。新增业务只调用公开 `RegisterProvider`，不向 Host 增加动作类型或业务分支。API 保持 2 / revision 1。

- `Crests.lua`：一个可搜索条目和一个托管视图；五档当前迷雾纹章首次打开时创建固定行，之后复用。只在显示时注册 `CURRENCY_DISPLAY_UPDATE`，带货币 ID 的事件仅刷新对应行；关闭、禁用、注销均停止事件，读取失败显示“—”并允许重试。
- `GameMenus.lua`：34 条静态菜单记录，每条引用固定开窗函数和本地透明 TGA 图标；支持分页的界面传明确页签，切换式入口先检查已打开状态。冒险指南的六个入口从实际页签控件读取 ID，复用原生 OnClick 路径同步显示与游戏保存的页签；隐藏、禁用或受限页签返回失败。
- `Bosses.lua` 与 `Data/JournalCatalog.lua`：由版本化 DB2 快照生成首领/副本关系，副本名作为每个首领的别名。搜索时不加载手册或扫描游戏 API；点击时延迟加载并检查精确 instanceID / encounterID。
- `InterfaceActions.lua`：内置模块共用的窄封装，处理原生调用失败、已打开窗口和战斗限制；失败不关闭搜索或写入成功历史。

数据版本、更新命令、离线成本与实机验收范围见 [内置 Provider 验证记录](validation/2026-09-10-builtin-providers.md)。

菜单图标由 `tests/build_menu_icons.py` 的矢量路径离线生成，运行时只加载 `Media/MenuIcons/*.tga`。资产自带 5 px 透明安全边距，兼容 Host 现有 7% 裁切；不增加特殊图标协议、运行时绘图或回调。

## 启停、性能和存储

onEnable(handle) 可返回清理函数；禁用/注销调用一次。SDK 还提供可取消的 RegisterReady。Provider 必须在其清理函数中释放自身事件与计时器。Host 单独清理查询任务、时限计时器和视图。

不新增 OnUpdate 或空闲轮询。查询等待时才有 deadline timer，来源变化时才有一次合并刷新 timer。静态目录最多 4096 条，动态回复最多 256 条，最终列表最多 20 条；每条最多 16 个动作。同步业务回调应快速返回，重工作由集成方使用游戏事件或异步完成。

SavedVariables schema 2 只保存设置与最小身份历史。搜索索引、动作 payload、回调和 frame 不持久化。旧数据直接不采用，不执行迁移。

## 验证

公开 API 测试覆盖原子性、可变输入隔离、实例重用、同 ID 跨 Provider、动态取消/恢复、无动作条目、未知适配器、容量和生命周期。UI 测试覆盖真实 Host 渲染、视图初始/更新状态、菜单与安全右键。WoW API 证据和最终静态验证记录位于 `docs/architecture/`、`docs/validation/`。

离线验证不声称测得真实客户端战斗 CPU、帧时间、taint 或安全点击行为。客户端验收需要记录登录、空闲、战斗、峰值对象量和窗口打开/关闭的实际样本。
