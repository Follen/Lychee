## 当前构建：0.3.0-character-storage

当前副本包含角色存储模块，共 56 个产品模块、59 个 Lua 文件、60 个交付文件。构建自动记录真实 `sourceCommit`、运行时目录 `sourceDirty` 和 `sourceTreeHash`，不再沿用固定提交号。私有轮次按角色清理/保留成就缓存；真实产品仍只做只读采样。以下 0.2.2 基准与历史报告保留作为修改前证据，不能当作本轮实机验证。

# Lychee Performance Test

独立、手动启动的诊断插件，调查 Lychee 生命周期与内存/CPU；不实施产品 SDK 或低内存重构。目录、TOC、Title 均为 `Lychee Performance Test`。仅依赖 `Lychee`，不依赖 Lychee Dev；原长文本粘贴入口已撤回。

当前修订 `0.2.2-baseline-gate`。整轮墙钟上限按用户要求从 180 秒延长到 600 秒，报告记录 `wallLimitSeconds=600`；这是诊断等待上限，不改变产品性能预算。开始/结束聊天和报告 `carrierRevision` 显示修订，中央大字显示运行状态。覆盖修复：显式启动后正常初始化 Ellesmere 设置、打开一个现有/默认模块页面、记录真实选项登记并关闭，再测 SDK 选项查询/Resolve；不再仅测试未就绪状态。旧报告仍保留。

## 构建与安装

仓库根目录运行 `python tools/performance-test/build.py`，得到：

- `analyze/performance-test-package/Lychee Performance Test/`：60 个安装文件。
- 同目录的 `Lychee Performance Test.zip`、`manifest.json`、`START.txt`。
- 56 个模块工厂来自当前生产 TOC 的非 UI/安全层源码，原文嵌入普通 Lua 函数，使用正常文件编译；没有 source-string/loadstring 编译器。源码逐文件 SHA256 记录在 manifest 中。

目标安装目录为 `D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee Performance Test`。已获独立诊断目录安装及后续修复同步授权。0.2 延续原 TOC 文件清单，将准备 helper 在构建期合入 Engine.lua；安装后由用户 `/reload` 清掉旧会话代码，再用下面同一入口加载。不凭旧进程启动时间断言新增插件无法识别；以实际 LoadAddOn 返回为准。不会自动退出、重启或清理存档。

TOC 使用 LoadOnDemand，默认不加载；加载时只建立模块工厂和入口，不执行测试、不初始化 Provider、不创建诊断 UI、不注册活动事件或计时器。编译后的工厂代码会保留到客户端重载，不能声称已经卸载。安装包大小不代表 Lua 常驻大小。

## 一次启动、一份报告

在非战斗、安全站立、关闭 Lychee 面板时输入：

```text
/run local t=debugprofilestop();local ok,e=C_AddOns.LoadAddOn("Lychee Performance Test");if ok then LycheePerformanceTest.Start(debugprofilestop()-t) else print(e) end
```

该入口为 167 个 ASCII 字节；不需要 Lychee Dev、剪贴板源代码或编辑器。此命令加载插件并开始测试，加载的毫秒单列为 `nativeLoadMs`；再次启动不能当成首次原生加载。0.2.1 的实际报告 `LYCHEE-PERF-1789202681` 在 68.402 秒完成四轮、EUI 选项和三次 UI 开关，但钥石四轮均报 ColorMixin，不能作为全部通过的基准。

启动后屏幕中央以透明底、42 号红色描边大字显示“正在执行中…”。流程完成后显示“执行完毕，可落盘”，下方提示 `/reload`；取消或中止分别显示实际结果，部分来源异常在副标题注明。提示一直保留至重载，点击穿透，不捕获键盘；仅状态变化更新，复用 1 Frame + 2 FontString，无额外 timer/OnUpdate。它在基线前创建，成本计入诊断插件，不能混入产品收益。

加载后 `/lypt` 查看状态，`/lypt cancel` 取消；同会话再次运行可用 `/lypt start`，但 `/reload` 后应先用 LoadAddOn 入口。不要在测试时点击业务动作。自动测试会先打开并关闭 Ellesmere 常规设置，再在条件允许时开关 Lychee 面板三次。已有窗口、override 编辑或初始化待完成时给出具体跳过原因。

结束在聊天打印 `complete`、`cancelled` 或 `aborted` 与 `LYCHEE-PERF-...` ID。只有 `complete` 表示协调流程完成，仍须检查每个来源的 availability/error/coverage；缺依赖不算覆盖成功。结束后 `/reload` 一次，报告通过游戏 SavedVariables 正常落盘：

```text
WTF/Account/<account>/SavedVariables/Lychee Performance Test.lua
LycheePerformanceTestDB.reports["LYCHEE-PERF-..."]
```

