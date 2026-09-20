# 空白包装层误选与光环提示框层级

基线 ad87988ca52de156e79a26e1bd5ec27aa47f2492。
用户截图选中 EllesmereUIUnitFrames_Hider 的1920×1080匿名包装层；在空地与Rurutia聊天按钮处均错误显示头像插件。
安装源码 EllesmereUIUnitFrames.lua:11256 创建playerVisWrap，SetAllPoints(origParent)，随后把玩家框设为子级。
包装层本身没有绘制；原算法 childContent 仅凭任一子级可能显示，就让全屏包装层成为原生首选结果。

实施前成本：不增加UI对象、事件、timer、缓存或候选上限；保留128对象/0.75ms批次、512原生候选总上限、
0.1秒活动采样，关闭/战斗零活动。删除子列表读取，单候选保留最多32自有Region、16祖先。
预算沿用16Frame/48Region、首次512KiB、100次启停1MiB/保留增长64KiB。

修复：删除 childContent 和“容器状态不可读即可提升空自绘”的规则。
Frame自身没有内容时不从子级借命中；受限原生图标/文字作为独立快照候选继续显示来源，不画红框。
不会递归寻找后代，也不加入插件名前缀、尺寸阈值或创建路径黑名单。
无法读取自身Regions的对象仍为unknown；只因子级存在/子列表受限不能放行自绘为空的包装层。
这收紧上一轮对容器的判断，旧测试必须按实际原生图标的归属验证，不能继续要求选择空容器。

提示框证据：sourceId=wow-ui-source，product=retail，requestedRef=latest，
resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34，source check远端一致；
- Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:313–314：GetDefaultTooltip返回AuraButtonTooltip。
- Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua:185–198：ShowTooltip操作独立光环提示框，:196调用RaiseFrameLevelByTwo。
- Interface/AddOns/Blizzard_SharedXMLBase/FrameUtil.lua:189–190：RaiseFrameLevelByTwo在当前level上加2。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1280–1289：SetFrameLevel为protected函数。
- Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_HeroTalentsContainer.xml:347：官方Frame使用frameLevel="10000"。
只把自身识别浮窗设为TOOLTIP/10000，outline仍TOOLTIP/0；不调用受限光环Tooltip的Hide/SetParent/SetFrameLevel。
AuraButtonTooltip及其内容与GameTooltip一样排除出候选。没有额外轮询、hook或动态层级争抢。
该静态层级覆盖普通/光环提示框的常规层级，不声称能压过任意第三方主动设置的更高层级。

验证：观察值adapter首次新增“空白处不选全屏包装层”断言，在旧实现实际失败；
增加Rurutia可读候选不能被包装层抢占、未知子级尺寸不构成包装层内容、受限图标保留创建来源。
原生首选不得穿透真正受限绘制、透明/隐藏/裁剪/继承Alpha等原有规则仍保留。
浮窗覆盖level200的独立tooltip代表场景，在旧level1实现实际失败；改后通过，且outline仍低于面板。
新增AuraButtonTooltip及子Region不抢占冷却图标的集成回归。

两个专项测试及600组独立oracle对照通过。离线12Frame/37Region，首次保留38.4KiB；
100次启停4ms/330.7KiB/未观察到保留增长；100次原生首选3ms/0.4KiB/零备用读取；
100次备用恢复9ms/8.5KiB。次数与原门槛相同，单样本耗时不当成游戏帧率收益。
完整check_contract.ps1、wowdoc validate（76 Lua / diagnostics=null）、git diff --check通过。
补充未加载AuraButtonTooltip及尚未创建采样框的父链终点用例：原实现把nil父级与nil工具引用匹配而误排除，
用例实际失败；将父链终止判断放在对象身份比较前后通过。未知或不存在的全局Tooltip引用不参与排除。
真实游戏中的三处位置与tooltip重叠仍需/reload后验收；没有新增TOC条目。
