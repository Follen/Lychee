# Lychee Performance Test

独立、手动启动的诊断插件，调查 Lychee 生命周期与内存/CPU；不实施产品 SDK 或低内存重构。目录、TOC、Title 均为 `Lychee Performance Test`。仅依赖 `Lychee`，不依赖 Lychee Dev；原长文本粘贴入口已撤回。

## 构建与安装

仓库根目录运行 `python tools/performance-test/build.py`，得到：

- `analyze/performance-test-package/Lychee Performance Test/`：60 个安装文件。
- 同目录的 `Lychee Performance Test.zip`、`manifest.json`、`START.txt`。
- 56 个模块工厂来自当前生产 TOC 的非 UI/安全层源码，原文嵌入普通 Lua 函数，使用正常文件编译；没有 source-string/loadstring 编译器。源码逐文件 SHA256 记录在 manifest 中。

目标安装目录为 `D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee Performance Test`。当前仅准备安装包，未安装。新增插件后需由用户重启客户端；不自动退出、重启或清理存档。该目录与生产 Lychee 分开，不能覆盖到 Lychee 目录内。

TOC 使用 LoadOnDemand，默认不加载；加载时只建立模块工厂和入口，不执行测试、不初始化 Provider、不创建诊断 UI、不注册活动事件或计时器。编译后的工厂代码会保留到客户端重载，不能声称已经卸载。安装包大小不代表 Lua 常驻大小。

## 一次启动、一份报告

在非战斗、安全站立、关闭 Lychee 面板时输入：

```text
/run local t=debugprofilestop();local ok,e=C_AddOns.LoadAddOn("Lychee Performance Test");if ok then LycheePerformanceTest.Start(debugprofilestop()-t) else print(e) end
```

该入口为 167 个 ASCII 字节；不需要 Lychee Dev、剪贴板源代码或编辑器。此命令加载插件并开始测试，加载的毫秒单列为 `nativeLoadMs`；再次启动不能当成首次原生加载。该命令的真实客户端运行仍待安装后验证。

加载后 `/lypt` 查看状态，`/lypt cancel` 取消；需要重新运行时用 `/lypt start`。若已有面板/识别器工作，真实 UI 阶段会跳过；不要在测试时点击业务动作。自动测试会在条件允许时开关面板三次。

结束在聊天打印 `complete`、`cancelled` 或 `aborted` 与 `LYCHEE-PERF-...` ID。只有 `complete` 表示协调流程完成，仍须检查每个来源的 availability/error/coverage；缺依赖不算覆盖成功。结束后 `/reload` 一次，报告通过游戏 SavedVariables 正常落盘：

```text
WTF/Account/<account>/SavedVariables/Lychee Performance Test.lua
LycheePerformanceTestDB.reports["LYCHEE-PERF-..."]
```

不需要再复制结果或执行导出脚本。报告包含 client/build、基线源码提交、阶段时间、逐来源状态、查询对照、内存及清理结果；不会存整份业务目录。最多保留 8 份，达到上限拒绝新运行，不自动删除。上次运行在退出时仍为 running，下次访问入口标记 interrupted，不能假称清理成功。保留旧报告直到新报告产生。

## 场景与边界

- 三轮真实坐骑 API 采集与临时记录构造分别计时，最多 10,000 ID；每批最多 32 项、协作式 4ms 目标。此阶段会预热坐骑 API，后面的 Provider 不能称为游戏缓存冷启动。
- 四轮私有生产 Provider/SDK/index 构建；前三轮不做详细热点插桩，第 3 轮保留私有成就缓存；第 4 轮单列 SDK、校验、索引、game getters 的独占归因。
- 11 类静态/动态查询、24 次热查、Resolve、取消后的迟到回复、索引单独重建、注销/再激活；比较条数、字段、顺序与动作描述哈希。动态数据可能随游戏事件变化，差异需要读报告解释。
- Ellesmere 使用已加载页面声明与已捕获选项重放；Exwind 读取真实已有模块及静态布局。不会加载上游设置、安装永久 hook、执行 setter/路由/解锁/业务动作。
- 钥匙通信与刷新、技能描述下载被抑制，只测当前游戏缓存。暴雪设置只读已存在的分类/布局。Inspector 不运行真实拾取，Crests 不打开自定义页。
- 实际 Lychee 控制器三次开关、快速重开、alpha/几何/行池检查单列；原生 UI 的视觉质量、硬件快捷键、所有页高水位、战斗和真实首次登录不在自动等价声明内。

外层计时器逐阶段推进，180 秒墙钟上限，取消/战斗/错误会停止调度、注销私有来源并断开临时环境。单个生产同步函数或原生 API 无法被 Lua 时间预算抢占；报告 `maxCallMs` 和 `maxResumeMs`，不承诺测试完全无停顿。私有计时器队列上限 8,000、单次 drain 6,000 步；指纹深度 14、节点 300,000，Ellesmere 重放最多 4,096 条。

## 内存与诊断成本

`memory` 分别记录全客户端 GC 前后、全局 GC 毫秒、内存统计刷新毫秒、Lychee 与诊断插件各自的 AddOn counter。诊断插件包含私有实例，不能把它的内存移走后声称 Lychee 达到 1 MiB。私有堆差含诊断及后台噪声；原生 Frame/纹理成本未被 Lua 堆穷尽。完整 GC 是用户启动的一次诊断干预，不是产品关闭策略。

`phases.activeMs` 为受测调用，`maxResumeMs` 包括诊断哈希、采样、GC 等；总墙钟还包含等待。第 4 轮插桩数字不能当成正常时延或与前三轮直接相减估算优化收益。加载/代码初始化、数据/API、SDK/index、查询、释放、UI 分开解释。观测高水位在同步调用结束时采样，不是精确峰值，也不是累计分配；本次实机流程不暂停 GC，累计分配仍由独立离线实验提供有限证据。

诊断源文件在 `tools/performance-test`；生产 `package/Lychee` 与 SDK 不改变。完成取证后可禁用诊断插件并重载；如需删除安装目录或报告，另行定向确认，不自动清理。

## 验证

`python tools/performance-test/build.py` → `lua tools/performance-test/test.lua` → `wowdoc validate --path "analyze/performance-test-package/Lychee Performance Test" --source wow-ui-source --product retail --ref latest`。

离线覆盖真实 TOC 文件加载入口、无自动启动/无 Dev、正常四轮、真实接口替身上的 EUI/Exwind 查询与解析、业务对照、早/中途取消、缺依赖、重入、战斗中止、超时、调度失败、模块初始化错误及之后恢复、工厂环境还原、UI 顺序、独立报告序列化/重读、跨会话 interrupted 恢复。离线替身不能证明真实客户端计时、taint、渲染或新增插件发现路径。

版本证据：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`（12.1.0）：

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:347`：LoadAddOn 接收 name，返回 loaded/value。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39`：NewTimer 接收 seconds/callback，返回 cbObject。
- `Interface/AddOns/Blizzard_ChatFrame/Shared/ClassTalentHelper.lua:57`：`SlashCmdList["TALENT_LOADOUT_BY_NAME"] = function(msg)`，原生 slash 注册形态。
- 同版本 SettingsPanel.lua:737、FrameScriptDocumentation.lua:509、MountJournalDocumentation.lua:273 的读取/计时证据见统一调查记录。
