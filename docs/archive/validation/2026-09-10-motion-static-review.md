# 动画静态排查

用户观察：reload 后最近列表偶发中间空白，随后自行恢复，现无法复现。静态检查 Show / SetQueryMode / RefreshHomeSections / SetSections / Motion / ResultList 释放路径，未找到主动留下最近列表两行空洞的路径。独立五行布局检查 y=-34,-86,-138,-190,-242，shown=true、alpha=1；离线不能验证原生裁切。没有证据证明缺少 UpdateScrollChildRect 是根因，不追加每帧刷新。

确认并修正 Alpha 边界：

- 同目标正在播放时 duration=0 被提前返回忽略。新增回归旧代码失败，修正后立即停止并落到目标值。
- 原生组被停止后 Lua playing 可仍为真。同目标请求先核对原生 IsPlaying，清除旧完成回调并恢复播放。模拟外部 Stop 后同目标重新请求通过。

API 来源 wow-ui-source / retail / requestedRef latest / resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34，Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimGroupAPIDocumentation.lua:220，excerpt: Name="IsPlaying", Returns isPlaying bool。

成本：无新增对象、缓存、计时器或订阅；活动 Alpha 请求增加一次原生播放状态读取，仅事件驱动调用，不轮询。原有 96 组上限与隐藏停止路径不变，2,000 次 Alpha 切换分配仍为 0.00 KiB。ui_motion / interaction_smoke 通过，静态 Lua/XML/TOC、wowdoc validate、diff 检查通过。完整契约结果见 motion-static-checks.txt。

这两个修正不等于已复现或已解决截图漏绘。真实客户端初始化、原生父级淡入与裁切交互仍缺现场证据；未进行游戏内帧时间测量。不增加诊断常驻开销。回滚采用新 revert 提交。
