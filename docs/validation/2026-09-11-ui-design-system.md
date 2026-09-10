# 黑底界面设计规范落地

基线：`b32ff89`。目标：让当前值、说明、输入区和操作在黑底上有明确身份，统一 Provider 管理、别名编辑、插件识别与公共导航。设计规范以根目录 DESIGN.md 为准。

## 实现前的成本与生命周期约定

触发仅为页面首次打开、配置变化、鼠标进入／离开、输入焦点与验证状态变化。Provider 管理仍固定两组、每组最多八个值容器；不随打开次数增加。删除只读值的圆角底面，新增固定输入边界与导航箭头，不引入媒体、OnUpdate、事件、timer、缓存或后台索引。

输入样式由公共 Components 管理；首次调用创建一次，隐藏清除临时焦点／错误样式，页面继续负责业务焦点与保存。关闭后没有新增活动工作。现有战斗关闭、旧按压身份和复用保护不变。

预算：创建只发生一次；20 次打开／编辑后新增 Frame 为零；设置列表保留原 1,000 来源、最多十行、20 次刷新分配低于 512 KiB 的门禁。纯样式只检查现有相关交互与实际尺寸预览，不添加复述颜色常量的测试；焦点／错误切换需行为回归。真实游戏像素渲染与缩放需另外验证。

## 实际改动

- DESIGN.md 统一信息层级、交互提示、输入、错误、空值、长词、中英文、布局及验收；修正文档中的旧尺寸、旧灰底悬停与词条规定。
- 公共导航常态主文字色，hover 只改变前景；行内编辑／添加显示下划线，返回与版本展开使用两条纹理绘制的方向箭头，保存使用重点操作色。
- Provider 详情删除 16 个只读词条的圆角底面，保留词表与固定容器。添加和编辑统一右对齐；已配置项步长 64，空项 48，减少无意义留白。只读词条不在单词中换行。
- 前缀编辑、别名编辑、插件识别复制框复用 StyleEditBox。原业务保存、取消、只读与权限规则不变。焦点／错误／隐藏均有明确收尾。
- 视觉预览暴露公共 CreateSurface 的四条边线缺少厚度，修复水平边高度、垂直边宽度及锚点；新回归检查边线确有尺寸。补齐英文“编辑”。
- 不改搜索引擎、Provider 声明或 SDK 协议，不新增运行时模块或媒体。

## 验证结果

`powershell -NoProfile -File tests/check_contract.ps1` 完整通过，覆盖 Lua/XML/TOC、双语与 SDK、搜索、UI、Provider 和性能门禁。`wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：71 个 Lua，valid=true，无诊断。`git diff --check` 通过。

`tests/interaction_smoke.lua` 覆盖编辑、取消、错误保留、同页开关、保存、旧按压、隐藏和固定池；新增表单焦点、错误优先、改正、隐藏恢复及 100 次焦点切换无新 Frame／OnUpdate 检查。`tests/addon_inspector.lua` 补齐离线 EditBox 内边距接口，原识别、冻结、复制、退出及战斗测试通过。

| 固定场景 | 基线 | 修改后 |
| --- | ---: | ---: |
| 1,000 来源、400 高视口，行数 | 8 | 8 |
| 首次创建 Frame/Region 替身合计 | 356 | 356 |
| 首次保留 KiB | 458.0 | 458.0 |
| 20 次刷新累计分配 KiB | 37.4 | 37.4 |
| 20 次刷新耗时 ms（单次运行） | 22 | 27 |
| 重复刷新行池增长 | 0 | 0 |

毫秒级离线单次数据不用于声称提速。Provider 二级页 20 次反复打开与编辑，无新增 Frame。插件识别修改后为 7 Frame／35 Region，100 次启停累计分配 345.7 KiB，保留增长 1.1 KiB，停止后活动工作为零。与旧实现相比，删除了圆角按钮装饰；这些替身数据不能换算成引擎纹理内存。

## 视觉检查边界

两轮集中检查：简中常态、英文常态、编辑错误、八个长词并展开版本。使用实际 ProviderSettings.lua 布局，离线 Frame/FontString 替身导出锚点，再投影为图像；主壳及系统图标为示意，字体测量和游戏引擎不完全相同。首次检查发现缺失边框与英文翻译，第二轮确认修复。没有以此宣称游戏实机像素验收通过。

本机证据保存在忽略目录 `.codex/`：`settings-contact-sheet.png`、`preview_settings.lua`、`render_settings.py`、`design-system-checks.txt`、`design-system-perf-before.txt`、`design-system-wowdoc.json`。这些不进入 AddOns。

主题对比度按 sRGB 相对亮度计算：text/window 16.57:1、textMuted/window 9.28:1、textDim/window 6.41:1，均满足 4.5:1；fieldBorder/field 3.17:1，满足 3:1；accentHover/field 5.53:1。禁用色单独使用，不以禁用色代替正常说明；游戏抗锯齿、UI 缩放与显示器观感仍须实测。

## WoW 来源证据

source list/check 确认本机 retail 对应 live 最新版本，无待更新。以下均为 sourceId=`wow-ui-source`、product=`retail`、requestedRef=`latest`、resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

| path | line | excerpt／用途 |
| --- | --- | --- |
| Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua | 391 | `function ChatFrameEditBoxMixin:OnEditFocusGained()`；焦点回调 |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua | 524 | `Name = "SetRotation"`，参数 radians 与可选 normalizedRotationPoint；方向箭头纹理 |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua | 915 | `Name = "SetTextInsets"`，参数 left/right/top/bottom 均为 uiUnit；文本框内距 |

本轮全部修改限于 Lychee 自有区域，不更改共享字体或 Blizzard 框架。战斗时沿用原有窗口关闭；没有新增战斗路径工作。交付后 `/reload` 即可加载；真实客户端中英文、缩放、输入边界与鼠标反馈仍待用户验证。

## 后续调整：移除行内操作下划线

用户实机反馈后，删除编辑／添加按钮的下划线及对应公共样式分支，保留纯文字、右对齐和红色 hover。DESIGN.md 已更新；以上下划线描述仅记录上一版实现。每个详情页减少两条纹理，不增加对象、事件或驱动，配置与点击行为不变。

完整 check_contract、wowdoc validate（71 Lua，无诊断）、diff --check 通过；实际 Lua 布局离线预览确认无下划线，游戏内观感仍待验证。本次移除装饰，不新增 API；查档 sourceId=wow-ui-source、product=retail、requestedRef=latest、resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34，SimpleEditBoxAPIDocumentation.lua:902（Interface/AddOns/Blizzard_APIDocumentationGenerated/），excerpt `Name = "SetTextColor"`。原始检查日志 `.codex/no-action-underline-checks.txt`。
