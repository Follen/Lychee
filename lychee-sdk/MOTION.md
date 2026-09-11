# Motion 与窗口 Presence

`Lychee.UI.Motion` 是共享动效入口。控件反馈与窗口出入分离：`UI/Motion.lua` 管原生 Alpha、滑块 Translation 和页面高度；`UI/Presence.lua` 管一个互斥的主窗口出入通道。不要每个结果行创建 Presence，也不要每帧调用组件 Update。

## 主窗口分层

根框体保持最终位置、尺寸和缩放。独立背景只含圆角纹理；同位置、同尺寸的裁切视口包含一个内容框体，该内容框体显式锚定到根框体，而非裁切视口。顶栏、正文和底栏都在内容框体下，因此裁切边界变化不会重新排版文字。普通页面通过宿主使用现成的主窗口通道，无需自行拼装。

`ConfigurePresence(layout, background, {header, body, footer}, preset, viewport)` 在创建时绑定一次。`Presence(root, shown, finished, initialPosition, initialVelocity, layout)` 启动；`StopPresence(settle, complete)` 停止并返回当前位置/速度。此通道只允许一个活动窗口，调用新目标会替换旧任务；同时存在多个独立窗口时应使用各自的原生 Alpha 反馈，不能共享这个主窗口通道。

`Motion.Presets.palette`：打开440ms、关闭320ms；背景宽90%→100%、高82%→100%，中心从下方24逻辑像素回到原位。背景和裁切视口共用同一轨迹，内容的所有几何量不变。Hermite 曲线完整开场速度为2.6/0.44，结尾速度为零；中途反向保留速度和进度。根透明度在位置0→0.30间smoothstep，内容在0.20→0.88间smoothstep。

所有参数均为这一个预设的稳定标量；不要在动画回调里生成新预设或组件树。调整参数必须一并验证起止状态、30/120Hz轨迹、快速反向、冷/热重开及边界裁切。

## 生命周期

- 创建只保留背景、裁切视口和固定内容层；首次播放才建立一个驱动，之后复用一个任务表。
- 结束清空目标、布局、完成回调和时钟引用，移除OnUpdate并隐藏驱动。
- `StopAll(except)` 清理控件动画；传主窗口可保留尚在反向的Presence。
- 关闭时业务会话与安全动作先失效，视觉退出结束后才隐藏窗口。
- 战斗中的隐藏仍由安全宿主负责。动效先停止，不能改受保护布局，也不能在脱战后自行重开。
- 减少动态效果即时恢复完整背景与裁切边界；退出必须完成回调和隐藏。

帧驱动只计算标量、更新空背景/视口尺寸位置与透明度；不逐帧SetScale、不重设文字、不创建表/闭包/Frame、不添加强制GC。

验证：`tests/ui_motion.lua` 与 `tests/ui_library_integration.lua`。离线测试不代表已验证游戏中的字体像素、原生裁切、帧时间或观感，最终以客户端验证为准。
