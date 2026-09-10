# Lychee

Lychee 是 World of Warcraft 游戏内的通用搜索工具。Provider 提供可搜索条目及其交互，Host 负责搜索、排序、统一展示、最近使用与执行约束。内置功能和第三方插件使用同一套公共 SDK；业务种类不由框架枚举。

`package/Lychee` 是唯一运行时 AddOn。`lychee-sdk` 是开发包，不作为独立插件安装。默认快捷键为 Alt+Space，也可在游戏按键设置中修改。

## 安装与升级

将 `package/Lychee` 文件夹复制到对应客户端的 `Interface/AddOns/Lychee`，确认 `Lychee.toc` 直接位于该目录下。首次安装或 TOC/模块列表变化后重启客户端。本仓库的检查、提交和正式服同步顺序见 [开发与验证](docs/DEVELOPMENT.md)。

Alt+Space 仅在没有已有 Lychee 绑定且该组合键未被占用时自动设置。空输入显示最近使用，右键打开动作菜单；Enter 执行普通动作，技能施放需要真实鼠标点击。战斗中不能呼出搜索。

0.2.0 使用 Provider API 2 / revision 2。升级时，旧 schema 的整份 `LycheeDB` 会重置，包括其中的设置与最近使用；不提供 schema 1 数据迁移；API 2.1 Provider 保持兼容，未声明客户端范围时仅在正式服启用。第三方集成须使用 `RegisterProvider`。

## 开发文档

- [架构](docs/ARCHITECTURE.md)：模块职责、生命周期、扩展边界。
- [SDK 接入](docs/SDK.md)：API 2 快速开始和可运行示例。
- [协议参考](docs/PROTOCOLS.md)：字段、限制、错误和行为约定。
- [SDK 开发包](lychee-sdk/README.md)：LuaLS 类型、辅助函数和第三方示例。
- [开发与验证](docs/DEVELOPMENT.md)：环境要求、检查命令、示例安装和客户端验收。
- [产品约定](PRODUCT.md) 与 [界面设计](DESIGN.md)：产品范围、交互和视觉规范。
- [框架决策](docs/architecture/2026-09-10-provider-framework.md)：方案比较、取舍和验收范围。
- `docs/comet/` 保留先前工作流的规格与历史；当前 Provider API 2 以以上架构与协议文档为准。

## 当前实现

已实现静态目录和增量更新、同步或延迟查询、当前条目恢复、普通回调动作、技能安全动作、独立拖动、托管视图和动作菜单。所有内置功能通过公共 Provider API 注册：

| Provider | 搜索与点击行为 |
|---|---|
| 玩家技能 | 搜索当前角色技能，使用现有技能安全动作与拖动 |
| 纹章 | 搜索“纹章 / 神话 / 英雄 / 勇士 / 老兵 / 冒险者”等，统一命中“纹章”；点击在搜索框内容区显示当前角色五档迷雾纹章数量 |
| 游戏菜单 | 34 个带语义图标的入口，覆盖角色、声望、货币、天赋、收藏、社交、组队、PvP、宏和设置等；包含旅程、旅行者日志、推荐玩法、地下城、团队副本、教程六个指南页签直达入口 |
| 首领 | 搜索首领名或副本/团本名，选择首领后直接打开对应冒险指南页面；目录含 1,154 个首领、214 个分组 |

纹章与首领目录的生成基线为正式服 `12.1.0.69587 / zhCN`；英文首领和副本名称通过客户端原生冒险指南 API 分批读取，临时缺失时显示英文 ID 占位并在相关模块加载后更新。纹章图标为神话迷雾纹章；数量来自角色实时货币 API，只在视图显示期间监听变化。首领使用副本图标，旧团本没有攻略章节的首领也保留。目录更新与验证见 [内置 Provider 记录](docs/validation/2026-09-10-builtin-providers.md)。

游戏菜单使用统一的透明线条图标，按功能语义生成；[图标预览](docs/architecture/2026-09-10-menu-icons.png) 与 [页签验收记录](docs/validation/2026-09-10-menu-icons-and-journal-tabs.md) 可供核对。“地下城 / 团队副本”打开冒险指南目录；“地下城查找器 / 团队查找器”打开组队页面。

API 2 不提供旧 SDK 适配；SavedVariables 使用全新的 schema 2，不迁移旧历史或索引。

在仓库根目录执行 `pwsh -File tests/check_contract.ps1` 运行契约检查。真实 WoW 的视觉、硬件点击、战斗/taint 和 CPU/帧时间仍须在客户端验证，离线测试不能替代这些证据。

## 客户端与语言

荔枝启动器 / Lychee Launcher：魔兽世界万用启动器。游戏中的“荔枝 / Lychee”使用荔枝红，其余名称保持正常颜色。

| 客户端 | TOC | 当前 Interface |
|---|---|---|
| World of Warcraft（正式服） | Lychee_Mainline.toc | 120100 |
| Mists of Pandaria Classic（熊猫人之谜怀旧服） | Lychee_Mists.toc | 50504 |
| Titan Reforged（泰坦重铸服务器「时光」） | Lychee_Wrath.toc | 38002 |
| Burning Crusade Classic Anniversary Edition（燃烧的远征周年纪念版） | Lychee_TBC.toc | 20506 |

Host 与每个 Provider 各自管理英文、中文文案；zhTW 回退 zhCN，enGB 回退 enUS。游戏物品、技能、成就等名称读取当前客户端原生语言。Provider 通过 `scope.products` 声明支持范围，API 2.2 同时要求注册自己的 `i18n`。

四客户端通用：技能、背包、游戏菜单、暴雪设置、插件识别。坐骑、装备方案、成就支持正式服／熊猫人之谜／泰坦重铸，并检查对应 API。纹章、团队钥匙、宝库、天赋方案、首领目录仅正式服。各客户端缺少的菜单入口不显示。

`tests/client_manifest.json` 是 TOC 加载清单，运行 `python tests/build_client_tocs.py` 生成，`--check` 检查漂移。客户端升级时须重新核对接口与 API。离线矩阵检查不替代各客户端的实机加载、战斗和安全动作验证。
