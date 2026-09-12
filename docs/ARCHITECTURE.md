# Lychee 通用搜索框架

运行时低内存重构另见 [角色存储与生命周期设计](architecture/2026-09-12-runtime-lifecycle.md)。它覆盖插件、SDK、构建和验收；以下描述已实现架构；保留紧凑目录，不包含全量休眠或伴随包。

当前契约：Provider API 2.6 / revision 6。字段定义见 [PROTOCOLS.md](PROTOCOLS.md)，接入见 [SDK.md](SDK.md)。

Provider 可声明 `searchable=false` 保留目录与引用能力，同时退出通用搜索索引；独立 query 控制触发范围。该策略由 Host 通用协议处理，查询引擎不判断具体 Provider ID。省略声明保持旧行为。

## 产品模型

Provider 是搜索能力的提供者，可以来自 Lychee 自身或第三方 AddOn。条目可以是可执行入口、实体、当前状态或只读信息。业务类别是展示元数据；点击、拖动和视图由显式声明决定，不由 `kind` 推导。

Host 持有搜索会话、索引、排序、结果行、最近使用和受保护执行器。Provider 持有业务数据、普通回调及可选视图内容。结果布局由 Host 统一决定；第三方不能通过 SDK 获取 Palette 根 frame 或 SecureButton。

## 模块与数据流

```text
Lychee:RegisterProvider(definition)
  -> ProviderLocales: per-Provider resources, bounded validation, selected locale
  -> ProviderRuntime: product scopes, validation, copying, instances, query tasks, resolution
  -> ExtensionRegistry: registration and enabled/removed lifecycle
  -> StaticIndex: compiled entries, matching, incremental replacement
  -> QueryOrchestrator + SearchSession: merging, ranking, cancellation
  -> ResultList / recent tiles: one presentation and interaction model
  -> ResultActionExecutor
       ordinary callback -> ProviderRuntime
       custom view       -> ViewHost
       protected spell   -> SecureActionBroker + Policy
       declared drag     -> Host cursor adapter / Provider callback
```

`CommandCatalog`、`CapabilityBroker`、`IntentRouter` 保留为 Host 内部模块与独立测试对象，不是 API 2 的第三方接入模型。SDK 不公开旧的 Extension draft 或多角色注册流程，也不维护一套旧协议适配层。

ProviderRuntime 是统一边界，不建立第二套索引或第二套启用状态。公共句柄提供 Text、Update、SetEnabled、GetState、Unregister；内部 generation 和 source token 不交给调用方。

## 产品与语言边界

API 2.2 的 Provider 必须明确 `scope.products`（1–4 个唯一的 retail／classic／titan／anniversary）并注册自己的 `i18n`，不能使用 Host 私有字典代替业务翻译。产品范围与 build／interface 上下界共同决定可用性；不支持的来源不启动功能事件和后台工作。旧 revision 1 无产品声明默认仅正式服。

ProviderLocales 只编译普通资源表：enUS 是完整基线，zhCN／zhTW／enGB 可部分覆盖，禁止额外键。四个 locale 各最多 256 键，键 96 字节、值 1024 字节，总计 128 KiB；格式参数保持类型和顺序。编译后按当前 locale、同族 zhCN／enUS、enUS 的顺序构建 Provider 自有的选定字典，无全局第三方命名空间。语言资源外部修改与已注册字典隔离，关闭不产生任何语言驱动或事件。

严格 `{key="KEY"}` 在注册、更新和动态回复边界解析为显示文本；普通字符串和搜索别名仍按字面处理。引用不能添加 scope／locale 字段。公共 `handle:Text` 支持最多 16 个参数、每个字符串 1024 字节、结果 32768 字节的受限格式化；未知键和非法格式以结构化错误返回。显示文本进入原有索引，不另建翻译索引。客户端语言参与搜索／目录缓存身份，产品支持与语言选择分别判断。

Host 自身界面语言由独立基础字典负责，zhTW 暂以简中回退，enGB 使用英语。品牌显示为 `|cffd53c49荔枝|r启动器`／`|cffd53c49Lychee|r Launcher`，描述为“魔兽世界万用启动器”／“Universal launcher for World of Warcraft”；目录名与稳定 AddOn ID 始终是 Lychee。

## 数据与身份

每个 Provider 有全局 ID；条目 ID 在 Provider 内稳定且唯一。对外稳定引用为 `{providerID,entryID}`。实例、索引版本、查询 epoch 是临时有效性凭据，不能充当持久化身份。两个 Provider 可以使用相同条目 ID，不会互相去重或覆盖历史。

