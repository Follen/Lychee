> 本文保留当时的测量流程。独立 Lychee Performance Test 及其工具已于本轮全局收敛中退役，旧启动命令不再可用。

# 一次启动的统一实机调查

**长文本粘贴交付已撤回。禁止再次将 `runtime-unified-study.lua` 粘贴到游戏编辑框。** 用户反馈 468817 字节输入在粘贴阶段导致程序无响应，尚未点击运行；没有证据证明探针执行或进程崩溃退出。本页原交付说明保留作事故记录，不再是有效运行指引。后续已获授权改为独立诊断载体与短入口并完成多轮实机取证，实际覆盖见 [实机结果](RUNTIME_RESULTS.md)。

本轮仅生成证据与可行性方案。正式实现必须另建分支；不改动生产运行时、SDK 版本或真实用户存档。

## 已撤回的历史交付（禁止执行）

最终输入文件位于本机忽略目录 `analyze/runtime-unified-study.lua`，由 `analyze/build-unified-study.py` 将当前版本 56 个非 UI/安全执行层文件与 `analyze/unified-study-body.lua` 组合生成。当前交付 SHA256：`88B339140A84A8B603DA7EB9151CDAD6CA90F878C7150887A3D918A7AE26F552`。

旧方案曾要求在 Lychee Dev 运行页粘贴、启动一次；用户在粘贴时无响应，未点击执行，这条路径已停用。以下是原方案的设计记录，不是有效启动指引。

报告位于 `LycheeDevDB.lycheeLifecycleStudies[studyID]`，schema=`lychee.lifecycle-study.v1`。这是独立诊断 ID，**不是标准导出 Ticket**。最多保留 8 份，达到上限停止而不删除旧记录。运行过程中只额外保留临时 `LycheeStudyControl` 控制对象，结束后清除；可以通过其 Cancel 方法中止。

## 独立插件接替

