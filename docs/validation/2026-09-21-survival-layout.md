# 计算页布局 0.3.22

用户确认计算按钮在技能末项下方。实现按可见行数定位，仅行数变化重设锚点；420高容纳8行及按钮。计算页收紧结果与效果区间距，等宽标签居中、28×2选中线位于文字底部中心；移除正文说明和效果翻页，12个行控件容纳每组全部11条以内效果。公共视图footer提示统一走左状态位，不包含LDT专用Host分支。

基线8ab45e3模块423.2 KiB；新实现离线422.2 KiB。去掉2个导航按钮，增加2个固定复用Checkbox行，取消 offset/pagination 状态，50轮无新增框架，保留-1.03 KiB。无新素材/事件/OnUpdate；采用原生技能图标。12行容量仍为固定上界，单次渲染最多12项。

回归覆盖公共Footer文本所有权/失败回滚、LDT分组切换全部可达/旧按下失效/关闭重开；完整契约和静态检查后提交交付。实机覆盖左侧footer、无分页且第11行可达、列表按钮跟随行数、合剂勾选、返回与清理。英文布局及硬件点击另列未覆盖。

API沿用wowdoc retail12.1.0 commit4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59已验证SetPoint/ScrollFrame原生接口，未添加新接口。仅已加载模块，reload即可。

## 0.3.23 公共圆角及上半区

Checkbox通过同一个14×14容器的两组7-region圆角绘制外边框及内填充，白勾2纹理；每实例增加1 Frame/12纹理，LDT12实例固定保留，无驱动和新媒体。沿用主题token缓存setter和既有圆角纹理。模块离线425.1 KiB（上一布局422.2），增加语义图标、数字分隔和结果状态区域；50次开关仍无新增控件、-1.03 KiB保留。ui_motion复用和减少动态效果回归通过。

0079初次实机返回11/12通过，左footer断言将原生空文本nil当作非空。截图可见左侧提示，未把该次声明为全通过；已ACK/清理。后续探针记录原始文本并接受nil/空字符串两种空控件表现。新版一起复核。

## 最终实机验收

运行提交5f8e99a，199文件SHA-256同步一致；完整契约、Lua静态语法、wowdoc valid=true与diff检查通过。Ticket `LYCHEE-20260921-005144-0080`，task=ldt-layout-live/request=ldt-layout-20260921-c/revision=3，complete=true/status=succeeded，12/12通过。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-005144-0080/content.json`。环境Retail12.1.0.69875 zhCN，灵止光—死亡之翼。ACK确认/清理并移除自有任务。

左footer原始值为“仅计算首段直接伤害”，右footer空原生值nil；旧断言的问题已由原始证据确认。无分页、11效果、计算按钮行数跟随、合剂勾选、致死结论、两级返回、重开清选项、退出清理通过。WGC截图ui-rounded-9.png确认圆角边框、勾号、图标、千分位数值和居中标签；游戏世界tooltip遮挡下方少量区域，非本插件新建提示。

100次计算1.4212ms。使用脚本调用客户端事件；真实硬件操作、英文布局及游戏全包/纹理内存未验证。有限额外框架与纹理由公共组件持有、反复开关不增长，接受此视觉一致性成本。

## 0.3.24 标题与层数控件

运行提交 `aaae4f4`，199 文件 SHA-256 同步一致。层数使用 112×28 圆角步进器，移除钥石装饰，刷新图标缩至 16；怪物标题下副本居左、类型等级居右。新增一个固定 Frame、七个圆角纹理及一个复用 FontString，无新驱动。完整契约、Lua 语法、wowdoc valid=true、diff 检查通过；50 次重开无控件增长。

Retail 12.1.0.69875 zhCN，灵止光—死亡之翼。Ticket `LYCHEE-20260921-005946-0081`，request `ldt-stepper-20260921`，revision `stepper1`；完整 payload 位于本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-005946-0081/content.json`。12/12 功能断言通过，100 次计算 1.4154ms；ACK 已确认并清理，自有任务已移除。WGC `analyze/survival/ui-stepper-5.png` 确认中文标题左右布局及紧凑步进器无重叠。英文实机、真实硬件点击及纹理内存总量未验证。

