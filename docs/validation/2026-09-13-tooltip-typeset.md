# Tooltip 字号与分组层级调整

用户提供成就、技能两个实机截图，指出上一版层级仍不清晰。原实现为14/12/11，身份区与操作区都较松散，亮红提示容易抢占注意力。本轮改为16/12/10：标题16号暖白、正文12号次白、类型与操作提示10号；标题与类型间距2，说明/操作分组间距12，两条操作提示间距2。最小行盒分别22/18/14，换行仍使用实际高度，不截断内容。普通宽280、内距14和全局缩放不变。

新增Theme专用 `tooltipTitle`、`tooltipMeta` 字号及 `tooltipAccent` 柔和荔枝色（RGB 0.78/0.46/0.50），仅公共tooltip使用，菜单与页面标题不变。字体仍为STANDARD_TEXT_FONT，无描边、无阴影，不依赖额外字体资源。成绩表维持表头11号、数据12号和业务颜色。DESIGN.md 已同步字号、行盒、分组及配色规范。

成本与生命周期：仅改变五个复用文字区域的首次字体/颜色设置，以及显示内容时的布局常量；不新增Frame/Region、事件、timer、动画或逐帧任务。空闲仍无跟随脚本，显示期间沿用鼠标坐标变化检查，隐藏后清理owner。新增两个字号键及一份颜色token，性能门槛不变。

验证结果：

- `python tests/run.py --report analyze/tests/tooltip-typeset.json`：93/93通过，包含Lua/XML/Python解析、TOC/发布/SDK、长文滚动、换行不重叠、空字段收缩、菜单、跟随及生命周期回归。未为样式常量新增重复实现的测试。
- 静止1000帧0.00 KiB分配、零新对象；正式服排除LDT冷加载1469.6006 KiB/24 ms，完整五包1831.6689 KiB/26 ms，均通过原门槛。数据来自离线替身，不代表游戏帧率或引擎内存。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44个Lua文件，valid=true，无诊断。
- `python tools/check_repository.py`、`git diff --check`通过；impeccable type扫描无发现，Lua动态样式另做源码复核。
- 配色对比度计算：tooltipAccent 5.67:1、textDim 6.29:1、textMuted 9.10:1。真实游戏字体的视觉重量、小视口缩放、中英文长标题和战斗/taint未实机验收；不把离线布局通过写成视觉验收通过。

版本证据：本轮source list/check后固定 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=12.1.0`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:500` 的 `SetFont` 接受 `fontFile:FontAsset`、`fontHeight:uiFontHeight`、可空 `flags:TBFFlags` 并返回 `success:bool`；同文件325行的 `GetStringHeight` 返回非空 `height:uiUnit`。沿用Theme既有成功后写字体缓存及实际文本高度布局，无新增API。

无新模块或TOC变化，提交后按五包发布清单覆盖同步、核对SHA-256并保留目标旧文件。同步记录为 analyze/tests/tooltip-typeset-sync.json；游戏中 `/reload` 后查看新效果。
