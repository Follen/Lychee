# Motion 与窗口 Presence

Motion.lua管理普通控件Alpha/Translation和页面高度；Presence.lua管理一个互斥主窗口通道。Provider页面使用宿主窗口，不给结果行创建Presence。

## 整个层级一起运动

本面板的背景由七块纹理拼成。录像20260912-103056.mp4证实，根节点原生Scale没有将它们及子框体合成为整体，产生裂缝与不同步。此路径禁止使用，API存在或数值测试通过不能证明原生显示正确。

Presence只改共同根节点SetPoint/SetAlpha，不改Frame scale、字号、宽高或子节点/纹理锚点。位置对齐整物理像素，保持文字原有像素相位；没有全窗裁剪，正文自己的滚动边界保留。

创建时调用`ConfigurePresence(layout, anchor, preset)`，anchor为`{point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=restingY}`。正常布局/缩放变化后、播放之前更新静止锚点。

`Presence(root, shown, finished, initialPosition, initialVelocity, layout, initialAlpha)`启动或反向；`StopPresence(settle, complete)`返回当前位置、速度、透明度，无任务返回nil。显式初始值仅供主宿主跨Hide/Show收尾接续；普通反向自动采样。

预设：enter=0.42秒、exit=0.24秒、distance=64单位、launchVelocity=2、enterAlpha=0.10秒。三次Hermite运动，完整开场初速launchVelocity/enter、退出初速0、终点速度0；反向继承速度。透明度独立：开场100 ms使用1-(1-u)^2，关场240 ms使用u^3，避免主要位移被淡入掩盖。反向继承当前透明度。

## 生命周期和成本

- 首次播放创建一个驱动Frame/任务表，以后复用；不创建主面板原生动画组。每帧最多SetPoint/SetAlpha各一次，无变化跳过，无表/闭包/Frame分配。
- 各次播放独立精确时钟起点，隐藏时间不计入重开。结束解除OnUpdate、隐藏驱动并清空region/layout/finished/clock，保留有界驱动/空表。
- StopAll(except)传入主面板可保留待反向的Presence；普通控件动画照常取消。
- 关闭立即失效会话和安全动作、禁用输入、释放焦点；Input:SetVisualFrozen(true)只冻结外观，隐藏后解除。业务时序不延迟到动画结束。
- 战斗由安全宿主隐藏，停止后不改保护布局、脱战不重开；减少动态效果直接设置终态并完成退出回调。
- 普通控件原生组仍最多96个；高度和Presence各一个复用驱动，空闲无每帧工作。

验证：ui_motion.lua、presence_geometry.lua、interaction_smoke.lua。几何测试使用生产Theme生成七片背景，按录像观察到的逐区域缩放行为检查拼接和相对位置；不是完整WoW渲染器。真实字体、滚动裁剪、战斗保护、不同帧率下观感仍需游戏确认。
