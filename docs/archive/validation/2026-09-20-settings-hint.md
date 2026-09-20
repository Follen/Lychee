# 首次使用设置入口提示 0.3.3

基线9476fda。第一次打开主窗口显示指向荔枝图标的轻量气泡，中英文文案，确认或进入设置后按账号保存一次性状态；未确认关闭后可重看。不在每次登录显示，不抢焦点。

存储：现有LycheeDB.settingsHintDismissed布尔值，由CharacterStore集中访问，UserPreferences提供语义入口。仅Registry ready后读写；保留其他账号字段，损坏根拒绝覆盖。角色设置、固定项与业务存档不变；这是明确的账号级新手引导偏好，不迁移角色设置。

成本：登录期无新Frame、事件、计时器；未确认首次打开创建固定一个气泡Frame与一个按钮及有限静态纹理/文字，之后复用；已确认的新会话不创建。目标为20轮无新增Frame、无持续保留增长；继承主窗口显示/战斗隐藏和缩放。正文与颜色复用Theme，Palette仅协调显示与确认，组件不读取存档。

离线回归覆盖zhCN、zhTW、enUS、enGB，首次打开、未确认重开、确认后20次重开、点击设置确认、模块重载、换角色、未ready和损坏根、战斗拒绝。原有CharacterStore所有权检查保持不变。完整契约、Lua解析、发布清单与四客户端wowdoc静态检查结果见本次日志；完整离线检查通过，实机结果如下。

API沿用项目现有Frame、Texture、Theme与导航按钮。wowdoc sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；SimpleScriptRegionResizingAPIDocumentation.lua:135 SetPoint，relativeTo为ScriptRegion，偏移为uiUnit；证据analyze/onboarding-setpoint.json。无新增TOC加载项，仅版本元数据更新，可reload。

## 实机结果与交付

运行提交aaec578，布局修正8f88724；版本0.3.3。196个文件已同步至正式服Lychee目录，逐文件SHA-256一致，旧额外文件保留。无需新增模块重启；reload握手确认12.1.0.69875就绪。正式服zhCN、晴昼秋岚—白银之手，Ticket 0050与最终0051的7项断言均通过：首次显示、中文文案、确认存储/隐藏、20次重开不重复、点击设置确认、窗口关闭。报告完整无截断，两次均ACK received并确认ticket_ack_cleared，自有settings-hint任务块移除，测试前确认状态恢复。

第一次WGC截图发现下方气泡遮挡第一行结果，修正到图标上方并加屏幕边界限制；最终截图analyze/onboarding-hint.png确认尖角、文案、按钮正常且不挡搜索框/列表。未修改图像呈现结果。

最终整次主窗口Show为1.953 ms（不是气泡单独耗时）。诊断GC后四批各5轮读数为13697.278、13621.747、13622.646、13623.544 KiB；Lychee Dev观察器约4293.300 KiB单列。测试同一Lua回调同步反复Show，会排入既有C_Timer.After(0)焦点回调；后两批各增加0.898 KiB，不能写成稳定零增长或气泡泄漏已排除。气泡对象身份始终相同，离线20轮Frame计数稳定，新增实现无timer、事件、数据列表或每轮缓存；以固定两Frame及有限纹理/文字的一次性成本接受本改动，不能据此宣称整体内存优化。该同步探针尚未测量队列排空后的长时间稳态，保留为性能验证边界。

账号标记跨模块重载和角色切换离线通过，实际登出换角色、战斗taint、英文和其他客户端实机仍未覆盖。未推送或对外发布。完整原始报告见[实机报告](2026-09-20-settings-hint-runtime.json)。
