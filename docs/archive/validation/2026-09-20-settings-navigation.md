# 设置定位、返回层级与空格前缀验收

版本 0.3.14；运行提交 `afa828a9af1e1f111575370441287af852f79f42`、补丁 `cf1a0df8ce15c218a0b5ad7513436010b3d2478d`。197 个运行文件已同步到本机正式服 Lychee，逐文件 SHA-256 一致，保留目标旧文件。

## 问题与修复

- 快捷键目录来自暴雪的隐藏搜索分类；`OpenSettingsPanel(category, name)` 只匹配可见行的 `data.name`，不能展开实际分类中的快捷键组。点击时按稳定 binding action 在当前布局中寻找分组，调用原生展开按钮，再定位真实子控件。没有命令名称或插件名称的硬编码映射。
- 大分组展开时，暴雪的尺寸回调延迟更新滚动范围；直接滚动会被旧范围截断。展开按钮回调返回后调用一次原生 `FullUpdate(UpdateImmediately)`，重新获取原生 Frame 再定位，不增加异步任务。
- 组合设置按 variable 定位实际行；画质按 CVar 对应控件定位，并选择普通／团队页签。没有设置值写入。条件隐藏项仍保留原有分类导航能力。
- 设置详情不再包含第二个返回入口。右上角依次返回 Provider 列表、搜索；别名编辑依次返回别名列表、综合设置、搜索。层级由 SettingsView 管理，Palette 仅调用 Back。
- 所有注册前缀统一支持空格及连续空白，保留中英文冒号；未注册首词保持普通查询。原文 byte offset 按实际分隔符长度计算，禁用、冲突、覆盖和注销仍走原策略。

## 版本化源码证据

共同身份：sourceId=`wow-ui-source`，product=`retail`，requestedRef/matchedTag=`12.1.0`，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。经 wowdoc inspect/query 查符号，再读取该固定提交完整实现。

| path（相对 Interface/AddOns） | line | excerpt / 含义 |
| --- | --- | --- |
| Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua | 288 | `OpenToCategory(categoryID, scrollToElementName)` 调用 `ScrollToElementByName` |
| Blizzard_Settings_Shared/Blizzard_SettingsList.lua | 143 | `return elementName == name`，只匹配 initializer.data.name |
| Blizzard_SettingsDefinitions_Frame/Keybindings.lua | 44 | `bindingsCategories` 逐项生成 `Controls`，包含 spacer/preface |
| Blizzard_SettingsDefinitions_Frame/Keybindings.lua | 151 | `CreateSearchableSettings(redirectCategory)` 创建隐藏索引分类 |
| Blizzard_Settings_Shared/Blizzard_SettingControls.lua | 1579 | Button 点击更新 `data.expanded`、高度与 `OnExpandedChanged` |
| Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua | 133 | `FullUpdate(immediately)` 同步或排队更新布局 |
| Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua | 821 | 滚动位置为 `extentUntil - offset` |
| Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua | 855 | `ScrollToElementData(elementData, alignment, offset, noInterpolation)` |
| Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua | 1594 | `AddResizableChildrenBehavior` 使用 `UpdateQueued`，尺寸回调内不能重入更新 |
| Blizzard_SettingsDefinitions_Shared/Graphics.lua | 417 | 普通／团队页签共用 section，`tabsGroup:SelectAtIndex` 切换显示 |
| Blizzard_SettingsDefinitions_Shared/Graphics.lua | 356 | `InitControlDropdown(self.ShadowQuality, settingShadowQuality, ...)` 等 CVar 控件关系 |

## 离线检查

- 复现命令 `lua tests/providers/settings_navigation.lua` 在修复前失败：`native binding section remained collapsed`。
- 修复后 zhCN/enUS 均通过：折叠组、稳定 action 身份、布局重建、更新滚动范围、组合行、普通／团队画质及零设置写入。
- search_personalization：空格、多空格、Tab、中英文冒号、大写、前导空白、offset、普通多词、payload 冒号、自定义覆盖、禁用和注销通过。
- interaction_smoke：单一返回入口、草稿取消、隐藏操作、复用和生命周期通过。
- 完整 `tests/check_contract.ps1` 通过；Lua 解析、Bindings XML、版本/仓库/发布清单、wowdoc Mainline TOC validate 与 diff check 通过。

## 实机

使用 lychee-dev 后台 messages + WGC + SV 路径，无前台/剪贴板。实际环境：Retail 12.1.0.69875，Interface 120100，zhCN，灵止光—死亡之翼。不能沿用之前其他角色的环境标记。

| Ticket | 结果 |
| --- | --- |
| LYCHEE-20260920-204414-0069 | failed/complete：缩小及重复打开已通过，第三方 `CLICK TankMDButton1:LeftButton` 虽展开但未进入视口；促成滚动范围补丁。已 ACK。 |
| LYCHEE-20260920-204720-0070 | succeeded/complete：70 个断言、35 个注册前缀、7 次原生定位全部通过。第一次 ACK 超时，核对画面后重试同 Ticket，确认并清理成功。任务块已移除。 |

完整报告保留于本机 `%LOCALAPPDATA%/LycheeDev/automation/received/<Ticket>/content.json`，含环境与坐标。最终 payload SHA-256：`9be1c736a35671971c802e58a1215c06c721736bab8727e56548f2dae47d8202`。

覆盖：Provider 详情→列表→搜索；别名编辑→列表→综合设置；当前 35 前缀空格/冒号等价；缩小的首次展开和再次打开；第三方快捷键深层分组；UI 缩放、主音量、普通阴影和团队阴影。全部真实子控件 IsShown，矩形位于 ScrollBox 视口内。另用后台截图确认缩小在列表顶部，视角组已展开。

## 性能与边界

- 无新增 Frame、事件、计时器、OnUpdate 或持久缓存。删除了两个重复返回控件。binding 字符串替代原 searchName 字段；没有第二份快捷键索引。点击只遍历当前分类的原生布局；引用不跨动作保留。
- 原生打开的包容耗时：缩小首次 103.73 ms，再开 7.86 ms；第三方快捷键 10.98 ms；UI 缩放 37.29 ms；主音量 7.94 ms；普通／团队阴影 14.44/4.73 ms。包含暴雪页面首次创建和布局，不能当成 Lychee 独占 CPU 或稳态基准；首次打开成本仍存在。
- 完整离线性能契约通过；本次未做可归因的实机 GC 前后内存比较，不宣称降低了多少 KiB。
- 英文客户端和其他三个客户端未实机测试；战斗、禁用、原生打开失败覆盖为离线回归，未触发真实战斗。尚未穷举每个原生设置及每个第三方快捷键。
