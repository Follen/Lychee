# 插件识别：补齐与 /fstack 的取目标差异

## 问题与修复

修复前基线：`c8320d9`。用户截图中，`/fstack` 已指出 Exwind 文字层和 EUI 冷却图标的创建位置，Lychee 却保留初始提示，Shift 下还展开空白详情。

旧实现仅检查 `GetMouseFoci()[1]`。不接收鼠标输入的可见区域可能不在这个列表中；第一项无效时也不会检查其余项。最小回归设置可见的 Exwind FontString、空鼠标焦点列表，在修改运行时代码前执行 `lua tests/addon_inspector.lua`，失败于：

```text
visible non-mouse text layer must be identified like /fstack, not leave the introductory empty panel
```

现在由私有 GameTooltip 的 `SetFrameStack(false, true, 0)` 取可见目标，包含文字与纹理；仍由实际创建位置和插件元数据动态解析来源。接口缺失或调用失败时回退到最多 32 个鼠标焦点，过滤根框体、受限目标和自身控件。没有修改外部插件，也没有接管 `FrameStackTooltip`、`fsobj` 或调试 CVar。

自身轮廓在单次同步取样期间隐藏，结束后恢复，避免选中自己的装饰层。按住 Shift 时先取得有效目标再冻结；没有目标时不显示空详情。其余布局、跟随距离、搜索协议和 SDK 不变。

## wowdoc 版本证据

以下证据统一使用：

- `sourceId`: `wow-ui-source`
- `product`: `retail`
- `requestedRef`: `latest`
- `resolvedCommit`: `8ea15b61e45c0ed4eba01439c90757f86eb78d34`
- 本轮已执行 `source list` / `source check`，本地与远端一致。

| path | line | excerpt / 用途 |
| --- | --- | --- |
| `Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.lua` | 226 | `FRAMESTACK_UPDATE_TIME = .1`；官方刷新周期 |
| 同上 | 234 | `self.highlightFrame = self:SetFrameStack(self.showHidden, self.showRegions, self.highlightIndexChanged);`；返回待高亮的目标 |
| `Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.xml` | 4 | `<GameTooltip name="FrameStackTooltip" ... inherits="SharedTooltipTemplate" ...>`；官方取样对象与模板 |
| `Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.xml` | 95 | `<GameTooltip name="SharedTooltipTemplate" inherits="SharedTooltipArtTemplate" ... hidden="true" virtual="true">`；复用公共基础模板，不加载调试窗口脚本 |
| `Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua` | 9 | `function SharedTooltip_OnLoad(self)`；设置背景、字体、边界，不依赖全局调试窗口 |
| 同上 | 22 | `function SharedTooltip_OnHide(self)`；清理 padding，不接管调试状态 |

本次依据覆盖正式服。其他客户端的接口缺失回退由离线测试覆盖，不等同于这些客户端已完成实机验收。

## 生命周期与成本

- 保留原预算：首次创建不超过 16 个 Frame 替身、48 个 Region 替身、512 KiB Lua 保留量；100 次开关累计分配小于 1 MiB、保留增长小于 64 KiB；10,000 次跟随分配小于 128 KiB。没有提高原有门槛。
- 默认关闭；未开启识别时不创建取样框、不扫描。首次进入复用既有信息窗并新增一个私有 GameTooltip；后续开关复用同一对象。
- 活动模式每 0.1 秒最多调用一次原生取样。Shift 锁定有效目标和复制期间不取样；仅无目标的 Shift 状态继续寻找首个目标。始终只有一个识别定时任务，无积压队列。
- 每帧仅更新指针位置与 Shift 状态；来源只在目标改变时解析，父级最多 16 层。回退鼠标焦点最多检查 32 个。
- 关闭、禁用、Esc、战斗均停止定时器与跟随，清理当前目标、文字、报告和轮廓锚点；晚到的旧回调不能重启取样。战斗内不运行原生扫描，脱战不自动恢复。
- 取样框归 Provider 所有，保留供复用，每次使用后隐藏并清空文字。没有新增随访问目标数量增长的 Lua 索引。
- **成本限制**：`SetFrameStack` 是不可由 Lua 分片的原生扫描，实际工作量取决于客户端框体堆栈。GameTooltip 模板及内部动态文字区域也有引擎成本。下面的替身数量、耗时和内存均不包含这些成本，不作游戏性能已达标的结论。

## 验证结果

`lua tests/addon_inspector.lua`：通过。

覆盖 Exwind FontString、EUI Texture、精确创建路径与复制内容、自身控件保持目标、取样时隐藏自身轮廓、secret 目标、接口缺失、多焦点回退、临时失败后恢复、Shift 启动、空白处 Shift、冻结后停止扫描、Esc／禁用／战斗、旧回调、原有来源推断与边界布局。

Lua 5.1 离线一次完整检查中的观测值：

```text
Pointer10000 ms=8.00 allocated_KiB=0.0 source_reads=0 redundant_setters=0
frames=8 regions=35 retained_KiB=36.1
cycles100_ms=3.00 allocated_KiB=345.7 growth_KiB=0.5 idle_work=0
```

这是固定替身场景的正确性与预算验证，样本不足以推断尾延迟或帧率改善。相比旧路径，新增原生取样有实际代价；本轮没有可用的游戏内前后性能测量。

- `powershell -NoProfile -File tests/check_contract.ps1`：全部通过，包含四客户端 TOC、Lua 加载、UI 交互、Provider、搜索与性能预算。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：`checkedLua=75`、`valid=true`、无诊断。
- `git diff --check`：通过。

## 实机待验

这次未改 TOC 或加载顺序，同步后 `/reload`。分别指向截图里的 Exwind 文字层和 EUI 冷却图标，对照 `/fstack` 的实际目标与创建位置；按 Shift、松开、复制、Esc，再测试同时开启 `/fstack`。

游戏实测仍需覆盖密集界面堆栈的单次扫描峰值、首次取样延迟、反复切换目标后的提示框区域高水位，以及进入战斗／关闭后零活动状态。离线替身不能验证真实拾取优先级、原生受限调用、taint 或渲染表现。回滚使用新的 `git revert` 并按相同校验和同步流程交付。
