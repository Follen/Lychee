# 来源标签提前省略

用户截图显示搜索行左侧有大量空白，但右侧“荔枝大米助手”仍被省略。原布局依据原生文字测量将列宽缩至80–160；若首次显示读数尚未就绪，允许保留80宽。此前针对首页增加的OnShow补测没有覆盖搜索行，也使两处拥有不同的补救路径。

本次按现有640宽窗口统一布局：首页最近使用与搜索结果都使用 `Theme.Metrics.sourceLabelWidth=160`，单行右对齐；标题与副标题以来源列左缘为右界、保持14间距。短来源不收窄列宽，长来源超过160才由原生单行省略，完整来源仍可在提示中查看。附加动作仍占自己的右侧位置，固定网格不显示此列。约定已同步DESIGN.md。

删除两处逐条字体测量、搜索行宽度缓存、首页OnShow补测。来源列由创建时的布局声明负责，不新增控件、缓存、动画、timer或OnUpdate；结果内容、排序与动作不变。代价是短来源也保留160宽，换取稳定标题边界；不宣称所有任意长来源都能完整显示。

回归将文字测量模拟为0，旧布局明确失败于“recent source reserves room even before native text metrics exist”；新布局通过，并断言整个绑定/显示过程不测宽。原测试中要求短来源缩回80及显示后补测的断言已按新设计替换；保留单行、超长有界、附加动作让位、固定/最近复用测试。

接口证据：wowdoc source list/check后查询SetWidth，sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。精确path、line及excerpt保存于本地 `analyze/label-wrap-20260913/SetWidth.json`。验证结果另记收尾；原生字体/缩放效果需与离线测试分开验收。

验证完成：full-column.json 全量89/89通过；wowdoc Host43个Lua文件有效、无诊断；git diff --check通过。SetWidth精确证据为 Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua 第175行，参数width为uiUnit。当前客户端场景正在进行，不强制reload，因此本轮尚未验收修复后的原生字体画面；前轮动态测宽截图不能替代此次固定列宽验收。
