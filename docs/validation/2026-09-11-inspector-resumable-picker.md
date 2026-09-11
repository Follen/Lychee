# 插件识别：统一可续接候选队列

基线 `1c05043b5fb107ae7adb105fe9b4b1c1ff2fdcc6`。
用户仍提供了原生 FontString 命中、过滤结果 nil 的运行时证据。
该截图未包含具体属性值，因此不能宣称已经证明它是哪一项过滤失败。
本轮解决已复现的算法缺陷，并补齐同一轮取样的诊断出口。

## 先复现再修改

`lua tests/addon_inspector.lua` 在旧实现失败：
`budget exhaustion must resume rather than starve the end of the native stack`。
固定假时钟每次增加 0.8 ms，列表开头 20 个空载体，最后一个可见图标，
连续 40 次 Poll 仍找不到末尾目标：预算每次耗尽，下一次又从头扫描。
这个测试验证队列公平性，不冒充实际 WoW 取样数据。

## 算法

保留有效原生命中优先；删除三层局部递归扫描，将祖先、原生列表、子 Frame、
Region 纳入唯一有界去重队列。同一评估函数验证内容、alpha、位置、裁剪、可访问性，
同一评分规则比较候选。原始 Frame 有可见区域时保留其身份；大于 32 个 Region
时，后续区域作为普通工作项进入队列，不再被直接忽略。

时间预算只控制单批，进度不会重置；鼠标或原生命中变化才取消未完成的一轮。
已找到目标逐批发布，但每次重验，且不让上一轮列表外的旧结果覆盖新列表。
完成一轮后释放候选引用，下一轮刷新动态 UI。

隐藏、全透明、空锚点、直接父容器裁剪、GameTooltip 排除继续生效。
读取失败分别记 geometry/text/color/alpha/level 等原因，不能当成确定空内容。
诊断只反映当前过滤过程，不改变源框体，不添加名称特例。

## 成本及生命周期

- 活动期仍一个 0.1 秒 timer、每次一次 SetFrameStack；原生选择成功不用队列。
- 单轮最多 512 个唯一对象；最多 16 个祖先；单批最多 128 个对象 / 0.75 ms，
  在对象边界让出，非硬实时抢占。原生取样、列表生成、一次方法调用不能抢占。
- 每组加入最多 512 个返回值，受同一总容量约束；不全局 EnumerateFrames。
- 队列、去重表、原因表首次 fallback 懒建并复用；容量满记录 capped。
  完成时清除 queue/seen 的对象引用，保留本轮诊断标量、原生命中和一个结果。
- 指针移动不保留旧结果；每次重新检查旧结果的显示、透明度和几何条件。
- Shift 锁定目标或失败报告、复制时暂停；关闭、禁用、战斗释放状态；空闲零工作。
- 既有预算：100 次固定操作累计分配 <1 MiB；额外 Frame 数零；关闭后无保留增长。
  新的 512 容量明确替代旧的 128 总候选截断。队列达到上限不声称扫描完整。

## 版本证据

sourceId `wow-ui-source`，product `retail`，requestedRef `latest`，resolvedCommit
`8ea15b61e45c0ed4eba01439c90757f86eb78d34`，source check 无更新。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua:11`：
  `GetFrameStack` 返回 `objects`，table / ScriptRegion。
- `SimpleFrameAPIDocumentation.lua:323`：GetChildren 返回 SimpleFrame 可变参数，Hierarchy secret；
  `:576` GetRegions；`:366` GetEffectiveAlpha 受 Alpha 访问控制；`:188` DoesClipChildren。
- `SimpleScriptRegionAPIDocumentation.lua:169`：GetRect 返回矩形且可能无返回值，具有 anchoring 限制。
- `Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.lua:234`：
  `self.highlightFrame = self:SetFrameStack(self.showHidden, self.showRegions, self.highlightIndexChanged)`。
- 直接父级裁剪依据沿用上一份验证记录的 ScrollingMessageFrame.xml:9 / lua:709。

## 验证结果

- 专项测试通过：预算续接、鼠标移动取消、大于 32 个 Region 的可见文字、
  secret 文本记录为不可读、空覆盖层、隐藏/透明、裁剪、循环图有界、
  512 个不同候选容量与 capped、无目标时 Shift 复制诊断、Shift/退出/战斗。
- 离线 Lua 5.1：原生有效 100 次 2 ms / 0 KiB；统一恢复 100 次 9 ms / 6.0 KiB。
  128 输入（含重复对象）×100 次 8 ms、最大单次 1 ms、199.1 KiB 累计分配。
  去重减少重复对象检查；不能由这组重复样本推断所有场景的速度提升。
- 100 次启停 4 ms / 302.6 KiB，未观察到保留增长；初始替身对象仍 9 Frame / 35 Region，
  关闭后 0 活动工作。假时钟只用于确定性正确性测试，成本使用真实离线计时。
- `tests/check_contract.ps1` 全部通过，wowdoc validate：75 Lua，valid=true，无 diagnostics。
  `git diff --check` 通过。

实机尚待验证：用户截图中的菜单文字、EUI 冷却/光环/资源条、快速移动、光环更新、
不同缩放和复杂插件组合；真实首结果延迟、完整 sweep 时间、帧时间、secret 访问路径。
如果仍无目标，用界面 Shift → 复制信息取得当前轮报告，无需再编写临时宏。
本轮没有声称所有第三方框体均已可识别。

回滚用新 git revert 提交，验证后按正式服同步流程复制。
