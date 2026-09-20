# Logo 播放期间偏移修复

## 复现与原因边界

- 用户录像 `C:\Users\follen\Videos\20260912-114435.mp4`，1920×1080、30 FPS、5.5 秒。重新打开约在 2.65 秒；3.1 秒面板已停稳但 Logo 不在原位，3.53 秒 Logo 出现在“最近使用”附近，约 4 秒回到正确位置。不是悬停触发或主窗口仍在运动。
- Agent 可重复检查：`python C:/Users/follen/.codex/visualizations/2026/09/12/brand-video-114435/check_video.py`。固定标题栏区域 (654,242,42,54)，4.2 秒原图红色像素 351，3.1 秒为 0；明确失败 `Logo leaves its local header bounds during native playback`。这是旧录像证据，修复不会改变该录像。
- 排查方向：原生缩放/位移组合坐标问题 > 父窗口 Presence > 重复触发。后两者被鼠标不在图标区域以及文字已停稳的连续画面削弱。确定的是原生 Logo 播放路径不满足局部边界；没有声称定位到客户端内部矩阵实现。
- 旧离线替身只按假定方式累乘/累加，不能证明客户端坐标；原来的“归零测试通过”不是视觉验收。`lua tests/brand_geometry.lua` 在旧实现上因调用已被录像否定的原生变换而失败；新测试随后继续对实际 SetSize/SetPoint 输出逐帧验证边界。

## 修复与成本预算

- 原图、UV 和主窗口 Presence 不变。移除 Logo 的所有原生 Scale/Translation，使用相对品牌容器的 CENTER 锚点和原纹理 SetSize；不把屏幕坐标或父框体位置带入公式。设置按钮命中范围改锚到静止品牌容器。
- 精确沿用预览的五段关键点与两条 cubic-bezier，1.386 秒播放一次。每次播放单独时钟起点；播放中同目标请求合并，结束/隐藏/减少动态效果/关闭均停止并恢复 LEFT (0,0) 和原尺寸。组件只传静止 size，避免从上次变形尺寸累计。
- 首次需要创建一个共享短时驱动和一个任务表；上限 1 活动目标、1 驱动、0 原生动画组、0 新纹理、0 timer。帧内有界五段查找和每曲线 16 次二分，最多 SetSize/SetPoint 各一次，无临时表/闭包。停止时解绑 OnUpdate、隐藏驱动并清空 region/parent/clock；战斗时先停更新，保留最多一个目标待安全时复位，不在战斗中修改保护布局。
- 沿用冷分配 <32 KiB、1,000 次播放累计分配 <64 KiB、GC 后保留增长 <8 KiB 的离线预算；新增短时驱动是替代已被实机否定的原生组合，不能继续宣称“无 Lua OnUpdate”。无活动状态仍无每帧工作。

## API 与验证

- `wow-ui-source / retail / requestedRef=latest / resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。SetSize/SetPoint/ClearAllPoints/IsVisible/SetScript/GetTimePreciseSec 的精确源证据见 `2026-09-12-brand-local-geometry-wowdoc.json`；这些接口用于自有纹理，保护布局 setter 在战斗分支禁止调用。
- 专项：2,952 姿态采样覆盖 30/60/144 FPS、三种父缩放、三种屏幕横坐标及运动父框体，局部中心 x 恒为 21，y 小于 4 UI 单位；宽高在确认的形变范围内。关闭、隐藏、减少动态效果、600 秒隐藏后的重开时钟和战斗待复位均通过。
- 生产面板集成：原图不变、固定命中区域、打开、悬停合并、完成后重播、关闭即时停止、关闭期间不重启、快速重开、组件隐藏和减少动态效果通过。
- 离线 Lua 5.1：首次替身增量约 1.6 KiB，1,000 次完整播放约 211 ms CPU 总量、分配与保留增长均 0.00 KiB。不是游戏每帧开销或原生对象内存数据。
- 完整契约 `tests/check_contract.ps1` 通过，原始输出见 `2026-09-12-brand-local-geometry-checks.txt`；所有运行时 Lua 解析和 Bindings.xml 解析通过，多客户端 TOC 检查通过，wowdoc validate 检查 79 Lua、valid=true、无诊断，git diff --check 通过。修复后的客户端录像、真实帧时间和内存待 `/reload` 后验证；不得把旧录像检测或离线测试宣称为实机修复完成。
