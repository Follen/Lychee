# 选中轮廓与浮窗层级

基线 abfd36bcc4ba4d341166d955a50ec3681bb4e531。
用户实机截图显示红框穿过检查报告窗口左上区域。
轮廓和主窗都是 UIParent 的直接子框体、TOOLTIP strata，未指定 FrameLevel；
轮廓晚于主窗创建/显示，缺少确定的上下顺序。
这是局部层级缺陷，直接用实际UI构造及摘要/Shift详情/报告状态验证层级关系，
无需扩大到识别算法调查。旧版本在层级关系断言失败。

成本与生命周期：只在首次创建这两个自有Frame时各设置一次FrameLevel；
主窗1、轮廓0；保留TOOLTIP strata，面板子控件按既有父子关系位于其上。
没有新Frame/Region、计时器、事件、缓存或热路径工作；沿用原有关闭/战斗隐藏。
不修改被选中的第三方框体，不增加每帧抬升，不依赖Show先后决定顺序。

wowdoc已source list/check，无更新。sourceId=wow-ui-source，product=retail，
requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。
Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1280：
`Name = "SetFrameLevel"`；:1288，frameLevel number。仅在非战斗首次创建的自有Frame使用。

回归覆盖摘要、Shift详情、报告及红框重新Hide/Show后，主窗仍严格高于轮廓。
离线检查不代替游戏渲染；待/reload确认截图中的相交处遮挡，及不同UI缩放表现。

验证完成：专项与完整 check_contract.ps1 通过；wowdoc validate 75 Lua、diagnostics=null；git diff --check 通过。离线仍为12 Frame/37 Region，10000次跟随0分配，未观察到启停保留增长。
