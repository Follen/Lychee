# 全局架构收敛

授权：审计项 1—7 全部实施；移除独立 Lychee Performance Test 插件，保留本体离线性能与行为门禁。

## 成本与生命周期

- 点击绑定：只在绑定、鼠标事件、隐藏、释放时处理。每个有界池目标保留常数个标量；按下不建表、不计时、不轮询。会话、查询代次、Provider 实例和索引版本仍分别校验。
- 页面切换：低频用户操作；准备、成功提交、失败恢复与取消覆盖同一生命周期。失败不清空现有首页/搜索内容，不新建常驻页面池。
- 固定项：每次角色存储或原始表更换时检查一次；正常热读取零复制。最多 64 个活动固定项，字段与总大小有界；异常原始数据保留在原存档字段，活动列表为空并显式报错，拒绝覆盖性写入，不静默丢弃。原始异常存档本身仍占 SV 内存，不能声称这一部分有界或已释放。无后台工作。
- 目录账本：通用目录保留每批 16 条，技能/坐骑保留原子的单次增量；只在成功提交后记账，禁用断开活动工作。业务记录继续使用具名字段。
- 结果生成：只对既有有界命中与解析结果生成快照；不新增目录缓存，不改变搜索集合、顺序、动作或外部隔离。
- 管理状态：Host 统一解释启用状态与实例身份；页面复用其展示记录，不持有原始内部注册表，不建立额外常驻镜像。
- SDK：构建期声明与交付门禁，不新增运行时轮询。独立诊断插件退役不算本体内存优化收益。

## 验收预算

保留 PERFORMANCE.md 全部门槛：2689 条离线目录低于 7168 KiB、48 次查询分配低于 4096 KiB；千 Provider 管理页不超过 10 行、20 次刷新分配低于 512 KiB；温固定项 10000 次读取零可避免分配。交互和结果路径不新增 Frame/活动 timer；不提高门槛让测试通过。

基线：4ac169809691df2d13a540def812321b688de346；本机 Lua 离线固定数据。`performance_memory --check`：保留 6873.6 KiB、48 查询分配 1782.6 KiB、增长 0.1 KiB；`performance_ui --check`：1000 Provider、8 行、356 替身、20 次刷新 37.4 KiB、池增长 0。原始输出 `%TEMP%/lychee-global-before.txt`。单次计时只作记录，不用于声称加速百分比。

## WoW 版本证据

sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`；source check 无更新。

- `Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua:805-828`：`SecureActionButton_OnClick` 根据 down/useOnKeyDown 决定原生执行；保留安全模板原生 OnClick，仅在非战斗 PreClick 拒绝过期绑定。
- `Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml:4-8`：SecureActionButtonTemplate 继承 SecureFrameTemplate，并绑定原生 OnClick。
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseWoWTokenFrame.lua:413-418`：OnMouseDown 检查 IsEnabled 后处理按下；交互身份通过事件管理。

游戏内鼠标事件顺序、战斗/taint、页面实际显示及新 TOC 加载需重启客户端验收。离线替身不是这些场景的通过证据。

## 模块职责与兼容性

- InteractionBinding 是内部鼠标按下身份所有者：绑定、按下、消费、隐藏/释放失效。键盘提交直接经过原 Executor，不伪造鼠标按下。安全按钮仍使用原生安全模板；非战斗的过期 PreClick 走统一 Release。
- Palette 的 OpenView 在外部 create/Mount 成功前保留首页/搜索展示，失败恢复输入焦点；回调中关闭、换查询或进设置会取消提交。旧自定义实例已由 ViewHost Dispose 的情况下，失败恢复当前首页/搜索，不复活已经释放的自定义页。Mount 返回 false 的旧合同不变（只有抛错表示挂载失败）。
- CatalogLedger 统一已提交账本和失败/取消记账；CatalogProvider、Mounts、PlayerSpells 保留业务枚举与批次策略。这是内置私有职责；第三方仍使用公开 handle:Update，不新增公共方法。
- ResultSnapshot 只生成展示字段。Query 与 ProviderRuntime 都调用它，Provider 身份由 ProviderRuntime 各盖一次；不依赖 Query 恢复固定项，不合并不同来源的代数。
- ProviderManagement 统一有效/用户/所有者状态及实例校验，管理页面只持有轻量展示记录和实例编号；重注册编号变化，写入前后校验，防止回调重入。不是第三方管理员权限。
- 固定项字段 providerID/entryID/sourceID 各至多 1024 字节，title/sourceTitle 各 4096 字节，icon 为有效非负整数或至多 1024 字节路径；总逻辑字节 65536（表/字段基础各 16，加字符串字节），最多 64 条。未知字段、空洞、重复引用、metatable、坏类型被拒。正常写入和恢复同一约束；恢复/撤销保留条目对象身份。

## 独立诊断插件退役

按用户要求移除 tools/performance-test 的 13 个专用文件及本地生成的插件/ZIP；正式服删除目标仅为 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee Performance Test`。不删除 Lychee 本体、Lychee Dev、历史 SavedVariables 或已落盘的测量证据。旧历史文档中的命令用于说明当时测量步骤，不再是当前可执行入口；原工具可在 Git 基线 4ac1698 查询。

本体 tests/performance_*、performance_memory、perf_* 与完整契约门禁保留；退役诊断插件不用于宣称本体内存下降。生成目录中的历史测试输出保留，START.txt 和旧插件交付 manifest 随旧插件退役，避免继续引导执行失效命令。

补充同一 source/product/ref/commit 的 API 证据：

- Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:408–419：HasFocus 返回 hasFocus bool，QueryFocus 受限检查；仅查询自有输入框。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua:45–51：InCombatLockdown 返回 bool。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua:273：GetMountInfoByID 标注 MayReturnNothing，保留名称、spellID、icon、隐藏与收集标志读取。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:270：GetSpellBookItemInfo 标注 MayReturnNothing，保留 slot index / spell bank 参数与客户端适配。