0.2.2 新增独立 `baseline.status=passed|incomplete` 与有限失败清单。覆盖三轮采集、四轮全部 15 个来源的无错误注册、钥石实际记录/搜索、全部查询、EUI 真实选项、EX Resolve、取消、等价、分阶段内存、最终清理、角色状态与三次真实面板显示。副标题只有通过这套检查才显示“本轮基准全部通过”；这仍不是未执行的战斗/硬件按键/全页面业务验收。离线读盘检查入口：`lua tools/performance-test/check-baseline.lua <SavedVariables路径> [报告ID]`，缺项返回非零退出码。

不需要再复制结果或执行导出脚本。报告包含 client/build、基线源码提交、阶段时间、逐来源状态、查询对照、内存及清理结果；不会存整份业务目录。最多保留 8 份，达到上限拒绝新运行，不自动删除。上次运行在退出时仍为 running，下次访问入口标记 interrupted，不能假称清理成功。保留旧报告直到新报告产生。

## 场景与边界

- 三轮真实坐骑 API 采集与临时记录构造分别计时，最多 10,000 ID；每批最多 32 项、协作式 4ms 目标。此阶段会预热坐骑 API，后面的 Provider 不能称为游戏缓存冷启动。
- 四轮私有生产 Provider/SDK/index 构建；前三轮不做详细热点插桩，第 3 轮保留私有成就缓存；第 4 轮单列 SDK、校验、索引、game getters 的独占归因。
- 11 类静态/动态查询、24 次热查、Resolve、取消后的迟到回复、索引单独重建、注销/再激活；比较条数、字段、顺序与动作描述哈希。动态数据可能随游戏事件变化，差异需要读报告解释。
- Ellesmere 经正常 EnsureLoaded 初始化设置，在另一个执行片段调用 ShowModule。临时包装真实 `_RegisterSearchEntry`，原函数照常执行，使用生产 Capture 逻辑收集真实选项；成功、错误、取消均还原，发生外部替换时不覆盖第三方新函数，并使自己的观察器立即失效。不安装新的永久诊断 hook、不调用 setter/安装器/重置/动作，不触发会调用 selector setter 的 GlobalSearch 预构建。
- 记录 `ellesmerePreparation` 的 loadedBefore/After（设置初始化标志）、core/options 原生加载状态、初始化同步耗时、可见/关闭状态、实际模块/页面及新采集/可用选项数量。每轮 `ellesmereOptionCheck.status=verified` 才表示真实选项查询并 Resolve 成功；一条 status 结果或 registered=true 不算。Exwind 继续读取真实已有模块/静态布局。
- 正常设置初始化会保留上游加载代码、原生 UI、上游自身初始化/回调及已有 Lychee 被动捕获数据；Hide 不是卸载，也不承诺完全恢复未打开前内存。只覆盖实际正常访问页面与已有元数据，未访问的变体/全部设置不伪称覆盖。准备阶段在四轮私有构建前，后续数据是上游预热条件。
- 钥匙通信与刷新、技能描述下载被抑制，只测当前游戏缓存。暴雪设置只读已存在的分类/布局。Inspector 不运行真实拾取，Crests 不打开自定义页。
- 0.2.2 先对三个真实原生颜色接口做原环境、继承隔离环境、显式 mixin、原环境桥接的同参数对照，保存 `nativeCalls.samples`；桥接结果须与原环境 RGB 一致，否则提前中止。仅对私有命名空间的三个 getter 使用真实环境调用桥接，保持多返回值/nil，不复制或硬编码颜色，不修改实际全局命名空间。错误保留 API 名、有限错误文本与可用调用栈。离线测试只模拟原生 raw lookup 行为，不能冒充游戏引擎根因已证实；须读取新的实机对照。
- 实际 Lychee 控制器三次开关、快速重开、alpha/几何/行池检查单列；原生 UI 的视觉质量、硬件快捷键、所有页高水位、战斗和真实首次登录不在自动等价声明内。

外层计时器逐阶段推进，600 秒墙钟上限，取消/战斗/错误会停止调度、注销私有来源并断开临时环境。单个生产同步函数或原生 API 无法被 Lua 时间预算抢占；报告 `maxCallMs` 和 `maxResumeMs`，不承诺测试完全无停顿。私有计时器队列上限 8,000、单次 drain 6,000 步；指纹深度 14、节点 300,000，Ellesmere 重放最多 4,096 条。

## 内存与诊断成本

`memory` 分别记录全客户端 GC 前后、全局 GC 毫秒、内存统计刷新毫秒、Lychee 与诊断插件各自的 AddOn counter。诊断插件包含私有实例，不能把它的内存移走后声称 Lychee 达到 1 MiB。私有堆差含诊断及后台噪声；原生 Frame/纹理成本未被 Lua 堆穷尽。完整 GC 是用户启动的一次诊断干预，不是产品关闭策略。

`phases.activeMs` 为受测调用，`maxResumeMs` 包括诊断哈希、采样、GC 等；总墙钟还包含等待。第 4 轮插桩数字不能当成正常时延或与前三轮直接相减估算优化收益。加载/代码初始化、数据/API、SDK/index、查询、释放、UI 分开解释。观测高水位在同步调用结束时采样，不是精确峰值，也不是累计分配；本次实机流程不暂停 GC，累计分配仍由独立离线实验提供有限证据。

