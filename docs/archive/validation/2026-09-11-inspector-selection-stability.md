# 候选轮次和覆盖层切换时的稳定性

基线 523413d11af7b4f666e1fc64173d5466c8969ca8。
用户提供 EUI 次级资源条、玩家 Aura、Rurutia 聊天按钮的 /fstack 截图，
原生高亮分别指向文字覆盖层、AuraContainer 和按钮/装饰层。
图中来源包括 EllesmereUIResourceBars.lua:3809、EllesmereUI_AuraKit.lua:1321、
RurutiaSuite/Core/UILib.lua:206、EUI_UnitFrames_WeaponEnchants.lua:113。
这些截图说明目标由多层控件组成；不能由静态截图断言具体运行时过滤原因。

## 已复现的问题

1. 原生高亮在同一控件的空覆盖层之间交替会取消未完成的 sweep，反复从头检查。
2. 上轮找到的子控件尚未被新一轮展开时，不在初始 seen 中，结果先被清空再重新出现。
3. 为解决第二条保留结果时，还必须区分新原生种子与内部展开区域；后者不能仅因同分
   就把 Frame 替换为其 Texture，造成身份来回切换。
4. pending / complete 每轮触发 UI Update，两个内部状态文案反复跳动。

修改前 `lua tests/addon_inspector.lua` 分别失败：
`pending and complete sweeps must not alternate the visible empty-state hint`；
`changing native overlay at the same pointer must not restart and starve the sweep`。

## 修复

- 同坐标且新原生命中属于当前已入队对象/其后代时，继续本轮。鼠标移动、切入无关
  控件仍作废重建，完成后刷新种子。关系检查最多 16 层，不进入 UIParent / WorldFrame。
- 上轮结果可以通过已入队祖先证明属于本轮范围，但每次仍重新检查可见性、alpha、
  位置和裁剪；绝不靠延时显示已经隐藏的内容。
- 保存 seedTail，将原生种子与内部展开项区分。同分的新种子可替换上轮结果，
  同分内部区域不会让已有 Frame/Region 身份互换；更高排序结果仍正常获胜。
- 主界面只显示稳定的“暂未识别此处界面”；进度和原因保留在 Shift 复制报告里。
  单纯轮次切换不再触发视图 Update / Layout。

## 来源和成本

沿用 wowdoc 的 wow-ui-source / retail / latest，resolvedCommit
8ea15b61e45c0ed4eba01439c90757f86eb78d34，source check 无更新。
本轮 inspect SimpleFontStringAPIDocumentation.lua:664 SetText，支持 cstring，带 Text aspect。
父级和取样 API 证据沿用前两份记录；未增加新 Blizzard API 或更改加载顺序。
本机 UILib.lua:206 为 BackdropTemplate Button，带 Center/Text；AuraKit.lua:1321
为原生 AuraContainer；这些来源只用于构造测试，不作为运行时名称映射。

活动期仍 0.1 秒、每次一次原生取样，总容量 512、单批 128 / 0.75 ms 不变。
新增两个复用标量和最多两次 16 层祖先成员检查；不新增 UI、timer、缓存表或扫描范围。
关闭时标量与候选一起清理。成员检查不证明可见性，也不替代现有隐藏过滤。

## 验证

- 模拟同一控件 OverlayA/OverlayB 交替 20 次能找到真实内容，随后跨轮 30 次保持结果；
  内容 Hide 后下一次 Poll 立即清除。旧实现对此失败。
- 30 次空候选轮次交替保持相同提示；原生候选同分优先、无关控件切换、源信息复制、
  队列预算续接、鼠标移动取消、alpha/裁剪/战斗/关闭回归全部通过。
- 离线 Lua 5.1：有效原生 100 次 2 ms / 0 KiB；统一恢复 100 次 12 ms / 6 KiB；
  原生 128 输入×100 次 8 ms、最大单次 1 ms、203.1 KiB；100 次启停 6 ms /
  302.6 KiB，未观察到保留增长，空闲 0 活动工作。与上轮相同口径的成员检查增加固定开销，
  不从离线计时推断游戏帧率。
- 完整 check_contract.ps1、wowdoc validate（75 Lua、无 diagnostics）、diff check 通过。
- 游戏中这三个控件的真实行为、复杂 UI 动态更新、缩放和帧时间仍待 /reload 验证。
  没有声称截图中的所有不可读属性均已解决。

回滚采用新 git revert 提交后按规定同步，不改写历史。