## 0.3.25 信息归组与同名快捷键

运行提交 `d4c9390`，199 文件 SHA-256 同步一致。标题属性跟随名称，层数与刷新收紧至8间距，结果新增两条1×48静态纹理；无新增Frame、事件或驱动。LDT离线模块426.8 KiB（上一版426.2），50次重开未观察到保留增长（-1.03 KiB）、零新增控件。新增分组字符串由SettingsAdapter既有4094条上限目录持有，清理随原目录生命周期；索引签名包含分组，更新不会留下旧副标题。双语同名快捷键、原定位流程、完整契约、Lua语法、wowdoc与diff检查通过。

证据：wow-ui-source/retail requestedRef=12.1.0 resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Keybindings.lua:25 `local action, cat, binding1, binding2 = GetBinding(bindingIndex)`，189–195分组名称按`_G[cat]`字符串本地化，213–225按该分组收录绑定。SimpleFontStringAPIDocumentation.lua:339–349定义GetStringWidth返回uiUnit；仅测量本插件普通文字，用于标题布局。

客户端加载未确认：reload nonce `req-20260920-171836-738755` 初次45秒与同nonce恢复20秒均无ready回执。没有重发重载，未执行实机任务、无新Ticket；临时任务区块已移除。本轮新标题、分隔线和两个缩小的实机分组仍待验收，不沿用0.3.24实机结论。截图位于本机LycheeDev/automation/reload同nonce目录。

## 0.3.27 生存页视觉层级

运行提交 `48a60ea`，199运行文件SHA-256一致。分类标签聚合靠左，公共Checkbox增加可选左置方式（默认右侧不变）；效果行32高/34节距，结果与标签间隔减少16。移除2个装饰纹理，无新增Frame、timer、事件或OnUpdate。LDT模块离线426.8 KiB，与上一版同量级；50次重开无新增控件、未观察保留增长（-1.03 KiB）。完整契约、Lua语法、wowdoc valid=true与diff检查通过。

实机Retail12.1.0.69875 zhCN，灵止光—死亡之翼；Ticket `LYCHEE-20260921-013023-0082`，request=ldt-layout27-20260921/revision=layout27，complete=true/succeeded；14项功能断言全部通过，包括三组切换、合剂、致死、返回怪物、重开及关闭清理。100次计算1.4368ms，不能等同整插件性能。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-013023-0082/content.json`；WGC `analyze/survival/ui-layout27-5.png` 核对布局无重叠，ACK与自有任务清理完成。真实硬件点击、英文实机、受限失败/战斗和引擎总内存本轮未覆盖，沿用原交互实现并明确边界。

## 0.3.28 整页结构与选择控件

运行提交 `628e06f`，199文件SHA-256同步一致。技能主标题替换怪物主标题，怪物/副本降为上下文；固定结果区和分类区，效果独立滚动。公共Checkbox的choice变体增加圆角整行选中反馈，18方框与2粗勾；默认样式继续兼容。新增2个固定Frame、1个重置Button，12行新增固定圆角背景纹理，新增上下文文字；没有事件/计时器/逐帧驱动，保留原生对象而不宣称GC可释放。关闭清空模拟与快照并恢复怪物标题，重置只清模拟。

离线模块429.5 KiB（上一版426.8）；50次重开无新增控件，未观察保留增长（-1.03 KiB）；固定查询保留增长0.8 KiB、峰批4ms。有限常驻增加用于固定结果、可辨识选择状态和重置操作，接受；引擎纹理总内存未测，不把Lua数字当总量。完整契约、Lua语法、wowdoc及diff检查通过。

实机Retail12.1.0.69875 zhCN，灵止光—死亡之翼；Ticket `LYCHEE-20260921-013825-0083` request=ldt-layout28-20260921 revision=layout28，complete=true/succeeded，20/20断言通过：自动数据、任务标题、固定区域父级、unknown与恢复、无编辑参数、底栏、两组切换、无分页、合剂与效果、重置模拟、致死、按钮随列表、恢复怪物标题、返回怪物、重开、返回搜索、清理。100次计算1.4478ms。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-013825-0083/content.json`；WGC `analyze/survival/ui-layout28-9.png` 检查圆角、选中态及固定区域。ACK确认与清理完成，任务移除。真实硬件滚轮/点击、英文实机、战斗及长技能名实机本轮未覆盖；离线滚轮转发、过期按压、生命周期与本地化契约通过。