注册、更新、动态回复、动作结果均经过边界校验。Host 复制输入，不给调用方原表附加私有字段；普通回调接收条目和 context 的副本。整批验证成功后才发布。非法声明、超量、重复 ID、未声明动作或未知执行器返回结构化错误。

静态条目通过 Update 更新。编译索引仅移除/重建实际变化的条目，同一帧的来源通知合并为一次当前查询刷新；已有画面保留到替换结果就绪。显示行复用，文本、颜色、纹理和尺寸使用现有 change guard。

索引保存 UTF-8 字符倒排集合，以最小集合与其余查询字符求交，完整短语和跨字段多词匹配仍由评分器确认。中文搜索不再补扫所有记录，也不再维护重复的整词、前缀和二三字片段映射。单条目集合直接保存键，多条目集合记录数量并在移除后缩回单条目；模糊候选独立限额。排序只维护最终前 20 个结果，匹配失败不分配 evidence/options 表。

Provider 与索引共享 Host 已验证的 canonical 记录；外部输入与动作回调的拷贝隔离不变。来源停用时释放编译字段和倒排关系，保留记录以便恢复。Normalizer 文本缓存采用 1,024 项上限；动态恢复记录使用弱值表，由可见结果维持有效引用。主面板首次非战斗打开时创建，之后复用。测量、正确性对照及游戏内复测边界见 [深度性能优化记录](validation/2026-09-10-deep-memory-optimization.md)。

## 搜索质量与职责边界

`Normalizer` 集中管理字面命中位置与字段评分。静态索引调用 `ScoreCompiled`，动态条目经 `MatchRecord` 将已校验记录适配成相同字段；高亮与成就查询复用 `FindLiteral`。索引只负责候选召回、有效范围和前 20 条选择，不再另外实现跨词评分。

1–2 个 ASCII 英文字母只命中完整词或词首，不参与编辑距离模糊匹配；包含这种短词的多词查询也不能通过模糊匹配绕过边界。3 个及以上英文字母保留词中匹配，中文与数字沿用原规则。空白与标点构成英文词界，紧邻的数字或 UTF-8 文字不构成词界。连续输入仍复用宽候选集合，不能把短词最终命中列表当成下一次输入的候选缓存。

跨词查询要求每个词都命中，以各词最强字段得分中的最低分乘 0.9 评分，再与完整短语得分比较；不再给任意跨字段命中固定 0.82 分。动态条目的标题、别名、关键词、描述、分类沿用静态字段权重；业务 query 返回无字面匹配的合法候选时，保留既有业务置信度回退，不强制过滤。

个性化偏好由 `Personalization` 提供，在静态前 20 条筛选前生效，并在合并后提升；偏好不能复活未命中、已停用或范围外条目。用户别名先比较最多 128 个声明的匹配质量，再恢复最多 20 个有效结果，失效引用不占有效名额。空文本来源／分类浏览比较整个合法候选集合，避免先按无序遍历截取 200 条后遗漏优先结果；候选键数组仍随目录大小增长，最终结果对象仍只维护前 20 条。模糊候选继续受原数量与时间预算约束，不承诺穷尽召回。

实现证据、前后性能和回归覆盖见 [搜索引擎质量验证](validation/2026-09-11-search-engine-quality.md)。这些是 Host 内部优化，不增加 SDK 字段或 API revision。

## 查询生命周期

静态目录不需要 query。动态 Provider 通过 `query(request,reply,context)` 提供候选，reply 最多成功一次，可以同步调用或延迟调用。返回的取消函数在完成、关闭、换词、超时、禁用或注销时调用，最多一次。Host 等待上限为五秒；这不意味着能抢占正在运行的同步 Lua。

结果统一在 Host 去重、排序、限量并展示。scope 和筛选对静态/动态来源都生效。晚到回复、旧实例句柄、旧条目版本和旧菜单回调无法操作新会话或同 ID 的新注册实例。诊断只保留有界的 Provider ID、错误码和阶段，不保存完整业务 payload 或异常栈。

动态最近使用通过独立 `resolve(entryID,context)` 获取当前条目。没有 resolve 的瞬时查询条目不写入历史；静态目录无需实现 resolve。当前版本不提供异步恢复或流式回复。

QueryOrchestrator 的 operation 身份用于隔离嵌套调用，SearchSession generation 用于会话有效性，两者职责不同。调用外部取消函数前先失效并摘除旧任务；回调若启动新查询，旧调用返回后不得再写入 pending、active 或界面。ProviderRuntime 将完成、非法回复、异常与超时集中收尾；异步终态在相同查询 epoch 下通知界面，既不会让“搜索中”悬空，也不会让旧回复刷新新搜索。取消函数仍最多调用一次，不增加计时驱动或常驻轮询。

