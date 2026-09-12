# Motion 与窗口 Presence

`Lychee.UI.Motion` 是共享动效入口。控件反馈与窗口出入分离：`UI/Motion.lua` 管原生 Alpha、滑块 Translation 和页面高度；`UI/Presence.lua` 管一个互斥的主窗口出入通道。不要每个结果行创建 Presence，也不要每帧调用组件 Update。

## 整窗运动

背景、顶栏、正文和底栏属于同一个窗口根节点。开关只改变根节点位置与整体透明度，不缩放文字、不收缩背景、不使用全窗裁剪。子控件的布局和正文自己的滚动边界保持不变。普通页面使用宿主现成的主窗口通道。

宿主创建时调用一次 `ConfigurePresence(layout, anchor, preset)`；anchor为 `{point="TOP", relative=UIParent, relativePoint="TOP", x=0, y=restingY}`。此表归宿主持有，在布局/缩放变化后、播放之前更新静止锚点。`Presence(root, shown, finished, initialPosition, initialVelocity, layout)` 启动；`StopPresence(settle, complete)` 停止并返回当前位置/速度。此通道只允许一个活动窗口，调用新目标替换旧任务；多个独立窗口不能共享此通道。

`Motion.Presets.palette`：打开440ms、关闭320ms、垂直距离44界面单位。Hermite曲线完整开场速度为2.6/0.44，结尾速度为零；关闭从静止启动，中途反向保留速度和进度。根透明度为smoothstep(position)，背景和内容共享透明度。位移按有效缩放舍入为整屏幕像素，再加到静止锚点上，保留文字的原有像素相位；一次播放仅采样一次缩放，播放期间不改缩放。

所有参数均为预设的稳定标量；不要在动画回调里生成新预设或组件树。调整参数须验证起止状态、固定宽高/缩放、整像素位移、30/120Hz轨迹、快速反向、冷/热重开及内容相对位置。

## 生命周期

- 直接复用既有窗口层级，不额外创建背景、裁剪或内容容器；首次播放建立一个驱动，之后复用一个任务表。
- 结束清空目标、布局、完成回调和时钟引用，移除OnUpdate并隐藏驱动。
- `StopAll(except)` 清理控件动画；传主窗口可保留尚在反向的Presence。
- 关闭时业务会话与安全动作先失效，视觉退出结束后才隐藏窗口。
- 战斗中的隐藏仍由安全宿主负责。动效先停止，不能改受保护布局，也不能在脱战后自行重开。
- 减少动态效果即时恢复静止位置与目标透明度；退出必须完成回调和隐藏。

帧驱动只计算标量，每帧最多根节点SetPoint和SetAlpha各一次；相同像素位移跳过SetPoint。不逐帧SetScale、不重设文字、不创建表/闭包/Frame、不添加强制GC。使用短时标量驱动以便反向保留速度，不另建原生动画组。

验证：`tests/ui_motion.lua` 与 `tests/ui_library_integration.lua`。离线测试不代表已验证游戏中的字体像素、原生裁切、帧时间或观感，最终以客户端验证为准。
