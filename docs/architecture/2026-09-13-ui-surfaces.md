# 公共浮层与无分隔线布局

根据用户实机截图统一右键菜单、tooltip 和详情页，并将整体 UI 基准缩放改为 1.15。沿用近黑底、暖白正文、红色操作反馈、原始品牌与技能图标。移除装饰分隔线，以既有留白区分标题、内容和底部提示；输入边界、选中指示、展开箭头等功能标记保留。

公共提示框从 ResultList 收拢到 Components；搜索、首页、技能详情和怪物特性复用同一个延迟创建实例。五个文本区域与现有有界成绩表保持；不修改全局 GameTooltip，不新增帧驱动、事件或持久设置。内容更新仅发生在悬停、数据绑定和页面生命周期，离开/隐藏/换绑清 owner。

菜单继续使用原生描述、关闭与池化机制。背景复用 Theme 的七区域圆角表面，通过原生 AttachTexture 管理池化纹理，每次生成重新应用样式；不增加独立菜单 Frame。比旧背景增加五个有界纹理，页面与提示框删除装饰纹理抵消部分对象成本。公共标题/正文/次要文字字号不分别乘倍数；主窗口和 UIParent 下的独立浮层使用同一视口约束缩放，普通屏幕 1.15，小屏幕缩小适配。

基线提交 `7969c6c`，完整离线 93/93 通过；冷加载基线 1473.8 KiB、完整 1850.2 KiB。保留 PERFORMANCE.md 的全部加载、复用、交互和资源预算；首次创建后重复开关不得增加 Frame，隐藏无新增 timer/OnUpdate。实际像素、游戏字体和战斗 taint 未测时明确报告，离线预览只作布局检查。

版本证据：sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，matchedTag=12.1.0，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

- `Interface/AddOns/Blizzard_Menu/MenuUtil.lua:151`：`MenuUtil.CreateContextMenu(ownerRegion, generator, ...)` 使用 owner 的 menuMixin，生成描述后交由 Manager 打开。
- `Interface/AddOns/Blizzard_Menu/MenuTemplates.lua:1078`：`MenuStyleMixin:Generate()` 通过 `self:AttachTexture()` 构造菜单纹理。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1470`：`SetScale` 接收非空 number，IsProtectedFunction=true；沿用窗口战斗禁止打开/调整的门禁，不在动画每帧缩放。
