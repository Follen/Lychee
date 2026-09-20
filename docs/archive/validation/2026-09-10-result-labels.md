# 搜索结果类型标签统一

日期：2026-09-10。用户实机截图显示技能结果右侧为蓝色“技能”，首领等结果没有标签。

根因是 ResultList 将右侧文案绑定 category 并使用 category.color；玩家技能定义了蓝色分类，其他内置 Provider 只有 kindTitle。修复统一在 Host 的结果渲染层完成：右侧和提示框类型文案优先 kindTitle，再回退分类显示名、Provider 显示名和“内容”；所有右侧标签在创建时应用 Theme.textDim、11 号字体，无描边。分类颜色数据不再控制这个标签的外观。

每次 SetItems 仍只处理最多八个可见行，沿用 cachedText；没有新增 Frame、事件、计时器或 OnUpdate。颜色在对象创建时设置，移除了逐结果分类颜色解析与缓存。沿用已有类型、分类和来源字段，不要求 Provider 增加声明或业务判断。

修改前 wowdoc source check 确认 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`，本地和远端均为 `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:675` 确认 SetTextColor 的 RGB/A 参数；path、line、excerpt 和版本见 [查询证据](../design/2026-09-10-result-labels-wowdoc.json)。使用既有 Theme 封装，仅设置自有 FontString。

结果列表离线测试覆盖技能、首领、游戏菜单、角色货币、本地化类型、分类回退、来源回退及无元数据回退；所有标签使用同一主题色和字号。原有重复刷新零 setter 变化、行复用、单字段增量更新、清理与提示框测试继续通过。

完整验证通过：11 组契约/交互测试；51 个 Lua 文件解析；Bindings XML 与 TOC 检查；wowdoc validate（35 个运行时 Lua、valid=true、零诊断）；git diff --check。结果见 [validate JSON](../design/2026-09-10-result-labels-validate.json)。这些验证不替代实机视觉和性能采样。

布局、字号和主题沿用现有界面，未取得修改后的实机截图或 CPU/帧时间采样。客户端 `/reload` 后应在同一“红玉”搜索下看到灰色“技能”和每行“首领”标签，菜单和纹章分别显示“游戏菜单”“角色货币”。

成功提交后同步至 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，核对运行时清单和 SHA-256。仅修改已有 Lua，不涉及 TOC 或新资源；`/reload` 可加载改动。
