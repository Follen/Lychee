# 主面板原生空间动效

**实机否决：** 后续录像`20260912-103056.mp4`出现七片背景裂缝和子框体不同步。此方案由`2026-09-12-window-geometry-repair.md`取代；下面的离线通过不代表视觉正确。

## 实现前观察与预算

- 依据用户录像 `C:\Users\follen\Videos\20260912-100048.mp4`（1920×1080、30 fps、10.6 秒），逐帧检查打开约 3.9 秒和关闭约 5.2 秒的片段。旧版主体位移在低透明度阶段消耗过多，视觉主要表现为黑框淡入；关闭先失焦/禁用输入导致外观提前变化。
- 基线提交 f8b3fc8；本轮仅改主面板出入与退出时输入外观，搜索、动作权限、布局和固定数据库不变。
- 触发源：主面板 Show/Hide；一个窗口、一个活动播放，无队列。首次播放至多新增一个原生 AnimationGroup、Scale/Alpha 各一个；不创建 Frame，不新增事件、计时器或 Lua OnUpdate。
- 首次打开预算：动效初始化至多上述三个引擎对象；不预热或重建内容树。热启动/关闭复用对象。1000 次开关及中途反向累计 Lua 分配低于 512 KiB（沿用原预算），对象增长为零；结束后没有活动回调/业务引用。模拟器 CPU 单列，不能换算成游戏帧率。
- 对象所有者为 Motion 主窗口通道，只保留一个根节点及其原生组；结束释放活动任务的 region/layout/finished。战斗由原安全宿主隐藏，停止播放且不修改保护布局；脱战不自动重开。
- 方案：Scale 原生视觉变换作用于整个根节点，固定布局/Frame scale/字体设置；不新增外层裁剪。打开从 88% 到 100%，420 ms OUT；透明度在 120 ms OUT 内到 1，使展开后段仍清晰可见。关闭到 90%，240 ms IN；透明度同周期 IN，前段保留主体、后段淡出。中断从原生 GetSmoothProgress 采样当前视觉缩放和透明度接续，取消旧完成回调。原生 smoothing 不提供速度继承，不能宣称反向速度连续。
- 关闭冻结输入外观但立即禁用实际输入/清理焦点；隐藏后解除冻结，下一次打开恢复实时状态。

## 版本依据

对应 wowdoc 记录见 `2026-09-12-native-window-motion-wowdoc.json`。sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

## 验证

- `powershell -NoProfile -File tests/check_contract.ps1`：完整通过，包括 Lua/客户端 TOC、SDK、搜索、角色固定项、安全动作、UI库集成、输入/设置与性能门禁。原始输出：`%TEMP%\lychee-native-window-motion-check.log`。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：checkedLua=79，valid=true，diagnostics=null。
- `git diff --check`：通过。
- 实际Palette Show/Hide离线边界回归覆盖：原生两个轨道停止前采样（Stop重置进度）、开关中途反向、重复关闭、原生Stop及settle setter重入、减少动态效果、战斗停止、冷/热12轮×6采样点、真实输入框冻结/鼠标离开/隐藏解除冻结/重开恢复。
- 使用相同1000轮“打开→50ms→关闭→30ms→重开→54个120Hz步进→关闭→39个120Hz步进”的序列：前后累计分配均179.69 KiB，热循环Frame/动画组增长均0。旧驱动测84 ms、新边界模拟测46 ms；旧版执行Lua插值，新版执行测试替身插值，不能据此报告游戏CPU改善百分比。
- 冷模块加载1312.7 KiB retained、18 ms、Frame=2、events=3，原有预算通过；首次Palette仍延迟创建59个Frame。动效本身首次创建1组/2轨道，移除了原Presence驱动Frame；并未把原生组/轨道内存换算成Lua节省。
- 结束后没有presence活动任务、OnUpdate或播放中的原生组，清空region/layout/finished。固定owner和动画对象保留以复用；不强制GC、不新增轮询。
- 业务之外的原生字体光栅、正文裁剪、动画中交互命中、受保护框体引擎行为，以及客户端30/60/120 FPS、不同UI缩放、快速反向的实际观感仍待实机验证。不能以离线通过宣称已经做到iOS系统级渲染。
- 仅现有Lua有运行时修改，按项目规则提交后同步到 `D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`，133个运行时文件清单及SHA256逐一核对；本轮无需变更TOC。回滚用新的git revert后按同一同步流程。

