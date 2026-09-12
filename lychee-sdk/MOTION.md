# Motion 与窗口 Presence

Motion.lua管理普通控件Alpha/Translation和页面高度；Presence.lua管理一个互斥主窗口通道。Provider页面使用宿主窗口，不给结果行创建Presence。

## 整个层级一起运动

本面板的背景由七块纹理拼成。录像20260912-103056.mp4证实，根节点原生Scale没有将它们及子框体合成为整体，产生裂缝与不同步。此路径禁止使用，API存在或数值测试通过不能证明原生显示正确。

Presence只改共同根节点SetPoint/SetAlpha，不改Frame scale、字号、宽高或子节点/纹理锚点。位置对齐整物理像素，保持文字原有像素相位；没有全窗裁剪，正文自己的滚动边界保留。

搜索框不创建本地Surface，直接使用窗口底色。相同颜色的重复背景在alpha=1时看不出来，淡出时会逐层叠加成深色矩形；例如两层25%不透明度合成43.75%。不要用退场时Hide背景或另加透明度补偿修复，避免引入状态闪变。普通设置输入框的独立Surface保留。

创建时调用`ConfigurePresence(layout, anchor, preset)`，anchor为`{point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=restingY}`。正常布局/缩放变化后、播放之前更新静止锚点。

`Presence(root, shown, finished, initialPhase, layout)`启动或反向；`StopPresence(settle, complete)`返回当前时间进度q，无任务返回nil。显式初始进度仅供主宿主跨Hide/Show收尾接续；普通反向自动采样。旧位置/速度/透明度三个初始参数已由一个phase替代。

预设只保留enter=0.42秒、distance=64单位、enterAlpha=0.10秒。打开和关闭共用一个时间轴：q每秒增减1/enter，位置q(2-q)，透明度a(2-a)，a=min(1,q×enter/enterAlpha)。完整关闭420ms，是完整开场的原样倒放；最后100ms倒放开场淡入。中途反向从当前q立即改变方向，只消耗剩余路程的时间。位置、透明度连续；速度方向即时反转，不沿用旧方向惯性。没有独立exit参数或另一条退场曲线。

## 生命周期和成本

### 原 Logo 动画

`Components:CreateBrand(...)` 保留原图。`brand:PlayMotion()` 调用 `Motion:Brand(texture, owner, size)`；owner 是静止品牌容器，size 是未变形的图标边长。`brand:StopMotion()` / `Motion:Cancel(texture, true)` / `Motion:StopBrand()` 停止并复位。单个品牌动效通道全库互斥；播放中同目标请求合并，新目标先停止旧目标。

录像 `20260912-114435.mp4` 证实此前原生 Scale/Translation 会把单纹理移出标题栏。旧替身把变换当成简单累计，没有覆盖真实渲染；不再使用该实现。直接用 SetSize 和相对 owner 的 CENTER 锚点渲染确认 SVG 的五段姿态，总时长 1.386 秒，cubic-bezier 用有界二分求解。中心 x=size/2，y=size/128 × (39 × (scaleY−1) + upwardOffset)，源图枢轴 (64,103)。静止时恢复完整 size×size 和 LEFT→owner.LEFT (0,0)，不改变 UV/纹理/父框体。点击区域必须锚到 owner，不能锚到正在变形的纹理。

首次实际播放创建一个私有短时驱动 Frame 和一个复用任务表；不创建原生动画组、新纹理或定时器。逐帧仅标量运算，最多 SetSize/SetPoint 各一次；同值跳过。精确时钟起点每次重置，停播解绑 OnUpdate、隐藏驱动、释放 region/parent/clock。减少动态效果和不可见时不启动；隐藏、关闭、StopAll 与 SetReduced 停止。战斗禁止几何 setter，仅保留一个有界待复位目标，下次安全调用时恢复，脱战不自动播放。

Palette 完成打开布局后触发；设置按钮 OnEnter 且窗口可交互时触发。主窗口 Presence 不变。验证：`tests/brand_geometry.lua` 的关键姿态、不同屏幕位置/缩放下局部边界与 30/60/144 FPS 采样，`tests/brand_motion.lua` 的真实面板集成。离线结果不代表客户端帧时间，游戏录像复验仍需单独完成。

### 公共生命周期

- 首次播放创建一个驱动Frame/任务表，以后复用；不创建主面板原生动画组。每帧最多SetPoint/SetAlpha各一次，无变化跳过，无表/闭包/Frame分配。
- 各次播放独立精确时钟起点，隐藏时间不计入重开。结束解除OnUpdate、隐藏驱动并清空region/layout/finished/clock，保留有界驱动/空表。
- StopAll(except)传入主面板可保留待反向的Presence；普通控件动画照常取消。
- 关闭立即失效会话和安全动作、禁用输入、释放焦点；Input:SetVisualFrozen(true)只冻结外观，隐藏后解除。业务时序不延迟到动画结束。
- 战斗由安全宿主隐藏，停止后不改保护布局、脱战不重开；减少动态效果直接设置终态并完成退出回调。
- 普通控件原生组仍最多96个；高度和Presence各一个复用驱动，空闲无每帧工作。

验证：ui_motion.lua、presence_geometry.lua、interaction_smoke.lua。几何测试使用生产Theme生成七片背景，按录像观察到的逐区域缩放行为检查拼接和相对位置；不是完整WoW渲染器。真实字体、滚动裁剪、战斗保护、不同帧率下观感仍需游戏确认。
