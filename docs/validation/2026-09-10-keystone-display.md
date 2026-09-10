# 钥匙成绩与选择标记

用户截图中的搜索选择标记为 1×22，最近使用为 2×22；搜索改为 2×22。钥匙结果使用对应副本纹理，未知钥匙保留通用图标。角色使用完整名字和职业色，自己增加“我”标注。总分与单本分数使用 Blizzard 的两个评分颜色接口。

参考已安装 ExwindTools/Modules/NODISPLAY/ExM+InfoMythicFrame.lua:774–790（GetSeasonBestForMap、GetSpecificDungeonScoreRarityColor）及 ExM+Info.Tooltip.lua:175–188。独立实现展示，不复制其界面代码。版本证据见 2026-09-10-keystone-display-api.json，sourceId=wow-ui-source/product=retail/requestedRef=latest/resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

自己的记录优先显示 GetSeasonBestForMap 返回的限时层数，无限时记录才显示超时层数；队友依据 rating summary 的 finishedSuccess 和 bestRunLevel 明确标注。队友摘要不保证提供超时最佳记录之外的所有较低限时成绩，因此不将超时层数宣称为最高限时层数。未知数据不填零或猜测层数。

复用现有根级悬浮框，钥匙宽 416，普通条目恢复 280。副本、成绩、分数三列，25 行距，数字右对齐；最多 16 本加表头。首次需要时每行创建 3 个 FontString，当前 8 本共 27 个，之后复用；切回普通条目清空隐藏文字，不保留记录引用。无新 Frame、事件或计时器，无逐帧工作。既有隐藏与安全点击行为保留。

预算保持既有 Provider 4 MiB 常驻/100 查询分配、关闭零活动与 UI 有界复用门禁。预期只增加最多 5×16 个成绩元数据行及单个悬浮框最多 51 个文字对象。离线 fixture 常驻从 2220.3 到 2226.5 KiB，100 查询仍 3952.3 KiB，未观察到保留增长。游戏内文字对象与纹理成本不能从 Lua 替身推断。

验证：完整 check_contract.ps1、Lua 语法、XML 解析、wowdoc validate（44 Lua，无诊断）、git diff --check 通过。新增检查覆盖职业色、两种评分色、副本图标、自己限时 11/超时 12、队友超时、未知成绩、8 行表格与表头、重复悬浮不创建对象、普通悬浮恢复及红线尺寸。实机布局、不同 UI 缩放与队友数据到达仍待 /reload 验证；离线检查不冒充实机通过。

后续按用户要求去掉角色名后的括号自我标记，保留角色名与职业色；限时／超时逻辑不变。Provider 回归、Lua 语法及 wowdoc 校验通过。

后续按用户截图调整结果背景：surfaceHover 改为 RGB 0.09/0.09/0.09，surfaceSelected 改为 0.12/0.12/0.12，均不透明，去掉红色偏向；同步 ResultList 后备色与 DESIGN.md。仅常量变化，无新增对象或驱动；结果行交互、UI 性能、Lua 语法、wowdoc 校验通过。实机色感待 /reload 确认。
