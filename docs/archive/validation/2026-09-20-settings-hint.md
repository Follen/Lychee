# 首次使用设置入口提示 0.3.3

基线9476fda。第一次打开主窗口显示指向荔枝图标的轻量气泡，中英文文案，确认或进入设置后按账号保存一次性状态；未确认关闭后可重看。不在每次登录显示，不抢焦点。

存储：现有LycheeDB.settingsHintDismissed布尔值，由CharacterStore集中访问，UserPreferences提供语义入口。仅Registry ready后读写；保留其他账号字段，损坏根拒绝覆盖。角色设置、固定项与业务存档不变；这是明确的账号级新手引导偏好，不迁移角色设置。

成本：登录期无新Frame、事件、计时器；未确认首次打开创建固定一个气泡Frame与一个按钮及有限静态纹理/文字，之后复用；已确认的新会话不创建。目标为20轮无新增Frame、无持续保留增长；继承主窗口显示/战斗隐藏和缩放。正文与颜色复用Theme，Palette仅协调显示与确认，组件不读取存档。

离线回归覆盖zhCN、zhTW、enUS、enGB，首次打开、未确认重开、确认后20次重开、点击设置确认、模块重载、换角色、未ready和损坏根、战斗拒绝。原有CharacterStore所有权检查保持不变。完整契约、Lua解析、发布清单与四客户端wowdoc静态检查结果见本次日志；实机结果待补充。

API沿用项目现有Frame、Texture、Theme与导航按钮。wowdoc sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；SimpleScriptRegionResizingAPIDocumentation.lua:135 SetPoint，relativeTo为ScriptRegion，偏移为uiUnit；证据analyze/onboarding-setpoint.json。无新增TOC加载项，仅版本元数据更新，可reload。
