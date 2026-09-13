# 列表弹出后的键盘选择与滚动修复

基线：821819df8464a59f1424947e84d2b71f6bf50c77。修复三项审计问题：入场结束覆盖键盘选择、首页键盘选中项不可见、空输入筛选结果的键盘操作被路由到隐藏首页。

## 行为与成本

- 方向键使本次延迟悬停失效，以既有目标字段的 false 值表达；直到入场结束前不再保存经过鼠标的行。FinishShow 与 Hide 沿用清理逻辑，下次打开不继承此状态。没有新增缓存、事件、timer、Frame 或逐帧工作。
- 首页 Move 在完成选择后，读取当前行既有 TOPLEFT 锚点及行、视口高度；只有上下边界超出视口时才调用既有 SetScroll。该路径不新增表或闭包，滚动保持原有边界钳制与战斗保护；鼠标选择不主动滚动。最多处理一个选中行，既有选择绘制与不可用项查找上限不变（64 固定项、5 最近使用）。
- 方向键与回车按当前可见的首页/结果页分发，空文本不再代表首页；没有改变 Provider、查询语义或持久存储。
- 沿用 PERFORMANCE.md 原有加载、交互峰值、分配和对象池预算，不放宽阈值。变更前最近一次完整五包加载为1834.1279 KiB，不含LDT正式服为1472.0596 KiB；前次交互峰值波动的原始证据保留于此前弹出验收记录。

## 回归与原生证据

正式新增三项 ui.popup_keyboard_* 回归，使用实际 Input 事件、Provider、SearchSession、Palette 和 HomeView，替换原生框体/几何、鼠标投递及时间。入场通过真实 Presence OnUpdate 完成，不直接调用 FinishShow。

旧实现三项全部失败，原始报告 analyze/ui-popup-audit/before-fix.json：键盘第2项被改回第1项；末行442–488位于0–430视口外；筛选结果保持第1项，隐藏首页变为第2项，回车不执行可见结果。修复后末行视口调整为58–488；筛选方向键选中第2项并正确执行。

补充覆盖入场期间晚到悬停不抢选择、入场后新悬停、重新打开清理、向上滚动与列表边界、跳过不可用项、鼠标选择不滚动，以及正常文本搜索。首次补充对照脚本错误地假定普通动作必定关闭面板，已改为显式关闭再打开；失败报告 edge-cases.json 保留，不归因为插件新问题。

本轮 wowdoc source list/check 后固定 sourceId=wow-ui-source、product=retail、requestedRef=12.1.0、matchedTag=12.1.0、resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；不把远端 latest 漂移混入本次接口依据。精确原始输出保存在 analyze/ui-popup-audit/wowdoc.json。

| path | line | excerpt |
| --- | --- | --- |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua | 65 | GetPoint(anchorIndex, resolveCollapsed)；返回 point、relativeTo、relativePoint、offsetX、offsetY，可无返回值 |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua | 103 | SetVerticalScroll(offset:uiUnit)，IsProtectedFunction=true；继续经非战斗 SetScroll 调用 |

## 完整验收与交付

- `python tests/run.py --report analyze/ui-popup-audit/full.json`：97/97通过，包含新增三项、既有生命周期/交互/战斗/动效、Lua/XML/Python静态检查、SDK/TOC/发布清单及全部性能门禁。
- 本轮100次最近使用交互为256ms总量、4ms峰值，累计分配24137.4KiB，未观察到保留增长，零新增框体。前次验收中的5/6ms计时波动没有通过本次单次通过得到解释，不宣称实机峰值改善。
- 完整五包加载1834.7021KiB/26ms，不含LDT正式服1472.6338KiB/22ms，各2Frame/4事件登记；相较上一交付各增加0.5742KiB，均满足原预算。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44个Lua文件，valid=true，无诊断；文档检查与git diff --check通过。
- 提交后按五包180文件发布清单覆盖复制，逐项核对SHA-256，保留目标旧文件。最终提交hash及同步结果记录于 analyze/ui-popup-audit/sync.json，不将分析、测试、SDK或文档复制入游戏。

无新增模块、TOC 或加载顺序变化；同步后使用 /reload。离线结果不代表游戏内像素、原生命中顺序、战斗安全与 taint 已验收。
