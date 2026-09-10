# 动画第二轮静态审查

基线 796c94b。覆盖 Motion、Palette 首次打开与关闭/切页、最近条目绑定/释放、ResultList、设置开关和安全覆盖层引用路径。本轮不声称复现了游戏截图中的漏绘。

新增确定缺陷与回归：

1. Slide 与 Alpha 原先不对称：原生 Translation 停止后，同目标请求仍提前返回。回归旧代码失败，新代码核对 IsPlaying 后恢复。
2. heightTick 在最后一次 SetHeight 触发同步尺寸回调后，无条件 StopHeight，可能误停回调新建的高度任务。使用任务代次校验，旧任务只结束自身。测试触发 400 高回调启动 450 目标，旧代码失败，新代码完成到 450。
3. StopHeight(true) 原先在 SetHeight 回调后清空复用 job.region，可能清除新任务的目标对象。改为在 setter 前捕获标量并释放旧引用；400 高回调新建 475 目标的测试通过。

这些是公共动画库边界缺陷；尚未证明截图发生时 Palette 实际触发了这些边界。最近条目无整行 Alpha 动画，静态布局连续；没有依据向滚动路径加入常驻强制重绘。

API 依据沿用上一轮：wow-ui-source / retail / latest / 8ea15b61e45c0ed4eba01439c90757f86eb78d34；SimpleAnimGroupAPIDocumentation.lua:220 IsPlaying。高度使用既有 SetHeight 与尺寸回调接口，无新增 Blizzard API。

无新增 Frame、动画组、事件、timer、队列；新增一个高度任务代次标量，job 继续复用。关闭后 driver 回调 nil、job.region nil；2,000 次高度/Alpha/开关操作各 0.00 KiB 临时分配，池不增长。离线计时约 1 ms，不能外推游戏帧时间。

完整契约、针对性回归、Lua/XML/TOC、wowdoc validate（45 Lua，valid=true）和 diff 检查通过，原始输出 motion-reentrancy-checks.txt。游戏原生裁切、重载后偶发漏绘仍未实机复现，需保持未确认状态；本轮不要求用户继续回忆触发过程。回滚使用新的 revert 提交。
