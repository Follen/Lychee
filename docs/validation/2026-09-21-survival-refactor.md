# 生存计算页面重构（0.3.19）

## 改动与成本

结果、外援、计算依据按决策顺序排列；未知持续跳数只阻止累计承伤，首段与每跳仍显示。完整结论通过 complete 标记区分，未知时不宣称全程可承受。UI 公共 CreateCheckbox 采用受控选中状态，整行点击、禁用优先；10 行固定复用，每行4个纹理，不新增素材、常驻事件、计时器或 OnUpdate。

成本基线为 9946502：模块435.9 KiB；本轮439.0 KiB，增加3.1 KiB，用于结果状态、布局和双语文案。离线50次开关保留-1.03 KiB，无新增框架；1000次计算11 ms，分配/保留均0 KiB。统计对象为单包 Lychee 的 LDT 测试环境，非游戏总内存。新增纹理归复用组件所有，关闭释放业务引用。接受有限 UI 成本，不以 Lua 堆代替纹理内存。

## 离线检查

完整 tests/check_contract.ps1 通过，Lua语法249文件通过，git diff --check 通过；wowdoc retail 12.1.0 validate valid=true。新增回归覆盖未知持续跳数保留承伤、补齐后完整计算、受控 checkbox 禁用/恢复/隐藏，保留切页按下身份校验和50轮对象稳定断言。

## API 证据

sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。

Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua:524–534：SetRotation，radians:number，normalizedRotationPoint 可选。勾号复用现有原生纹理旋转方式；未使用新素材。滚轮与输入事件证据沿用 [上轮验收](2026-09-20-ldt-survival-ui.md)。

## 实机覆盖计划

Retail zhCN 当前角色：打开具体技能，未知持续时显示部分结果；勾选/取消外援立即更新；填写跳数入口展开并定位参数；连续滚轮及子控件转发；确认后显示累计伤害；返回怪物再返回搜索；关闭清理。记录实时计算100次CPU与截图。战斗、其他职业/客户端、英文排版及真实硬件点击不在本次自动化覆盖范围。

实机结果待同步后补录。
