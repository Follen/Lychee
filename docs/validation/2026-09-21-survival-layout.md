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
