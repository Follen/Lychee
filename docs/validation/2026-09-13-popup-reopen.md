# 列表重新打开时的布局与误悬停

用户提供 `C:/Users/follen/Videos/20260913-144923.mp4`（13.567秒）和 `20260913-141905.mp4`（6.367秒），均为1920×1080/30fps，并明确问题是“重新打开时跳动或错位”。中文输入期间的中间搜索结果不属于本轮修复范围。

逐帧检查14:49录像约4.8–5.4秒：窗口入场经过静止鼠标时，第一、第二条最近使用先后触发悬停，选中项和tooltip切换。抽样帧中背景、标题和行的位移一致，没有据此认定列表脱离根节点；原有入场轨迹保留。原始片段和诊断帧位于 analyze/video-list-popup，不作为运行资源交付。

## 复现与原因

- `lua analyze/video-list-popup/hover-repro.lua` 经完整关闭/打开并派发原生OnEnter边界事件，在旧实现的 `opening window must not pop tooltips for passing rows` 断言失败。首页、搜索行及安全覆盖层均没有入场悬停门禁。
- `lua tests/ui/popup_geometry.lua` 通过真实Provider、Palette、HomeView、Presence装配和有限原生几何替身，复现首次打开及最近使用变化后的首帧旧高度：旧Show先按已有首页内容定高，显示后才切换首页并重新定高；因此可能同时播放入场与高度动画。五条最近使用在该夹具下最终高度390。
- 同一回归发现首页内容高度已包含留白，滚动计算又从视口扣20，导致五条完整容纳的最近使用仍有20单位滚动范围；原测试没有按父级锚点推导实际视口尺寸，未覆盖这个问题。
- 后续用例在旧悬停身份判断下复现 `reused primary target transfers deferred hover to a different search result`；最终以InteractionBinding所属对象的交互代次校验，覆盖普通点击子框体和安全按钮，不能仅比较子框体上的空identity。

## 修复与生命周期

先恢复当前首页并在隐藏时定高，再显示和入场。移动期间不处理路过条目的悬停；Palette只保存最后一个目标及其交互代次，沿用Presence完成回调，在仍可见、鼠标仍在其上、未重绑且没有动作菜单时恢复一次OnEnter。此回调只恢复视觉，不模拟点击或施放。关闭清空目标和代次，快速反向不继承旧悬停；普通点击、键盘输入和既有安全点击检查保持。

首页滚动范围统一使用真实视口，不再重复扣除20。真实溢出仍可滚动并钳制边界；不改变固定项、最近使用容量或保存数据。DESIGN.md同步打开顺序、悬停恢复和滚动规范。

成本：增加两个控制器方法及有界状态，最多一个待处理悬停目标、一个代次标量；开场布局标记只在Show调用内使用。复用既有Presence驱动及完成回调，无新Frame/Region、动画组、事件或timer，无鼠标轮询。每次入场完成至多对一个仍有效的自有目标查询可见性、鼠标命中和脚本；关闭后无待处理目标。完整五包离线保留量由上一交付1831.6689增至1834.1279 KiB（约2.46 KiB），原预算不变。

## 验证与限制

- 新增并登记 `ui.popup_geometry`：冷打开、从搜索重新打开、最近使用数量变化、入场误悬停、安全覆盖层、普通搜索子目标重绑、离开、关闭、快速反向、右键菜单、真实点击和滚动边界通过。
- `python tests/run.py --report analyze/tests/popup-reopen-final.json`：最终94/94通过，含Lua/XML/Python解析、TOC/发布/SDK、既有动效/战斗/交互与性能检查。
- 首次全量为93/94，ui.interaction_smoke的100轮输入/清空峰值5.000ms，未满足严格<5ms。保留原报告 analyze/tests/popup-reopen.json。三组交替基线/新版测量的基线峰值均4ms，新版为4/6/4ms；正常完成的分配量均24137.4KiB、无新Frame、无保留增长。新版一次6ms失败日志也保留，不能凭最终通过宣称峰值问题已解释或消失。最终独立全量该项263ms总量、4ms峰值；未修改门槛，时延波动仍是验证限制。
- 最终不含LDT正式服加载1472.0596KiB/22ms，完整五包1834.1279KiB/26ms；各2Frame/4事件登记，通过原加载门槛。tooltip静止1000帧0.00KiB分配、零新对象。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44个Lua文件，valid=true，无诊断。文档与差异检查通过。

离线替身不证明原生像素、实际鼠标事件顺序或游戏战斗/taint结果。尚未取得修复后的实机录像，需 `/reload` 后重复“搜索 → 关闭 → 再打开”，分别把鼠标放在列表区域内外，并检查不同最近使用数量及快速反向。无TOC/模块变化，无须重启；提交后覆盖同步五包运行清单并核对SHA-256，保留旧文件。同步记录为 analyze/tests/popup-reopen-sync.json。

版本证据：本轮source list/check后固定 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=12.1.0`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

| path | line | excerpt |
| --- | --- | --- |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua | 470 | `IsMouseOver`，可选偏移默认0，返回`isMouseOver:bool` |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua | 968 | `IsVisible`返回`isVisible:bool` |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua | 220 | `GetScript(scriptTypeName, bindingType)`，默认Extrinsic，返回脚本引用 |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua | 124 | `SetHeight(height:uiUnit)`，受保护函数；仍只在非战斗路径设置自有框体 |