## 动作与视图

普通业务通过注册的命名 `run` 回调扩展，不为每种业务新增 action kind。结果只引用回调 ID，不携带闭包。普通回调可返回成功/业务错误、关闭搜索或打开本 Provider 的托管视图。

受保护动作使用 Host 已支持的描述符。目前提供技能施放；必须通过真正的硬件点击，不把普通回调包装成安全脚本。其他受保护类型需独立查档、实现适配器和实机验证后才能加入协议。

拖动与点击相互独立。原生 spell cursor 与 Provider 自有非保护拖动各有声明，没有声明就不注册拖动。菜单可访问全部声明动作；搜索行、最近使用图标和安全覆盖层使用同一执行校验。

ViewHost 提供内容容器并管理 create、Mount(initialState)、Update(state)、Unmount、Dispose。Provider 负责释放自己建立的事件、计时器等活动；可复用 frame，不能让隐藏视图持续工作。

## 内置 Provider

`Builtin/Init.lua` 在登录后注册玩家技能、坐骑、纹章、游戏菜单、首领与宏伟宝库。新增业务调用公开 `RegisterProvider`，不向结果渲染或动作路由增加具体业务分支。API 为 2 / revision 6。

关键词触发归 ProviderPolicy 所有：注册／保存时验证词表，失效后构建有限路由快照；精确命中转为空文本来源查询，复用既有索引和动态查询入口。Index 继续只认识 sourceID/excludedSources 通用条件，不识别模式或 Provider ID。触发词用大小写／首尾空白规范化，与通用模糊搜索的标点处理分离。队伍钥匙使用同一声明，删除独立触发判断和重复查询目录，查询回调仅限频请求刷新。

- `Crests.lua`：一个可搜索条目和一个托管视图；五档当前迷雾纹章首次打开时创建固定行，之后复用。只在显示时注册 `CURRENCY_DISPLAY_UPDATE`，带货币 ID 的事件仅刷新对应行；关闭、禁用、注销均停止事件，读取失败显示“—”并允许重试。
- `GameMenus.lua`：34 条静态菜单记录，每条引用固定开窗函数和本地透明 TGA 图标；支持分页的界面传明确页签，切换式入口先检查已打开状态。冒险指南的六个入口从实际页签控件读取 ID，复用原生 OnClick 路径同步显示与游戏保存的页签；隐藏、禁用或受限页签返回失败。
- `Bosses.lua` 与 `Data/JournalCatalog.lua`：由版本化 DB2 快照生成首领/副本关系，副本名作为每个首领的别名。搜索时不加载手册或扫描游戏 API；点击时延迟加载并检查精确 instanceID / encounterID。
- `Mounts.lua`：缓存已收藏且当前角色可见的坐骑名称与召唤法术 ID，声明已有 `secure-spell` 点击和 `spell` 拖拽。新坐骑事件按 ID 增量更新；不带 ID 的收藏事件合并刷新，未变记录不提交；战斗期间只标记 dirty，脱战恢复。禁用注销事件，重新启用复用同一事件 frame；失败保留旧索引。共享安全策略对技能书之外的法术补充原生坐骑收藏校验，点击和拖拽时重新确认，不信任 Provider 自称可用。
- `GreatVault.lua`：一个静态条目，名称及“低保”等别名命中；调用原生 `WeeklyRewards_ShowUI`，确认 `WeeklyRewardsFrame` 已显示才返回成功。已打开时保持打开，战斗或原生加载失败不关闭搜索窗口。
- `InterfaceActions.lua`：内置模块共用的窄封装，处理原生调用失败、已打开窗口和战斗限制；失败不关闭搜索或写入成功历史。

数据版本、更新命令、离线成本与实机验收范围见 [内置 Provider 验证记录](validation/2026-09-10-builtin-providers.md)。

坐骑与宏伟宝库的来源、生命周期及离线压力测试见 [专项验证记录](validation/2026-09-10-mounts-vault.md)。

当前菜单图标由 `tools/build_flat_menu_icons.cjs` 从扁平图集离线导出，原矢量重建工具保留在 tools 作为历史素材工具，运行时只加载 `Media/MenuIcons/*.tga`。资产自带 5 px 透明安全边距，兼容 Host 现有 7% 裁切；不增加特殊图标协议、运行时绘图或回调。

## 启停、性能和存储

onEnable(handle) 可返回清理函数；禁用/注销调用一次。SDK 还提供可取消的 RegisterReady。Provider 必须在其清理函数中释放自身事件与计时器。Host 单独清理查询任务、时限计时器和视图。

