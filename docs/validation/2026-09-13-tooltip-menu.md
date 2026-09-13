# Tooltip 跟随与右键菜单标识

## 变更与原因

- 用户截图中的提示固定在条目右侧，与旧 `ShowTooltip` 的入口右上锚点一致。新回归在同一条目内移动鼠标，旧实现以 `tooltip must follow cursor movement within the same hovered entry` 失败。
- 共用提示改为按有效缩放跟随鼠标，默认右上偏移12，接近右侧/顶部翻转，保留原生屏幕夹取及 UIParent 防裁剪。隐藏、旧 owner 离开、结果重绑、窗口关闭和战斗清理均有覆盖。
- 右键菜单增加本地化“菜单 / Menu”标题，使用已有 game-menu 资源的20方形行内图标。标题无动作，操作从顶部44处开始；18个动作上限、点击身份与安全技能准备流程不变。
- 为维持原冷加载预算，在同一组件文件合并重复底面构造、文字/显示方法、浮层/字体初始化与按钮状态转发；删除与底层同值 setter 重复的私有缓存。跟随回调在首次提示创建时实例化。没有调整性能阈值、目录数据或公开 SDK。
- 测试夹具补齐根尺寸、有效缩放与鼠标坐标；原动画断言改为比较实际应用缩放，而非因缺失根接口得到的常数1。冷加载用例在断言前打印精确指标，保留原测量范围和阈值。

## 成本与生命周期

- 所有者：Components 单例。首次悬停创建一个复用 tooltip；既有五个文本区域、长说明滚动区和有界表格不扩容。菜单只多一个标题 FontString，行内图标复用现有纹理文件。
- 每活动帧只处理当前一个提示的坐标，O(1)，不扫描列表、不重建文本；坐标相同不调用定位 setter。无新 timer/事件。关闭或中断解除 OnUpdate、清 owner 和坐标缓存；无活动提示时没有跟随工作。控件结构保留复用，不写 SV。
- 预设门槛：沿用冷加载基线 <1474 KiB / <46 ms；静止1000帧额外分配 <64 KiB、零新增对象；所有既有生命周期和交互预算保持。
- 初版新增成本导致冷加载1476.9 KiB失败。相同源路径的修改前测量约1474.0 KiB（当时输出保留1位小数）；最终精确值1473.9736 KiB、20 ms、2个Frame/4个事件登记。预算余量很小，不能据此声称显著内存收益。
- 最终静止1000帧分配0.00 KiB、零新增对象；开关100次复测252 ms总计、4 ms最大单轮、零新增框体、未观察到保留增长。都是 Lua 5.1 离线替身口径，不包含引擎纹理内存。

## 版本化 WoW 证据

以下均为 `sourceId=wow-ui-source`，`product=retail`，`requestedRef=12.1.0`，`matchedTag=12.1.0`，`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。先执行 source list/check；远端有更新，但本次按项目120100目标固定取证。

| path | line | excerpt / 用途 |
| --- | --- | --- |
| Interface/AddOns/Blizzard_SharedXML/InputUtil.lua | 12 | `InputUtil.GetCursorPosition(parent)`：读取 `GetCursorPosition()`、`parent:GetEffectiveScale()`，返回 `x / scale, y / scale`。 |
| Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerDraggedItemBase.lua | 5 | `CooldownViewerDraggedItemBaseMixin:OnUpdate()` 读取缩放后的鼠标位置，以 `SetPoint("TOPLEFT", topLevel, "BOTTOMLEFT", x, y)` 更新跟随位置。 |
| Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameConstants.lua | 31 | `ICON_LIST` 使用 `|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:` 纹理标记；标题复用相同行内纹理机制。 |

## 验证结果

- `lua tests/ui/result_list_ui_smoke.lua`：旧实现红；最终鼠标移动、根缩放变化、屏幕边缘、静止跳过setter、防裁剪、旧owner、直接隐藏、战斗、复用与菜单身份通过。
- `python tests/run.py --report analyze/tests/tooltip-menu-final.json`：完整执行93项，92通过；唯一失败为 `ui.interaction_smoke` 的5.000 ms样本触及严格 <5 ms门槛。原失败保留，未改变阈值。
- `python tests/run.py --case ui.interaction_smoke --report analyze/tests/tooltip-menu-interaction-recheck.json`：同代码单独复测1/1通过，最大4.000 ms。完整检查覆盖与这次定向复测共同完成门禁，不将全量原报告改写成93/93。
- 全量入口包含 Lua/XML/Python 静态解析、五包TOC/发布清单、SDK、本地化、UI和性能检查。`wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44份Lua，valid=true，无诊断。
- 原始日志位于忽略目录 `analyze/tests/tooltip-menu*.json`、`analyze/tests/tooltip-menu-final.log`。未交付临时基线副本、测试或分析数据。

## 实机待验证与交付

未操作客户端：需 `/reload` 后检查最近使用、搜索结果、小怪技能说明的跟随位置、不同UI缩放、屏幕边缘、长说明滚轮及右键标题外观；游戏内战斗/taint与CPU/纹理成本未测。无新增TOC或运行文件，本轮不要求重启。

按仓库规则仅提交本轮相关文件；同时出现的 PERFORMANCE.md、其SDK副本和性能来源文档整理属于并发工作，不纳入此提交。提交成功后按发布清单覆盖五个同名包，逐文件校验SHA-256，保留目标旧文件。实际提交hash与同步清单由交付结果记录；撤回使用新的git revert。
