# 主面板拼接裂缝修复

## 实机证据与原因

用户录像`C:\Users\follen\Videos\20260912-103056.mp4`，1920×1080、30 fps、5.933秒，对应交付52487cb。约2.9秒关闭和3.4秒打开的连续帧显示：左右细条与背景中片分离，输入框/正文没有随背景保持整体轮廓。

生产Theme:CreateRoundedSurface在UI/Theme.lua将背景分为中片、左右条与四角。原生Scale用于根节点后，其实机行为不等于整个Frame子树的合成缩放。本轮不声称这是所有WoW框架的普遍规则，但录像足以否决该实现。正文裁剪无法解释正文之外的左右背景裂缝，透明度不同步也不能解释有实际间隔的拼接边。

旧测试仅检查API数值和不改布局，未模拟各区域变换，因此“全部通过”未覆盖此故障。新增tests/presence_geometry.lua直接调用生产七片背景构造，按录像观察到的逐区域Scale建立有限几何替身，检查中片/侧条边缘闭合及内容相对位置。对52487cb的实际Presence.lua运行失败：`left background seam split during presence`；修订版通过。该替身不是完整原生渲染器，也不能证明新观感已达成。

## 修订和成本

- 恢复共同根节点SetPoint运动，维持Frame缩放、字体、七片纹理和子节点布局；根节点SetAlpha统一透明度，无原生Scale、全窗裁剪或独立背景收缩。
- 空间与透明度分开：进入420ms、64单位、Hermite初速2/0.42，透明度100ms二次ease-out；完全可见后仍余约37单位运动。退出240ms、Hermite移动、透明度u^3淡出，中点仍87.5%可见。修复旧弱位移方案的大部分运动发生在低可见度阶段的问题。
- 快速反向继承位置、速度、独立透明度。沿用每次播放精确时钟起点、对齐物理像素、减少动态效果、战斗取消、输入冻结/恢复。
- 仅主窗口Show/Hide触发，一个活动任务，无队列。首次创建一个驱动Frame/任务表，以后复用，取代上一版1组/2轨道。预算沿用先前根节点实现：1000轮累计分配<512KiB、热循环无新增对象；每帧最多根SetPoint/SetAlpha各一次，同值跳过，零活动解除OnUpdate并隐藏驱动。结束释放region/layout/finished/clock；不新增计时器/事件/GC。
- 热循环实测179.69KiB，与前两版相同；CPU结果为离线驱动/替身的测试成本，不能对比为游戏帧率收益。原生对象与Lua堆分开，不将移除组或新增驱动换算成内存净节省。

## 验证与剩余事项

- tests/presence_geometry.lua：旧版失败、新版通过，场景包括开场/关场的拼接边和内容位置。
- tests/ui_motion.lua：反向位置/速度/透明度、冷/热12轮×6点、30/120Hz、重入、减少动态效果、战斗与1000轮对象复用通过。
- tests/interaction_smoke.lua：有焦点/失焦Esc、输入外观冻结/悬停/重开、战斗与原业务通过。
- tests/check_contract.ps1完整通过，原始结果`%TEMP%\lychee-window-geometry-check.log`；Lua/XML/TOC/客户端/SDK/性能检查通过。
- wowdoc validate：79个Lua有效，diagnostics=null；git diff --check通过。对应版本证据在window-geometry-repair-wowdoc.json，sourceId=wow-ui-source/product=retail/requestedRef=latest/resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。
- 仅现有运行时Lua变化；提交后按133文件清单/SHA256同步到`D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`，保留目标旧文件。使用/reload加载；回滚用新的git revert及相同同步流程。
- 无法直接操作客户端。新的实际视觉、字体光栅、正文裁剪、快速反向观感、不同帧率及战斗保护仍待游戏验证。不得把提交、复制或上述离线检查当成实机通过。
