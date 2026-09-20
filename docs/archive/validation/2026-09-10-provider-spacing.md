# Provider 操作对齐与留白

基线0b68787。编辑按钮固定在右侧，与开关右边界同为内容右侧8；词条为操作预留68宽，长词换行不撞按钮。空配置添加按钮保持值列左对齐。恢复默认右对齐。提示缩短，普通搜索起点76→60，前缀136→104，常态项步长92→76，版本区前额外12留白移除。单行词表展开版本时内容410→326，降低不必要滚动；长配置与错误仍按内容增加高度。

无新增对象、事件、timer或驱动。既有固定词条池和布局键不变。完整check_contract.ps1通过；interaction_smoke的词条边界检查收紧到编辑操作列左侧；wowdoc validate retail检查71 Lua，valid=true；git diff --check通过。日志.codex/provider-spacing-full.txt与provider-spacing-validate.json。

wowdoc source list/check后查询SetJustifyH。sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:560–568，Name="SetJustifyH"，justifyH类型JustifyHorizontal。证据.codex/provider-spacing-api.json。

游戏实际UI缩放、对齐和一屏显示待/reload确认，几何计算与离线通过不冒充实机截图或性能数据。
