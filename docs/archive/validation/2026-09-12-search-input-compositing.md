# 搜索输入框淡出深色长条

用户录像`C:\Users\follen\Videos\20260912-105826.mp4`，6.4秒。放大约3.9–4.3秒的退场帧，搜索框矩形比窗口其他区域更黑，位置随窗口移动；本轮保留d79e29d已经确认的正放/倒放时间轴。

生产Input:Create给搜索容器创建了额外Surface；Theme的input/inputFocus/inputHover与window底色相同。父透明度分别作用于重叠绘制区域：局部和窗口两层同色底在alpha=1时不可区分，在0<a<1时合成不透明度为a+a(1-a)，产生录像里的长条。Runtime的search EditBox本来没有普通输入框的样式，额外底色来自Input外层容器。

修复：搜索容器不再创建背景/四边纹理，也不在焦点/悬停/启用切换时ApplySurface。保留文字/图标状态、输入外观冻结、鼠标范围、焦点、禁用及释放逻辑。普通设置字段的StyleEditBox及Surface不变。不是在动画过程中临时隐藏背景，避免新增边界闪变。

成本：首次打开减少一个背景和四条边纹理，无新Frame/事件/定时器/驱动/缓存；热路径取消Surface setter及拼接样式key。沿用现有输入生命周期，隐藏后没有新增活动工作；本次不改轨迹/时长，不声称离线内存能量化原生纹理节省。

验证：

- 在真实Palette/Input/Theme交互测试中读取实际生成的Surface颜色，计算25%/50%/75%/100%窗口alpha时的叠加。旧版在首个样本失败：`search background stacks opacity during fade: 0.4375 vs 0.25`；修订版通过。另确认search EditBox没有另一层普通字段背景。
- tests/interaction_smoke.lua与tests/ui_motion.lua通过：有焦点/失焦Esc、关闭外观冻结、鼠标离开、重开、战斗、普通字段，以及43点开关镜像轨迹与部分反向未变。
- 完整tests/check_contract.ps1、wowdoc validate和git diff --check作为交付检查。日志`%TEMP%\lychee-input-compositing-check.log`。
- Alpha接口证据：wow-ui-source / retail / latest / 8ea15b61e45c0ed4eba01439c90757f86eb78d34，SimpleFrameAPIDocumentation.lua:1133，SetAlpha(alpha:number)。完整元数据沿用2026-09-12-window-geometry-repair-wowdoc.json；本轮无新增API。
- 提交后按133文件清单/SHA256同步`D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`，保留目标旧文件，/reload加载。回滚使用新的git revert。
- 离线叠色检查不是WoW完整渲染器；修订后的实际消失画面仍需客户端确认。
