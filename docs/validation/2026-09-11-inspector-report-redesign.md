# 插件识别浮窗重构与文字按钮留白

基线 fa4324d1284cd08e91137f817ccd6451eef8d2b7。
用户完整报告 checked=78 queued=78 capped=false：RurutiaChatBar.2014fcc9670
及其 Text 均被 outside-pointer 拒绝；父 ChatBar 无纹理，Center 透明。
本机 RurutiaSuite/Core/UILib.lua:206 创建 Button、启用 AnyUp 点击；:235 创建居中文字。
这里的点击区域比字形区域大，不能将“鼠标未压在文字上”等同于按钮不可见。
旧算法上的文字按钮留白回归先失败，再实现可点击 Button/CheckButton 的内容证明。
内容仍必须显示、非透明、非空且完全位于按钮内；再与最多16层裁剪祖先求可见交集，各自按有效缩放转为屏幕坐标。普通 Frame 不放宽。
不加入插件名前缀白名单，不取消 fstack、空锚点、隐藏、裁剪和 Tooltip 过滤。
该证据解释此次 RS 样例，不能据此宣布所有 EUI Aura/次级资源条实机问题已修复。

浮窗按 DESIGN.md 改为摘要 / 详情 / 报告；去掉重复标题与无目标时的空栏目。
原裸 EditBox 没有独立裁剪容器，报告溢出会盖住按钮。
现在 EditBox 是 ScrollFrame 的 scroll child；正文、返回操作、底部提示各有固定区域。
滚轮、公共滚动条及 OnCursorChanged 共用范围钳制。完整文本仍可 Ctrl+C。
复制期间冻结目标；返回、Esc、战斗退出沿用原有生命周期。未添加 TOC 或模块。

## 成本与生命周期

来源算法只在活动识别轮询中运行，0.1 秒一次；按钮每个候选最多32个可见区域检查。
新增两次 GetRect 只发生于可点击按钮的区域已通过内容过滤、指针未命中该区域时。
祖先裁剪求交最多16层，也仅在按钮留白分支运行。标量校验无新增临时表；沿用每批128/0.75ms、总512候选上限，不全局枚举。
报告在主动点击复制时生成，沿用196608字符上限；只保留当前报告，返回/关闭清空。
UI首次使用创建并复用；新增报告容器、ScrollFrame、公共滚动条三个 Frame。
滚动更新由鼠标、光标和尺寸事件驱动，只有主动拖动滚动条时使用共享 OnUpdate。
退出时结束拖动、清除焦点和报告；未启用/空闲/战斗零新增活动。
沿用首次16 Frame/48 Region、保留512 KiB、100次启停累计分配1 MiB/增长64 KiB预算。

## 版本来源

sourceId=wow-ui-source，product=retail，requestedRef=latest，matchedTag=null，
resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；已 source list / check。
以下路径均在 Interface/AddOns 下：

- Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:417，
  `Name = "IsMouseClickEnabled"`，返回 enabled bool。
- Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:91，
  `Name = "SetScrollChild"`，child 为 SimpleFrame；:65 GetVerticalScrollRange。
- Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua:21、36，
  ScrollingEdit_OnTextChanged / OnCursorChanged；用负 cursorOffset 与 scroll/range/height 调整滚动。
- Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:580、720，
  `Name = "SetMaxLines"` / `Name = "SetWordWrap"`。

## 验证

专项回归覆盖按钮留白、隐藏文字、同几何普通Frame拒绝，原有冷却/Aura/覆盖层筛选；
报告原生裁剪父子关系、长内容滚动范围、滚轮、键盘选区跟随、底部动作隔离、小屏缩放；
Shift、复制、Esc、战斗、停用、重复启停和无全局枚举保持通过。
滚动替身注入原生测量后的2400像素内容高度，不按字节数伪造游戏字体测量。
专项实测（离线 Lua 5.1）：12 Frame、37 Region，首次保留37.1 KiB；
10000次指针跟随11ms/0分配；100次启停5ms/393.2 KiB、无观察到保留增长。
完整 check_contract.ps1 通过；wowdoc validate 75 Lua / diagnostics=null。
游戏里的真实文字自动高度、复制到剪贴板、不同UI缩放下绘制及 RS/EUI 识别仍待 /reload 验证。
无法控制当前游戏客户端，不把离线回归或同步当作实机验收。

独立只读审查发现并复现两个P2，现均已修复：
1. 鼠标在裁剪区域内，但离鼠标的按钮文字已被裁掉；加入绘制矩形交集检查，
   回归覆盖完全/部分裁剪、不同有效缩放、不可读GetRect。
2. Shift诊断在同一次轮询完成时pending前后相同，原复制按钮不会启用；
   现在单独跟踪diagnosticReady，完成和恢复扫描均同步UI。
两项新增断言都先在旧逻辑失败，再通过；审查无其他必须修复发现。
