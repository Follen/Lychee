# 重载首次展开时最近条目漏绘

现场路径：/reload → Alt+Space，展开过程中最近条目部分消失但位置仍保留。用户反馈对 homeView.frame 执行 UpdateScrollChildRect 后恢复（用户原话有“好像”，新代码仍需同路径实机验收）。此证据支持滚动内容边界更新遗漏，之前仅验证 Lua 布局连续不能排除原生绘制问题。

Palette 最近列表过去 OnSizeChanged 仅更新滚动位置与自绘滑块；同滚动位置时连 SetVerticalScroll 都会跳过。现在首次 OnShow、实际视口宽高变化、内容高度变化、行布局或显隐变化后调用 UpdateScrollChildRect。缓存三个几何标量和一个 dirty 标志；成功调用后清除，隐藏/战斗短路保留。初次隐藏构建在显示时刷新。

不创建额外 Frame、AnimationGroup、timer 或 OnUpdate，不扫描新目录；利用已有布局循环标记变化，尺寸事件仅 O(1) 比较和必要的原生刷新。活动伸缩期间随实际尺寸更新，空闲无工作，同尺寸事件不调用原生刷新。客户端原生调用成本/帧时间待实机测量，不声称零成本；保留原有动画与安全交互。

证据：sourceId wow-ui-source / product retail / requestedRef latest / resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34；SimpleScrollFrameAPIDocumentation.lua:115 定义 UpdateScrollChildRect()；Blizzard_SharedXML/HybridScrollFrame.lua:155–156 在 scrollChild:SetHeight(displayedHeight) 后 self:UpdateScrollChildRect()。原始查档 scroll-rect-api.json。

回归先在旧代码失败：expanded recent viewport must refresh native scroll bounds。修正后覆盖实际视口变化、无变化重复通知、首次显示、隐藏后重开、战斗延期与恢复。旧测试不模拟客户端渲染，本次回归证明边界刷新调用契约，用户现场刷新恢复才是绘制方向证据。

完整 check_contract、Lua/XML/TOC、wowdoc validate（45 Lua，valid=true）、git diff --check 通过；原始日志 scroll-rect-checks.txt。新版本 /reload → Alt+Space 的实机确认仍待用户执行。其他游戏场景 CPU/内存未测，不把离线通过记作游戏验证。回滚使用新 revert 提交。