## 0.3.29 精修四项反馈

运行提交 `8d7fdbb`，199文件SHA-256一致。标题下移12；结果区三列184、内缩16并居中，结论图标按本地普通文字GetStringWidth定位且缓存setter；标签和下划线左对齐；choice未选框16、半径5、switchOff实心底。无新增Frame/Region/驱动，Lua模块离线430.5 KiB（上一版429.5）；50次重开未观察保留增长（-1.03 KiB），查询增长0.5 KiB，峰批3ms。完整契约、语法、wowdoc valid=true和diff检查通过。

Retail12.1.0.69875 zhCN，灵止光—死亡之翼。Ticket `LYCHEE-20260921-014706-0084` request=ldt-layout29-20260921/revision=layout29，complete/succeeded，20/20功能断言通过，100次计算1.6274ms。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-014706-0084/content.json`，WGC `analyze/survival/ui-layout29-9.png` 核对三栏、勾号、标签和未选态。ACK确认且清理，自有任务移除。英文实机、真实鼠标/滚轮、战斗和总纹理内存未覆盖。增加留白导致同高度窗口可见行减少，保留已有独立滚动供访问全部效果。

## 0.3.30–0.3.31 勾选四态图集与尺寸

运行提交9019048加入原创SVG四态图集，5caee2c按用户反馈将显示尺寸从20缩到16（实际轮廓约12），整行点击不变。200运行文件SHA-256一致；素材256×64 RGBA原始像素64 KiB，全行共享，每个choice从1 Frame/16 regions改为1 Texture，12行减少12 Frame/180 regions。状态UV和透明度缓存，无新驱动。完整契约、四态禁用/复用回归、Lua语法、wowdoc与diff检查通过；50次打开不增加控件、保留-1.03 KiB；离线模块430.5 KiB、查询增长0.0、峰批3ms。纹理引擎总内存未量化，不按对象计数换算总节省。

首轮Ticket `LYCHEE-20260921-020131-0085` 为21/23通过，合剂与选中态两项失败；WGC有同时鼠标操作且模拟选项发生变化，疑似干扰但不当作已确证根因；已ACK清理。check30-fast已加载但因用户尺寸修订未执行，直接换成check31。check31在断言同一回调中先恢复自有模拟基线，再执行点击检查。最终Ticket `LYCHEE-20260921-020529-0086` request=ldt-check31-20260921/revision=check31，Retail12.1.0.69875 zhCN 灵止光—死亡之翼，complete/succeeded，23/23通过。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-020529-0086/content.json`。WGC `analyze/survival/ui-check31-3.png` 确认缩小标记、hover及禁用（后两者由探针临时注入，不代表实际角色增益）；选中图集在首轮截图中可见。100次计算1.4311ms，ACK确认清理，任务移除。英文客户端、不同DPI及真实硬件点击独立场景未覆盖。


## 0.3.32 工具栏归组与荔枝红

基线5caee2c，局部样式修订：复用1个底座Frame和3个Button，额外3组圆角共21区域、3条加减线及1分隔，共25个固定Texture；无新增Frame、驱动、事件或缓存。首次打开分配、关闭隐藏、后续复用；单次hover更新当前按钮，效果仍12行有界。图集尺寸与64 KiB原始像素不变，不声明总内存节省。

