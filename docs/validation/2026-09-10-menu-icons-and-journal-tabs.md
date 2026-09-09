# 菜单语义图标与冒险指南页签

日期：2026-09-10。延续 Provider API 2 / revision 1，在原有 28 个游戏菜单入口上补充六个冒险指南页签，合计 34 个入口。

后续修订：本文记录首次手绘资产交付；图标已由同日的 [IconPark 替换记录](2026-09-10-menu-iconpark.md) 取代，共用预览和资产清单现在指向新版。六个冒险指南页签的实现和验证保持有效。

## 交互与资产

| 搜索名称 | 目标控件 | 打开位置 |
|---|---|---|
| 旅程 | JourneysTab | 冒险指南的旅程 |
| 旅行者日志 | MonthlyActivitiesTab | 冒险指南的旅行者日志 |
| 推荐玩法 | suggestTab | 冒险指南的推荐玩法 |
| 地下城 | dungeonsTab | 冒险指南地下城目录 |
| 团队副本 | raidsTab | 冒险指南团队副本目录 |
| 教程 | TutorialsTab | 冒险指南教程 |

加载界面后由实际按钮 GetID 取得页签身份，不硬编码数字。使用原生 EJ_ContentTab_OnClick，同步 C_EncounterJournal.SetTab 和 EJ_ContentTab_Select；以实际 selectedTab 确认完成。游戏隐藏/禁用的页签不强制打开，受限状态读取和原生调用失败返回 UI_UNAVAILABLE，保留搜索窗口供重试。原有地下城/团队查找器保持独立。

34 个图标按功能语义用矢量路径生成：例如金币对应货币、分支节点对应天赋、书本对应法术书、衣架对应外观、齿轮对应设置。配色为浅色线条与荔枝红，透明背景。构建源为 [build_menu_icons.py](../../tests/build_menu_icons.py)，没有使用图像生成服务或第三方图标素材。

运行时格式为未压缩 RGBA TGA，64×64，每个图标四周预留 5 px，适配搜索列表及最近使用的 UV 0.07–0.93 裁切。运行时没有矢量渲染、图标事件或定时器，颜色及尺寸由资产和既有 Host 呈现完成。34 个图标的像素数据合计 544 KiB（未计 TGA 文件头、引擎元数据或可能的 mipmap），只在需要呈现时由游戏加载。

- [PNG 预览](../architecture/2026-09-10-menu-icons.png)：模拟 Host 裁切后的深色背景效果。
- [SVG 矢量参考](../architecture/2026-09-10-menu-icons.svg)：同一组可编辑形状。
- [资产与哈希清单](../architecture/2026-09-10-menu-icons.json)：34 个稳定文件名和 SHA-256。

## 来源与验证

修改前 wowdoc source check 确认 `wow-ui-source / retail / latest` 的本地和远端均为 `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

- Mainline `Blizzard_EncounterJournal.lua:2790`：原生页签点击同时调用 SetTab 和 Select；`:2795` 根据具名页签 ID 切换内容、写 selectedTab。
- Mainline `Blizzard_EncounterJournal.xml:2316,2321,2326,2346`：旅程、旅行者日志、推荐玩法、教程控件名称；函数中的 dungeonsTab / raidsTab 对应副本目录。
- `SimpleButtonAPIDocumentation.lua:257`：IsEnabled 可因 ButtonState 返回受限值，因此整个可用性条件放在小范围 pcall 内。
- `SimpleTextureBaseAPIDocumentation.lua:600`：SetTexture 接受纹理资源路径。现有 Host 已使用 addon TGA 路径，图标字段沿用同一公共协议。

完整 path、line、excerpt 与版本元数据见 [页签查询证据](../architecture/2026-09-10-journal-tabs-wowdoc.json) 和 [纹理查询证据](../architecture/2026-09-10-menu-icons-wowdoc.json)。仅使用正式服 Mainline/共享资料；查询返回的其他分支不作为实现依据。

专项离线测试已覆盖六个页签的搜索/点击、使用非固定测试 ID、只加载一次、重复打开、禁用、隐藏、受限状态读取、加载失败及静默选中失败；原有首领精确跳转测试继续通过。

最终检查全部通过：11 组契约/交互测试；51 个运行时、SDK 与测试 Lua 文件解析；Bindings XML 及 TOC 检查；wowdoc validate（35 个运行时 Lua，valid=true、零诊断）；git diff --check。34 个菜单 ID 与资产清单一一对应，文件 SHA-256、64×64 RGBA 格式及裁切安全范围均已核对；已经逐项检查模拟 Host 裁切后的预览。静态验证见 [validate JSON](../architecture/2026-09-10-menu-icons-validate.json)。

离线完整测试样本：三个新增 Provider 合计注册约 153 ms，常驻增量约 19,136.4 KiB，100 次交替查询均值约 4.89 ms；相比上一交付的菜单新增六条静态记录和纹理路径，没有新增常驻更新机制。此数据不包含游戏图形引擎加载图标的成本，也不是实机帧时间测量。

游戏内需验证：搜索六个名称与常用菜单，确认图标不缺失、不裁边、页签定位正确；不可用页签给出错误；首领点击仍定位具体首领。图标文件为新增资产，建议重启客户端后验收。当前尚未取得实机视觉、taint 或帧时间样本。

交付必须先提交，再覆盖复制至 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee` 并核对文件清单及全部 SHA-256。不复制构建工具、SVG/PNG 预览、文档或查询证据。回滚使用新 git revert 提交，复核并复制运行时；不自动删除正式服旧资产。