用户随后明确要求独立 **Lychee Performance Test**。源码、构建/验证、安装、取消及独立报告说明见 [诊断插件退役说明](../../design/2026-09-12-global-refinement.md#独立诊断插件退役)。正常 TOC 承载 56 个模块工厂，独立 SavedVariables，完全不依赖 Lychee Dev。167 字节短入口替代 468817 字节源文件输入。最新安装版为 0.2.2-baseline-gate，`LYCHEE-PERF-1789203670` 同一报告全部基准通过；旧版本的部分完成与超时记录仍保留。通过范围不包含候选 SDK 3/休眠、全部页面、战斗与硬件动作。

下表的大部分场景由独立插件继续执行；加载阶段已改为原生 TOC 编译与私有模块初始化分别记账，另增加三轮分批真实坐骑采集/构造。当前正式入口以新 README 为准。

## 场景矩阵

| 场景 | 一次运行中的覆盖 | 明确边界 |
| --- | --- | --- |
| 加载 | 独立包正常 TOC 编译，随后执行 56 个私有模块工厂；两阶段分别计时 | 已验证原生 LoadAddOn 入口；不是冷客户端整体产品首开，不含私有 UI 实现 |
| 业务读取 | 按实际声明逐项初始化 15 个内置来源，记录依赖、失败、条数与耗时 | 未收集坐骑仍由真实 API 枚举；不清除游戏内部缓存 |
| 静态目录 | 两轮新私有缓存、一次私有存档缓存恢复、一轮独立插桩归因 | 私有第 3 轮恢复不代表新架构的真实休眠；目前还没有该架构 |
| SDK | 真实公开 RegisterProvider/Update/动态 reply/Resolve/取消与注销 | 接入实现仍使用内部 Locale/Normalizer/Support，不能充作完全独立 SDK conformance 证明 |
| Ellesmere UI | 0.2 正常初始化并访问一页，临时观察真实登记，关闭/还原后测 `eui:`、`eui:冷却` 及具体选项 Resolve | 仅实际页面/已有元数据，不执行 setter 或搜索预构建；0.1 未初始化，只覆盖状态提示 |
| Exwind | `ex:` 与 `ex:冷却`，读取实际模块、静态布局和路由声明 | 不执行布局函数、路由、解锁或设置动作 |
| 搜索 | 完整异步首查、静态与动态热查、记录/排序/动作描述及载荷哈希比较 | 不执行真实动作；不验证每一种语言与硬件安全调用 |
| 生命周期 | 活动数据注销/查询取消、旧回复不再发布、再激活及重建 | 实现代码和假 Frame 池保留；不假装插件可卸载 |
| 内存 | 全局 GC 前后、Lychee API 统计、私有代码/活动数据/释放及最终清私有缓存对照 | GC 是全客户端停顿；私有堆差含诊断与背景噪声；不是按插件精确分配器数据 |
| 峰值 | 每个受测同步调用结束后的堆高水位 | 是观测下界，不是中途精确峰值或累计分配 |
| 真实 UI | 条件允许时 3 次真实面板开关、快速重开、几何、alpha、行池、关闭恢复 | 不用假 Frame 冒充此阶段；若已有面板/识别器活动则跳过；不是 Alt+Space/Esc 硬件路径 |
| 不变量 | 真实插件、索引、Provider 表和用户 DB 根引用，角色状态哈希 | 背景游戏事件可能自然改变数据；不把观测变化直接归因为探针写入 |

队伍钥匙来源的通信、前缀注册和请求刷新被阻止，只能读取现有 API 缓存，不能获得新的队友回复。缺失技能描述的下载也被阻止；涉及这些差异的结果必须视为有条件样本。暴雪设置只读取已存在的分类和布局，`SettingsPanelMixin:GetLayout` 为返回 `categoryLayouts[category]` 的读取接口。

`rounds[*].providers` 和 `coverage` 是逐来源覆盖依据；不能因为流程 status=complete 就声称所有依赖、所有页面和业务动作已经验证。

## 计时解释

- `phases` 的 activeMs/maxCallMs 统计受测同步调用，包含加载或真实 UI 时应按阶段区分。
- `maxResumeMs` 是整个诊断协程一次运行的最大跨度，包含比较、GC 等诊断开销，不等于产品独占 CPU。
- 查询 wallMs 包含私有队列的调度等待。warm24WallMs 还包括诊断比较开销；热路径取舍优先看 warm24ActiveMs 与对应调用样本，不能把该墙钟当成产品响应时间。
- 第 4 轮 profile 的 SDK/校验/索引/游戏 getter 独占时间用于定位热点；其大量包装与计时开销不与前三轮正常时延混为一谈。
- 私有来源逐一初始化，耗时不能宣称就是当前真实登录的并发时序。清理仍留私有成就存档时会显式标记；最终另清全部私有数据缓存再采样。

## 本地验证

Lua 5.1 语法及完整流程检查通过：四轮构建、Ellesmere/Exwind 动态结果与 resolve、记录和查询顺序对照、取消后无迟到回复、开始前与中途取消、依赖缺失、超时、计时器创建失败、UI 调用顺序与关闭恢复。隔离检查确认没有真实 Frame 创建、外部业务动作、原 API 函数替换或真实运行时根替换。UI 顺序的本地替身测试不是游戏视觉验收。

本地命令：`python analyze/build-unified-study.py`，`luac -p analyze/runtime-unified-study.lua`，`lua analyze/test-unified-study.lua`。原生成文件和测试保留在本机；正式实机结果尚待本轮用户运行与落盘，不以本地 PASS 替代实机。

## WoW 版本证据

sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:737`：`SettingsPanelMixin:GetLayout(category)` 返回 `self.categoryLayouts[category]`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39`：`C_Timer.NewTimer(seconds, callback)` 返回 `cbObject`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:509`：`debugprofilestop` 返回毫秒；探针只做差，不重置全局 profiler。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua:273`：`GetMountInfoByID` 返回 hidden/collected 等字段；第一份已落盘采集证据验证了实际枚举与返回数量。

报告存储使用用户明确授权的独立诊断字段，不调用或伪造 Lychee Dev 私有 ns 的导出 API。
