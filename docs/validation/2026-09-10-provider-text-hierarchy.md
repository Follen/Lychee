# Provider 说明、示例与状态层级

基线 2eb5ba5。用途保留 meta 次级文字；输入示例使用独立 meta 标签及主文字色实际输入，移除重复箭头说明；未设置移到标题右侧操作区，空配置隐藏示例。关键词文案改为查看结果，不暗示全部列表。中文、英文和 DESIGN.md 同步。

只在首次进入详情增加4个固定 FontString（两个示例标签、两个状态标签），无新 Frame、事件、timer 或热路径扫描。布局键增加两个已配置状态，保存后更新布局；打字不额外重排。现有20次重开编辑池零增长回归通过。

验证：check_contract.ps1 全部通过（含 Lua/XML/TOC、语言与性能门禁）；interaction_smoke 增加未配置、保存与清空状态转换检查；git diff --check 通过。wowdoc validate retail 检查71 Lua，valid=true，无诊断。日志位于 .codex/provider-hierarchy-full.txt 和 provider-hierarchy-validate.json。

API 依据：sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。source list/check 后查询 SetJustifyH，Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:560–568，Name="SetJustifyH"，justifyH 类型 JustifyHorizontal。证据 .codex/provider-hierarchy-api.json。

游戏内字体、缩放、对齐尚待 /reload 实机确认；用户截图为修改前版本，不作新版本视觉验收。无常驻行为变化，本轮未进行游戏 CPU 测量。