计划实机覆盖：层数加减及0/35禁用、刷新保留手动模拟、四态、重置、失败unknown与恢复、关闭重开、两级返回。沿用完整契约检查关闭清理和50次复用，另核对实际缩放下显示。

修改前wowdoc source list/check已核对；sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135–149 定义SetPoint(point,relativeTo,relativePoint,offsetX,offsetY)；SimpleTextureBaseAPIDocumentation.lua:576–587 定义SetTexCoord(left,right,bottom,top)。接口仅用于本插件非受保护UI。

0.3.32运行提交a7e32e2，同步200个SHA一致。完整契约、语法、wowdoc valid=true和diff检查通过；离线模块432.4 KiB（基线430.5），增加固定按钮圆角及线条，50次重开不新增Frame，保留-1.03 KiB（未观察增长）；查询增长0.0 KiB、峰批3ms。此有限固定成本用于同组反馈，接受；引擎总内存未测。

Ticket `LYCHEE-20260921-021400-0087` request=ldt-check32-20260921/revision=check32，Retail12.1.0.69875/zhCN/灵止光—死亡之翼，完整succeeded、28/28通过，含层数0/35边界、加减、刷新保留模拟和原有关闭/返回/重置/unknown恢复。100次计算1.7718ms。payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-021400-0087/content.json`，ACK确认清理。WGC `analyze/survival/ui-check32-4.png` 确认工具栏、红色手动选中、灰色禁用及细未选框；hover/禁用由探针注入。发现可承受文字省略，最终0.3.33追加4单位宽度余量（无新增对象）再确认。

最终确认前收到用户反馈未选白边过亮，0.3.33同轮将未选边框降至#39363B、内底#18161A；尺寸、图集容量和事件逻辑不变。实机额外使用同commit的SimpleFontStringAPIDocumentation.lua:442–454 `IsTruncated` 返回bool检查结论文字截断。

最终运行提交 `c8bdbd9`，200文件SHA一致；完整契约、Lua语法、wowdoc valid=true及diff检查通过。Ticket `LYCHEE-20260921-021749-0088` request=ldt-check33-20260921/revision=check33，同Retail12.1.0.69875/zhCN角色，complete/succeeded，29/29通过；客户端IsTruncated=false，结论宽约55单位。100次计算1.8136ms。完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-021749-0088/content.json`，最终WGC `analyze/survival/ui-check33-4.png` 核对暗边框、荔枝红选中、工具栏及完整结论。ACK确认清理、临时任务移除。未覆盖英文实机、其他DPI、真实硬件点击独立场景及引擎总内存；本轮为同一实际缩放下的局部样式验收。


## 0.3.34 标题复用导致提前省略

离线回归 `lua tests/providers/ldt_provider.lua` 在修改前失败：short-to-long creature title must grow beyond its previous clipped width。实机基线Ticket `LYCHEE-20260921-024143-0089`（title-red），Retail12.1.0.69875 zhCN 灵止光—死亡之翼：净化构造体完整宽69.1304，首次分配71.1304不截断；模拟上一短标题40宽再走实际OpenView/Mount，GetStringWidth只返回38.4783、分配40.4782且IsTruncated=true；单独恢复320宽后false。证明旧宽度影响测量，不是字体缺字或总空间不足。完整payload在本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-024143-0089/content.json`，已ACK清理。

修复两个实际同类点：怪物标题与生存结论采用GetUnboundedStringWidth；保留上限、居中和4单位缩放余量。设置标签先重置测量宽度，首页测量只影响装饰标记，均无此反馈循环；其他菜单布局未作未经复现的扩改。无新增对象、事件、timer、持久数据或热循环，现有静态/复用预算不变。

wowdoc source check已核对，sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:398–410 定义GetUnboundedStringWidth返回width/uiUnit；339–350为GetStringWidth；442–454为IsTruncated。仅用于本插件公开名称文字。
