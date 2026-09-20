# Builtin / Secure 全目录性能审查

基线 `4e12531`；2026-09-10，Lua 5.1 Windows 离线模拟，200 个技能，真实 Builtin PlayerSpells 模块、固定 API 替身和记录提交计数。不是游戏 CPU/帧时间或真实索引内存。遵循根目录 PERFORMANCE.md。

## 已实现

- 玩家技能只在 Provider 启用时扫描；移除注册前扫描及重复建记录。
- 事件框首次启用创建，停用注销所有事件、清空 OnEvent 和活动引用，保留一个可复用框；反复启停不新增永久 WoW Frame。
- 延迟刷新带生命周期代次，旧回调不清除新任务状态、不扫描；同一启用期突发事件仅一个有效任务。
- 不属于本模块请求的 SPELL_DATA_LOAD_RESULT 立即返回。战斗期间仅保留 dirty，PLAYER_REGEN_ENABLED 恢复一次，无新增 ticker/OnUpdate。
- 技能快照比较 name/icon/subtext/description/aliases，未变化不提交；变化只 upsert 变化技能、remove 消失技能。提交失败恢复旧快照，后续可重试。
- 注销释放技能快照与 Provider handle；停用清空描述请求表。重新启用重新读取最新技能，保留原有 flyout、隐藏技能行、已知别名技能收录。
- 安全代理首次创建仅保留一个必要共享事件框，不注册任何事件；物理点击 PreClick 后注册三个 player 施法事件，成功/失败/释放后注销；dirty 时注册脱战事件，Flush 完成注销。事件兴趣有变化检查，不影响安全属性或原有施法/坐骑执行路径。

## 事前预算与实际结果

预算：禁用初始化扫描 0；一次启用最多一个事件框；同一生命周期最多一个有效刷新；旧回调扫描 0；无关数据加载事件扫描 0；无变化源提交 0；单条变化只提交 1 条。初始基线先运行 `--baseline`，随后原代码运行断言版本在 `disabled provider must not scan` 失败。

| 同输入场景 | 基线 | 修改后 |
| --- | ---: | ---: |
| 禁用状态初始化扫描 | 1 | 0 |
| 20 次无变化刷新源提交 | 20 | 0 |
| 一个无关数据加载事件扫描 | 1 | 0 |
| 旧延迟回调跨禁用/重启后扫描 | 1 | 0 |
| 22 次启用后的永久事件框数 | 22 | 1 |
| 100 次无变化刷新累计分配 | 37353.8 KiB | 9172.6 KiB |
| 同序列回收后保留增长 | 0.0 KiB | 0.0 KiB |
| 三轮 CPU ms（交替测量） | 67 / 65 / 67 | 35 / 31 / 31 |
| CPU 中位数 / 最大 | 67 / 67 ms | 31 / 35 ms |
| 安全代理空闲事件订阅 | 4 | 0 |
| 空闲投递 300 个玩家施法事件后的回调 | 300 | 0 |

计时总量为 100 次刷新，不是单次耗时；Lua os.clock 分辨率有限。最终三轮前后交替测量原始输出在 `docs/archive/design/2026-09-10-project-perf-builtin-results.json`。环境扰动使 CPU 数字只具方向意义。累计分配在受控 GC stop 测量，结束恢复；不代表峰值或游戏插件内存。启动与真实单批峰值待游戏测量。

## 所有权与覆盖

