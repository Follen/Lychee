# 搜索面板与提示框视觉调整

日期：2026-09-10。基线运行时提交：51c8320；文档基线：a61fabc。依据为用户提供的搜索结果与提示框两张实机截图，反馈是视觉粗重、难看。

## 实现

- 保留黑红配色、原始荔枝标志、640 宽搜索布局、单选反馈和原有交互。
- 选中行改为暗中性色与 1 × 22 短红线，移除整圈红框。顶部 64 → 56、底栏 32 → 28；顶部横线移除，底栏分隔线减弱并内缩。
- 自有文本区域使用 STANDARD_TEXT_FONT，清除文字描边/继承阴影。输入 16、标题 14、说明 12、分类与状态 11。
- 自有提示框替代全局 GameTooltip：一个延迟创建的 Frame、五个可复用 FontString、固定宽度与动态文本高度。标题、类型、说明和操作区分层，操作提示使用次要文字色。
- 搜索行、最近使用、次要技能动作共享提示框。离开、结果替换/失效、关闭时隐藏并释放 owner；战斗中拒绝显示。不会修改全局 GameTooltip 或共享 GameFont。

## 验证结果

- pwsh -NoProfile -File tests/check_contract.ps1：10 项全部通过。
- luac -p：45 个运行时、SDK、测试 Lua 文件通过。
- Bindings.xml 解析通过。
- wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest：valid=true，checkedLua=30，diagnostics=null。
- 回归覆盖提示框复用、全局样式隔离、长说明高度、内容缩短后收缩、换结果隐藏、单一选中状态，以及原有菜单、最近使用、战斗/安全按钮模拟。
- git diff --check：清理测试末尾空行后通过。

## WoW API 证据

sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。source check 确認本地与远端相同。

[查档原始记录](../architecture/2026-09-10-ui-refinement-wowdoc.json) 保存 path、line、excerpt。包括 SimpleFontStringAPIDocumentation.lua 的 SetFont（500）、SetShadowOffset（633）、GetStringHeight（325）；SimpleFrameAPIDocumentation.lua 的 SetClampedToScreen（1206）和 SetFrameStrata（1292）；SetPoint、SetParent 的生成 API 记录。所有修改前已读取对应证据。

[修改后静态验证](../architecture/2026-09-10-ui-refinement-validate.json)。

## 性能与证据边界

提示框仅在首次悬停创建，后续复用；只在悬停/内容变化时测量最多五段文字，不增加 timer、事件或 OnUpdate。移除八个结果行的八个描边 Frame 与 32 个描边纹理；首次提示后增加一个 Frame、五个 FontString、八个背景/分隔纹理（按代码对象数，不是客户端采样）。重复悬停对象数不变、相同结果无 setter churn 由离线测试验证。

尚未取得修改后的实机截图、真实文字测量、不同 UI 缩放及屏幕边缘定位证据；离线 GetStringHeight 为测试替身。真实战斗/taint、安全点击和 CPU、内存、帧时间仍须在客户端验证，不能用静态通过代替。

本次不改 TOC 或新增模块，提交成功并同步后可通过 /reload 加载。同步只覆盖 package/Lychee 运行时，核对全量文件清单和 SHA-256。回滚使用新 git revert 提交后按相同流程验证、同步。
