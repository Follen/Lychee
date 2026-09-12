# 原 Logo 原生动画

## 实施前预算与生命周期

- 保留 `Media/lychee-logo.tga` 的全部像素、配色、UV；不新增媒体、Frame、纹理、定时器或 Lua OnUpdate。
- 第一次实际播放时创建一个 AnimationGroup 和十个原生动画，计入 Motion 现有 96 组上限；以后复用。减少动态效果、战斗或不可见时不创建。
- 面板打开播放一次；设置按钮 OnEnter 在面板可交互时触发；播放中重复请求忽略。隐藏、关闭、减少动态效果和 StopAll 都停止，原生变换归零，不重排其他控件。
- 五段时长 168/336/336/252/294 ms，共 1.386 s；不搬入浏览器预览的循环停顿。42 px 纹理最大上移 2.296875 UI 单位。缩放关键点沿用预览 (1,1) → (1.075,.925) → (.96,1.045) → (1.035,.965) → (.99,1.012) → (1,1)。SVG 向下为正，WoW 向上为正。
- 原生逐段 Scale 使用相邻关键点比值，Translation 使用差值；共同底部原点位于原图 y=103/128。缓动采用 WoW IN_OUT/OUT/IN，不能声称与浏览器 cubic-bezier 像素逐帧相同。
- 离线预算：冷播放新增 1 组/10 动画、Lua 替身增量 <32 KiB；预热后 1,000 次播放/中断无新对象、累计临时分配 <64 KiB、GC 后保留增长 <8 KiB。引擎原生对象内存及游戏帧时间须实机测量，离线替身不能换算。

## 版本依据

`wow-ui-source / retail / requestedRef=latest / resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`；source check 无更新。精确 API 摘录见同目录 `2026-09-12-brand-motion-wowdoc.json`。

同版本 `Interface/AddOns/Blizzard_FrameXML/EventToastManager.xml:620–630`：order=1 的 Scale 为 `scaleY="0.001"`，order=2 为 `scaleY="1000.0"`，共同 BOTTOM 原点，证明分段 Scale 使用累计乘法恢复尺寸。动画只作用于单纹理；不重新启用此前被录像否定的整窗 Scale。

## 验证

- `lua tests/brand_motion.lua`：PASS。创建 1 组/10 动画；首次 Lua 替身增量 6.72 KiB；预热后 1,000 次播放/中断累计分配 0.00 KiB、GC 后保留增长 0.00 KiB；没有新增 Frame/纹理/驱动。关键姿态、净缩放/净位移复位、池上限、隐藏/战斗/减少动态效果以及高度变化后的参数失效均通过。
- 专项测试还加载生产 Palette/Components/Motion，验证打开、播放中悬停合并、播放结束后悬停重播、关闭即时停止、退场时悬停不重启、快速重开、组件隐藏和设置切换。旧 ui_motion 的精简 Palette 替身补上品牌组件接口；实际品牌路径由新测试覆盖。
- `powershell -NoProfile -File tests/check_contract.ps1`：PASS；完整原始输出见 `2026-09-12-brand-motion-checks.txt`。此前一轮失败来自旧测试替身缺少 brandComponent，修正后完整重跑通过；未修改业务代码绕过断言。
- 所有运行时 Lua 经 `luac -p`，Bindings.xml 解析通过；TOC 清单/多客户端加载检查通过；`wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：79 Lua、valid=true、无诊断；`git diff --check` 通过。
- 源码审查：只增加单纹理原生变换，媒体和 Presence.lua 没有改动，设置按钮点击、搜索、窗口与安全会话时序保持原实现。没有新增模块或 TOC 修改。
- 限制：以上内存是离线 Lua 5.1 替身统计，不包含客户端原生动画对象和纹理内存；没有据此宣称游戏帧率或总内存已验证。游戏内需 `/reload` 后检查打开、连续快速开关、悬停、减少动态效果和战斗隐藏；比较同环境开关前后常驻/临时内存及帧时间。原生缓动和不同 UI 缩放下的真实观感待用户确认。
