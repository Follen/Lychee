# 关闭沿开场原轨迹返回

用户录像`C:\Users\follen\Videos\20260912-104436.mp4`长8.433秒；反馈开启已可接受，关闭应沿开启原路径返回。基线c52b62e的开启420ms，关闭另用240ms和独立透明度，不能互为倒放。

## 契约与实现

- 保留完整开场视觉轨迹：原Hermite开场初速2/T、末速0恰好化简为2q-q²，T=0.42秒。距离64单位，前100ms透明度ease-out到1，均不变。
- 开关共享q：开场从0到1，关闭从1到0，每秒变化1/T。位置q(2-q)，透明度a(2-a)，a=min(1,qT/0.1)。关闭完整420ms，最后100ms执行开场淡入的倒放。
- 中途反向从当前q直接往回走，剩余时长=abs(target-q)T；位置/透明度连续，速度方向立即反转。零进度关闭立即结束，无透明活动窗口。
- 主宿主跨收尾只保存phase；删除独立退出曲线、退出时长和三项运动状态传递。保留输入外观冻结、业务/安全动作立即失效、战斗取消、减少动态效果、独立时钟及像素对齐。

## 成本与生命周期

触发源仍只有主窗口开关，一次一个任务，无队列；首次一个驱动Frame/任务表，以后复用。每帧只计算标量和最多一次SetPoint/SetAlpha，无新增事件/计时器/原生动画组。隐藏清空活动引用并移除OnUpdate。沿用预算：1000轮累计分配<512KiB、热循环对象增长0、空闲工作0。反向只改方向/起点，不复制轨迹数组；采样数组仅存在于测试。

## 验证

- 修复前先运行tests/ui_motion.lua中的43点镜像对照：在关闭sample 1失败。修复后43点位置和可见透明度全部倒序相等；最后隐藏帧按实际不可见状态比较。
- 额外覆盖150ms开场→回退50ms→前进50ms，应回到同一时间轴状态；剩余退场时长恰为已播放时间；同帧打开关闭立即完成。
- tests/ui_motion.lua、presence_geometry.lua、interaction_smoke.lua及完整tests/check_contract.ps1通过；完整日志`%TEMP%\lychee-reverse-presence-check.log`。
- 1000轮累计分配179.69KiB，Frame/组增长0，结束无活动回调。关闭采样延长至51×1/120秒以覆盖420ms全程，不能与旧短退出循环的CPU数字作等量比较。
- API未新增；GetTimePreciseSec重新经wowdoc查询确认：wow-ui-source / retail / latest / 8ea15b61e45c0ed4eba01439c90757f86eb78d34，Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua:27，返回seconds:number。SetPoint/SetAlpha/SetScript证据沿用2026-09-12-window-geometry-repair-wowdoc.json同版本。
- 同步目标为`D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`，提交后核对133个运行时文件及SHA256，旧文件保留。现有Lua修改只需/reload。回滚使用新的git revert。
- 离线镜像检查可证明轨迹关系；新的实际观感、不同帧率下字体/裁剪与战斗保护仍待客户端验证。
