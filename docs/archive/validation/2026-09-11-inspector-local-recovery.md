# 原生命中后的局部补选与聊天裁剪

基线：9a8cf525a21fbed44b1bc9232751cefb7e91256e。

用户同次取样证据为 `LY true <对象名> nil`，对象分别为
`EllesmereUIPlayerAuraBars_Buffs.*`、`ERB_SecondaryFrame._countTextOverlay`、
`EllesmereUIUnitFrames_Player._raidMarkerHolder`。证明原生接口返回对象，过滤未产出目标；
不能再把这个症状当作来源归属失败。另有聊天文字在实际显示区域外仍被勾选的截图。

## 原因和边界

EUI 的文字、边框、队伍标记载体铺满父框体，但鼠标位置未必有任何绘制内容。
原过滤排除空载体是正确的，缺口是排除后仅依赖另一原生列表，没有局部恢复。
现在先保留通过过滤的原生对象；否则只在其附近最多三个祖先范围内检查三层子框体，
返回有真实可见 Region 命中的对象。不会将空载体直接判为可见，也不写死 EUI 名称。
不进入 UIParent/WorldFrame，隐藏、透明、禁止访问、空内容、裁剪过滤继续生效。

聊天裁剪检查此前从绘制 Frame 的父级开始，漏掉直接承载 FontString 的 Frame。
从该 Frame 自身开始检查，覆盖暴雪 FontStringContainer 的 clipChildren。
截图不证明淡出实现出错，已确认的代码缺口是直接父级裁剪遗漏；完全淡出的文字继续排除。

## 版本证据

- sourceId `wow-ui-source`，product `retail`，requestedRef `latest`，resolvedCommit
  `8ea15b61e45c0ed4eba01439c90757f86eb78d34`；source list/check 无更新。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:188`
  `DoesClipChildren` 返回 `clipsChildren` bool；`:323` `GetChildren` 返回 SimpleFrame 可变参数，
  带 Hierarchy secret 限制；`:366` `GetEffectiveAlpha` 带 Alpha 访问限制。
- `Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.xml:9`：
  `parentKey="FontStringContainer" clipChildren="true" ... setAllPoints="true"`。
- 同目录 `ScrollingMessageFrame.lua:709`：`CreateFontStringPool(self.FontStringContainer, ...)`；
  `RefreshDisplay` 对聊天行执行 `SetAlpha(alpha)` / `SetShown(alpha > 0)`。
- sourceId `ellesmereui`，product `main`，requestedRef `9.1.8`，matchedTag `v9.1.8`，
  resolvedCommit `271ffc30d3265d9f77746b0e15224d918f0fafcb`，source check 无更新。
  本机该版 `EllesmereUIUnitFrames/EllesmereUIUnitFrames.lua:7131–7149`：
  raidIconHolder SetAllPoints(frame)，其 raidIcon 可以 Hide；
  `EllesmereUIResourceBars/EllesmereUIResourceBars.lua:3808–3823`：countTextOverlay
  SetAllPoints(secondaryFrame)，只有居中的 FontString；
  `EllesmereUI/EllesmereUI_AuraKit.lua:1024–1054`：borderHost、dispelHolder、stackCarrier
  均为覆盖整个 aura button 的框体。这些结构用于回归输入，不用于运行时名称匹配。

## 成本与生命周期

沿用活动期 0.1 秒单定时器和一次 SetFrameStack。仅原生对象过滤失败时触发补选，
每次共享 64 框体上限、每组 32 children / 32 regions，上下各三层；
0.75 ms 在框体边界停止，单个原生调用无法抢占。其后备用列表仍有独立 0.75 ms / 128 候选界限。
不创建 UI、表缓存或闭包；临时计数标量本次结束清空。局部结果成功则不取备用列表。
暂停、关闭、禁用、战斗沿用现有停止机制，未启用不运行。
固定 100 次补选累计分配预算 1 MiB，新增框体为零，关闭后零活动工作。

## 验证

- 先增加实际 Provider 路径回归，旧实现失败：
  `tests/addon_inspector.lua:215: empty native overlay must recover the visible sibling beneath it`。
- 修复后 `lua tests/addon_inspector.lua` 通过：空覆盖层恢复可见兄弟、隐藏父级、
  空内容、循环子框体有界、直接父级裁剪、裁剪内文字、完全淡出文字。
- 固定离线 Lua 5.1：LocalRecovery100 7 ms / 5.0 KiB 累计分配 / 0 次备用列表读取；
  NativePreferred100 1 ms / 0 KiB；NativeStack128×100 64 ms、最大单次 2 ms；
  100 次启停无保留增长、0 空闲工作。不是客户端性能结论。
- 完整 `tests/check_contract.ps1` 通过；wowdoc validate 75 Lua、valid=true、无 diagnostics；
  git diff --check 通过。
- 实机原截图位置、快速移动、UI 缩放、光环更新及客户端帧时间仍待 /reload 验证。
  游戏中的 secret 值或特殊绘制仍可能使安全读取失败；不以离线测试宣称全部目标已识别。

回滚使用新 git revert 提交，再按正式服同步流程覆盖复制，不改写历史。