0.2.2 的 `scheduler` 记录请求等待总量、实际唤醒等待总量、最大超期、唤醒次数和协程执行合计。后者包含诊断本身，不是产品独占 CPU；失败/取消可能留下未执行请求的等待预算，不用请求总量当实际耗时。颜色前置对照、三处 getter 桥接、最终覆盖检查和中央提示均是诊断新增成本，不用于宣称生产性能收益。

诊断源文件在 `tools/performance-test`；生产 `package/Lychee` 与 SDK 不改变。完成取证后可禁用诊断插件并重载；如需删除安装目录或报告，另行定向确认，不自动清理。

## 验证

`python tools/performance-test/build.py` → `lua tools/performance-test/test.lua` → `wowdoc validate --path "analyze/performance-test-package/Lychee Performance Test" --source wow-ui-source --product retail --ref latest`。

离线覆盖真实 TOC 文件加载入口、无自动启动/无 Dev、正常四轮、真实接口替身上的 EUI/Exwind 查询与解析、业务对照、早/中途取消、缺依赖、重入、战斗中止、超时、调度失败、模块初始化错误及之后恢复、工厂环境还原、UI 顺序、独立报告序列化/重读、跨会话 interrupted 恢复。离线替身不能证明真实客户端计时、taint、渲染或新增插件发现路径。

0.2 专项新增：真实登记形态 → 私有 SDK 选项查询/Resolve、初始化与可见打开/关闭、加载/打开错误、加载不完整、初始化后/可见期间取消、原登记函数恢复。初始化与 Show 分两次执行，避免创建无法取消的上游 `_SplitFirstOpen` 延迟 Show 回调。60 安装文件/59 Lua 不变。

Ellesmere 版本依据：wowdoc `sourceId=ellesmereui, product=main, requestedRef=latest, resolvedCommit=271ffc30d3265d9f77746b0e15224d918f0fafcb`，source check 本地/远端一致；安装版本 9.1.8。安装源 `EllesmereUI.lua:5472` 初始 `_deferredLoaded=false`；:5565 `EnsureLoaded` 调用 EnsureOptionsLoaded 后设 true 并执行延迟初始化；:10726 `_SplitFirstOpen` 延迟重入 Show；:10738/:10746/:10762/:10766 为 Show/Hide/IsShown/GetMainFrame；:11305 ShowModule 非战斗选择常规页面。`:10700` 的首次提示已读标记仅在 Okay 点击中写入，测试不点击。`EllesmereUI_GlobalSearch.lua:651` 的预构建会调用 selector/restore setter，明确排除。生产 Lychee Adapter 的只读替身仍用于四轮查询，准备阶段才进入正常上游入口。

版本证据：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`（12.1.0）：

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:347`：LoadAddOn 接收 name，返回 loaded/value。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39`：NewTimer 接收 seconds/callback，返回 cbObject。
- `Interface/AddOns/Blizzard_ChatFrame/Shared/ClassTalentHelper.lua:57`：`SlashCmdList["TALENT_LOADOUT_BY_NAME"] = function(msg)`，原生 slash 注册形态。
- 同版本 SettingsPanel.lua:737、FrameScriptDocumentation.lua:509、MountJournalDocumentation.lua:273 的读取/计时证据见统一调查记录。

0.2.1 验证依据：同上 wow-ui-source/retail/latest、resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`，`FrameScriptDocumentation.lua:509` 的 debugprofilestop 返回 elapsedMilliseconds；超时显式秒转毫秒。状态 UI 精确 API 查询证据保存在本机 `analyze/performance-test-package/status-api-evidence.json`，对应官方 SimpleFrame/SimpleFont 文档的 CreateFontString、SetFrameStrata、EnableMouse、SetFont、SetTextColor。用户允许将诊断墙钟上限延长至 600 秒，单批/队列/取消与产品性能预算保持原值；旧 180 秒报告继续保留为历史。

0.2.2 颜色证据同 source/product/ref/commit：`Interface/AddOns/Blizzard_APIDocumentationGenerated/ClassColorDocumentation.lua:11` 的 GetClassColor 在 :23 返回 `Mixin="ColorMixin"`；`ChallengeModeInfoDocumentation.lua:92` 的 GetDungeonScoreRarityColor 在 :104 返回同 mixin；该文件 :239 的 GetSpecificDungeonScoreRarityColor 在 :251 返回同 mixin。它们证明返回对象契约，不公开引擎如何查找 mixin。`Interface/AddOns/Blizzard_ScriptErrors/Blizzard_ScriptErrors.lua:59` 调用 `debugstack(debugStackLevel)`；仅在诊断失败时采集并截断到 2400 字符，最多 16 条。精确查询保存在 `analyze/performance-test-package/color-api-evidence.json`。
