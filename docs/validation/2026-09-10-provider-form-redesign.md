# Provider 配置表单重构

基线 9ae6b0a。将纵向说明层级改为两列配置表单：左列设置名，右列展示所有实际词及紧随其后的编辑动作；空配置为添加按钮。版本信息与恢复默认并列跟随正文。输入编辑原位替换配置，保留已有按项保存和即时开关。中英文、DESIGN.md同步；搜索策略和SDK协议没有变化。

## 成本和生命周期

首用懒创建两个各8项的只读词条池，新增16个固定Frame；重开／编辑不再创建。每词沿用策略48字节上限，标签依据当前字体测量宽度，单次最多16词，无输入热路径测量。已复用短词换成长词前先解除旧宽约束再测量。全配置键变化触发布局，词条限于值列，6间距、34换行步长；没有新订阅、timer或OnUpdate。关闭停止拖动、清焦点并失效交互身份。固定池保留用于复用，非无限增长缓存。

## 已执行

- tests/check_contract.ps1 全部通过，含Lua/XML/TOC、i18n、搜索与性能预算。
- interaction_smoke 保留即时开关、保存取消、恢复默认、不可访问配置拒绝、失效点击、独立来源和关闭回归；增加8个长词完整可见及换行边界检查，清空回到添加操作，20次重开并编辑取消池零增长。
- wowdoc validate retail：71 Lua，valid=true，无诊断。
- git diff --check 通过。
- 证据日志：.codex/provider-redesign-full.txt、provider-redesign-interaction.txt、provider-redesign-validate.json。

## wowdoc依据

source list/check后查询GetStringWidth；sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。
Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:339–351：Name="GetStringWidth"，返回width类型uiUnit。本页面只测量插件自身静态配置文字。证据 .codex/provider-redesign-api.json。

## 待验证与局限

用户截图是旧布局；本轮无游戏内新截图，实际字体、UI缩放、鼠标反馈和极端长文案待/reload检查。离线几何测试不替代实机渲染或性能测量。本次仅改低频设置UI，未测登录／团本场景CPU，不宣称帧率收益。完整搜索预算通过不用于估算新增词条的引擎内存。