| 文件 | 审查结论 |
| --- | --- |
| Builtin/Init.lua | 一次 Init，无驱动、无额外数据副本；不改。 |
| Builtin/PlayerSpells/Init.lua / Provider.lua | 上述修复；技能快照最多当前技能目录，描述请求由此目录产生、停用清空；源记录由 Provider 持有。 |
| Builtin/Data/PlayerSpellAliases.lua | 构建期有限别名表；不改。 |
| Builtin/Data/JournalCatalog.lua | 构建期有限首领目录，无事件/框架；用于重注册保留。 |
| Builtin/Bosses.lua | 注册时生成一次记录，不创建真实指南或搜索页面；1154 记录固定全集；不改。 |
| Builtin/GameMenus.lua | 固定菜单定义和闭包，仅点击执行 UI API；无轮询，不改。 |
| Builtin/GreatVault.lua | 固定单记录，点击按需打开；无背景采集，不改。 |
| Builtin/InterfaceActions.lua | 操作时小范围 pcall 与真实页面成功验证；不改。 |
| Builtin/Crests.lua | 首次打开创建面板、五行复用，隐藏/停用去事件，相关货币增量刷新与 setter guard；不改。 |
| Builtin/Mounts.lua | epoch 防迟到、战斗暂停、事件合并、成功后提交轻量快照、增量更新、无常驻轮询。全量刷新仍读取完整坐骑目录并产生临时记录，作为后续有测量优化候选，不宣称零分配。 |
| Secure/Descriptor.lua | 固定动作边界校验，小描述符只在动作准备创建，不改。 |
| Secure/Policy.lua | 必要的实时可用性/收藏验证，避免缓存改变安全与战斗语义；不改。 |
| Secure/SecureActionBroker.lua | 有界于已准备目标高水位的复用按钮、幂等 Release、active swap-remove、战斗延迟释放；本轮将四个常驻事件改为按 pending/dirty 监听。同目标 ShowFor 仍重写锚点，未以无数据重构安全布局路径。 |
| Media（只读覆盖） | 1 PNG 共 77752 bytes、38 TGA 共 609918 bytes、一个资源说明 TXT 213 bytes；内置菜单只保存路径，实际设置纹理在显示 UI 时发生，无运行时转换或动态创建媒体。保留所有资源，未改共享媒体/TOC。磁盘字节不等于纹理显存；纹理实际尺寸/显存待客户端验证。 |

## 版本证据

`source check` 确认 local/remote 一致。以下均 sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`，matchedTag=null。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:941`：`Requests data for the spell be loaded; Listen for SPELL_DATA_LOAD_RESULT to be notified when load is finished`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:11`：`After` 参数 seconds:number / callback:TimerCallback。不可取消的 After 使用代次失效。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1586`：`UnregisterAllEvents`，用于停用时释放事件。
- 精确技能书 API、事件及框架证据见 `docs/archive/design/2026-09-10-project-perf-builtin-api.json`；计时器、异步结果证据见同前缀 timer / spell-load JSON。
- `RegisterUnitEvent` / `UnregisterEvent` / 玩家施法与脱战事件版本证据见 `docs/archive/design/2026-09-10-project-perf-builtin-secure-events.json`。

## 验证

- `lua tests/performance_builtin_secure.lua` PASS：生命周期计数、单项变更/删除、提交失败保留与重试、战斗暂停恢复、启停 40 次复用、停用无事件。
- `lua tests/perf_builtin_secure_events.lua` PASS：空闲零事件、准备按钮不监听、PreClick 才监听、无关施法不误结束、失败/成功注销、战斗释放后脱战恢复注销；基线默认断言在 idle broker must have zero event subscriptions/callbacks 失败。
- 旧版通过 `LYCHEE_PERF_SOURCE=analyze/project-performance-2026-09-10/baseline/package/Lychee` 执行同一测试；`--baseline` 输出计数，默认断言失败，确认测试能抓原问题。
- `lua tests/smoke.lua` PASS，保留停用后 `_eventFrame=nil` 既有契约。
- `lua tests/builtin_providers_smoke.lua` PASS：1154 首领，离线初始化 104 ms / 3815.6 KiB；非本轮前后对比。
- `lua tests/mounts_vault_smoke.lua` PASS：1500 坐骑，初始化 110 ms / 3480.1 KiB；非本轮前后对比。
- `lua tests/interaction_smoke.lua` PASS：安全动作、战斗、Provider view、菜单、最近使用、滚动、设置固定项；56 个框架延迟到首次打开、已释放按钮重复属性写入 0。
- 三个修改 Lua 文件 `luac -p` PASS；`git diff --check` PASS（仅 Windows 换行提示）。整体 wowdoc validate/完整契约由主 Agent 集成执行。

游戏内登录、空闲、单/多目标战斗、姓名板峰值、配置开关的 CPU/内存/帧时间/taint 仍待实测。技能目录全扫仍为真实技能变化的同步工作，本轮消除了重复提交与无关触发，没有宣称已实现分批扫描。回滚通过新 git revert，由主 Agent 提交后同步。
