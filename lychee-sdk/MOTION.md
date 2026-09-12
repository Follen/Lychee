# Motion 与窗口 Presence

`Lychee.UI.Motion` 是共享动效入口。`UI/Motion.lua` 管控件原生 Alpha、滑块 Translation 和页面高度；`UI/Presence.lua` 管主窗口出入。普通 Provider 页面使用宿主窗口，不给结果行创建 Presence，也不每帧调用组件 Update。

## 整窗原生变换

背景、顶栏、正文和底栏属于同一窗口根节点。原生 Scale / Alpha 对整窗做视觉变换；不调用 Frame:SetScale / SetPoint，不改字号、不重新布局、不新增全窗裁剪。正文自己的滚动边界保持不变。

宿主创建时调用一次 `ConfigurePresence(layout, anchor, preset)`。anchor 为宿主持有的 `{point="TOP", relative=UIParent, relativePoint="TOP", x=0, y=restingY}`，供正常静态布局更新；动画只取其中preset，不逐帧改锚点。

`Presence(root, shown, finished, initialScale, initialAlpha, layout)` 启动。初始参数省略时采用完整开场或关场起点；中途改变目标时自动采样正在运行的两个轨道。`StopPresence(settle, complete)` 停止并返回当前视觉缩放/透明度（无播放返回nil、nil）。这个内部宿主接口已替换旧的归一化位置/速度参数，不能传旧的0/0开场值。

`Motion.Presets.palette`：

| 参数 | 值 | 用途 |
|---|---|---|
| enter | 0.42秒 | Scale从enterScale到1，OUT |
| enterScale | 0.88 | 完整开场视觉尺寸 |
| enterAlpha | 0.12秒 | Alpha从0到1，OUT；后段展开已经完全可见 |
| exit | 0.24秒 | Scale和Alpha同时IN，前段保留可见主体 |
| exitScale | 0.90 | 关场收拢到的视觉尺寸 |

Scale以CENTER为原点，两个动画Order均为1并行播放。参数是稳定标量，不在回调里创建预设或组件树。反向在Stop之前读取各自GetSmoothProgress，保证尺寸/透明度接续；不保证原生IN/OUT曲线的反向速度连续。完整隐藏后的每次Play重置轨道，冷/热打开幅度相同。

## 生命周期与成本

- 主窗口通道只有一个原生组，首次播放懒建并保留在Motion.presenceState，拥有一个固定root。其他root调用即时应用，不能用本通道管理多个独立窗口。
- 一组、两个动画对象，没有新Frame或Lua OnUpdate/计时器；持续插值由引擎执行。普通控件另有最多96组的上限。
- 结束/停止先取消活动任务和回调，再停原生组，结束时清空region/layout/finished；仅保留原生组和所属root。结束后的setter/native hook重入不能完成旧退出。
- `StopAll(except)` 清理控件动画；传主窗口可保留尚在反向的Presence。
- 关闭立即失效业务会话和安全动作、清理焦点/禁用输入；Input:SetVisualFrozen(true)暂时冻结外观。退场结束再隐藏窗口，Input:Hide解除冻结。打开恢复启用状态和实时外观。
- 战斗隐藏由安全宿主负责；停止动画不改保护布局，不在脱战后重开。
- 减少动态效果直接设置终态；退出完成回调负责隐藏，不能留下透明活动窗口。

验证：`tests/ui_motion.lua`、`tests/interaction_smoke.lua`、`tests/ui_library_integration.lua`。native_animation.lua仅模拟原生组生命周期和采样边界，其缓动计算不代表客户端实际曲线。离线测试能检查不改布局、取消/反向、输入冻结、对象复用；字体光栅、正文裁剪、运动中命中、战斗保护与实际帧率/观感必须在游戏验证。