不新增 OnUpdate 或空闲轮询。查询等待时才有 deadline timer，来源变化时才有一次合并刷新 timer。静态目录最多 4096 条，动态回复最多 256 条，最终列表最多 20 条；每条最多 16 个动作。同步业务回调应快速返回，重工作由集成方使用游戏事件或异步完成。

游戏原生 SavedVariablesPerCharacter `LycheeCharacterDB` 保存所有当前角色设置：palette、来源开关、固定、历史、别名、搜索偏好及紧凑成就缓存；统一由 Core/CharacterStore 访问。旧账号面板设置只转移到升级角色一次，原有角色字段优先；账号自动禁用不作为角色默认。固定最多64项。搜索索引、动作payload、回调和Frame不持久化。

`UserPreferences` 管理固定引用和顺序，`SettingsView` 复用来源/固定行。设置页打开时暂停搜索会话并释放安全覆盖层；返回恢复搜索。用户开关与 Provider 自身开关由 Registry 合并为有效启用状态，保留原有启动/停止生命周期。来源关闭不删除固定记录，首页刷新时重新解析当前引用。

设置页按可见窗口复用行，滚动使用绝对记录索引；按下后的绑定身份失效会取消旧点击。技能模块复用事件框并只提交有变化的记录；安全代理仅在待确认施法或待脱战清理时监听事件。规范化缓存限制条数和文本长度，关闭查询释放旧候选。核心动态请求与调度轮次明确处理替换、取消和重入。全模块覆盖、收益与必要代价见 [全项目性能审查](validation/2026-09-10-project-performance.md)。

## 验证

公开 API 测试覆盖原子性、可变输入隔离、实例重用、同 ID 跨 Provider、动态取消/恢复、无动作条目、未知适配器、容量和生命周期。UI 测试覆盖真实 Host 渲染、视图初始/更新状态、菜单与安全右键。WoW API 证据和最终静态验证记录位于 `docs/architecture/`、`docs/validation/`。

离线验证不声称测得真实客户端战斗 CPU、帧时间、taint 或安全点击行为。客户端验收需要记录登录、空闲、战斗、峰值对象量和窗口打开/关闭的实际样本。

## Provider 内部的版本适配层

Host 的产品过滤与 Provider 的实现选择分离：前者控制注册实例可用性，后者允许同一业务在不同 product/interface/build 下采用不同数据源、事件与交互。适配器归 Provider 所有，推荐按 TOC 加载，初始化时唯一选择；共享入口仅提交一个普通 descriptor。Host 不依赖具体适配器或新增游戏业务分支。未选中分支不创建业务资源，稳定 ID／缓存版本隔离／清理遵循 [SDK 版本差异约定](../lychee-sdk/CLIENT_VARIANTS.md)。

## 内部结构维护

### 加载、创建与复用

TOC列出的Lua在加载阶段执行，并非所有代码按需加载。Provider初始化、索引构建和Frame创建是另外三个阶段：
搜索窗口首次打开时创建；具体目录按各Provider既有时序构建，不能以延后业务可用性冒充成本消除。
首领目录保持原加载阶段与完整数据，仅使用连续三字段数组减少每条记录的小表。
启动成本由`tests/performance_loading.lua`单独测量，不能用首次UI框体计数替代代码加载统计。

ViewHost串行处理一次挂载会话；create每次调用，实例缓存归Provider，正常Unmount→Dispose顺序不变。
重入挂载/更新拒绝，回调中请求关闭在回调结束后清理；归属保存在宿主字段中，不从可修改context重新推断。
模板和完整契约见[SDK视图生命周期](../lychee-sdk/VIEW_LIFECYCLE.md)。
Elles的版本敏感访问集中在Adapter，不能据此宣称与上游无耦合；详见
[适配契约](../lychee-sdk/ADAPTER_COMPATIBILITY.md)和[本轮验证](validation/2026-09-11-loading-views-adapters.md)。

内置功能按职责存放在 `package/Lychee/Builtin/<功能>/`，实现与独立语言资源就近维护。客户端支持声明唯一来源是 `tools/client_manifest.json`，生成 TOC 与 `Builtin/Definitions.lua`；启动和注册读取同一声明。共享 CatalogProvider 负责刷新生命周期，功能不得绕过它读取 Host 私有记录或自行协调搜索完成通知。详见 [项目结构与维护入口](PROJECT_STRUCTURE.md)。

revision 6 将普通搜索 searchGlobal 与两个快捷入口词表解耦。ProviderPolicy.Configuration 把旧声明和旧用户 mode 覆盖映射为原有效能力，新用户组合配置优先；Snapshot 负责独立入口路由与冲突归属。UI 只编辑组合配置，不再暴露互斥模式。旧模式中未启用的词表不会自动激活。
