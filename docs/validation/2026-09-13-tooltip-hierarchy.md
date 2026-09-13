# Tooltip 层级与荔枝色

- 根据用户截图统一整个tooltip层级，并按后续要求加入少量荔枝色：标题14号暖白；来源/类型11号textDim；正文12号textMuted；主操作11号accentHover；辅助拖动11号textDim。成绩表列标题11号灰色、数据12号，保留游戏原有评分/职业颜色。
- 标题最小行盒20，其余16；标题与来源间隔4、正文分组10、操作分组12，两条操作提示间隔4。空字符串与缺失操作均不占行、不留空白；拖动单独出现时仍与正文分组。长文本按实际测量高度排版。
- DESIGN.md新增五级文字表、间距、缺失内容、品牌色使用范围及成绩表规范。提示仍只读，红字不成为新的点击区域；普通280、滚动说明400、表格416的宽度与跟随位置不变。
- 生命周期和预算：仍由Components拥有一个按需创建的tooltip、五个复用文本区域与原有有界表格/滚动区；没有新增对象、纹理、timer、事件或逐帧工作。颜色/字号只在首次创建设置，空闲跟随脚本仍停止。删除首次显示前重复的宽度setter、合并首次显示分支；未改变任何性能阈值。
- 对比度按Theme当前RGB与tooltip底色计算：text 16.26:1、textMuted 9.10:1、textDim 6.29:1、accentHover 5.78:1。原有游戏内彩色标记保持原义，不据此宣称它们全部经过对比度验收。
- `python tests/run.py --report analyze/tests/tooltip-hierarchy.json`：93/93通过，包含Lua/XML/Python静态解析、TOC、发布、SDK、UI、长说明、成绩表与原性能门禁。新增回归覆盖空操作、仅拖动、双提示与复用后收缩；已有跟随/关闭/战斗和对象复用测试通过。
- 同路径冷加载最终1473.9385 KiB、22 ms、2 Frame/4事件登记；低于1474 KiB/46 ms原门槛，余量仍小。静止1000帧0.00 KiB分配、零新增对象。离线数据不等于游戏CPU、纹理或视觉验证。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44个Lua文件、valid=true、无诊断。文档与差异检查通过。

版本证据：source list/check后固定 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=12.1.0`、`matchedTag=12.1.0`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:325` 定义 `GetStringHeight` 返回非空 `height:uiUnit`；继续使用它测量换行高度。字号与颜色通过既有Theme接口设置，SetFont证据沿用[菜单验收](2026-09-13-action-menu-polish.md)。

未取得新外观的实机截图；`/reload` 后需检查截图中的短提示、长标题、长说明滚轮、表格、中英文和UI缩放，战斗/taint及引擎内存仍待实测。无新TOC或模块，本轮无需重启。提交成功后按五包发布清单覆盖同步，核对SHA-256并保留旧文件；同步记录为 analyze/tests/tooltip-hierarchy-sync.json。
