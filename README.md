<div align="center">

<img src="addon/Lychee/Media/lychee-logo.png" width="88" alt="荔枝标识">

# 荔枝启动器

**技能、物品、设置，一个入口。**

按下 <kbd>Alt</kbd> + <kbd>Space</kbd>，输入你要找的内容。

[简体中文](README.md) · [English](README.en.md)

[![版本](https://img.shields.io/badge/version-0.2.5-d53c49?style=flat-square)](addon/Lychee/Lychee.toc)
[![Lua](https://img.shields.io/badge/Lua-5.1-2c2d72?style=flat-square&logo=lua&logoColor=white)](addon/Lychee)
[![语言](https://img.shields.io/badge/语言-中文%20%2F%20English-526b5d?style=flat-square)](#clients)
[![客户端](https://img.shields.io/badge/WoW-4%20客户端-6d587c?style=flat-square)](#clients)

[![Provider SDK](https://img.shields.io/badge/Provider%20SDK-API%201.0.0-536b85?style=flat-square)](lychee-sdk/docs/zh-CN/GETTING_STARTED.md)
[![许可](https://img.shields.io/badge/license-非商业%20·%20署名-d53c49?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/Follen/Lychee?style=flat-square&color=b79857)](https://github.com/Follen/Lychee/stargazers)
[![Issues](https://img.shields.io/github/issues/Follen/Lychee?style=flat-square&color=687581)](https://github.com/Follen/Lychee/issues)

[安装](#install) · [试着搜一下](#search) · [插件设置直达](#integrations) · [开发 Provider](#developers)

<img src="docs/media/search-spells.png" width="960" alt="游戏内实机截图：搜索奥术，展示奥术智慧、奥术宝珠、奥术冲击等技能，匹配文字以荔枝红高亮。">

<sub>游戏内实机截图 · 搜索「奥术」</sub>

</div>

想用一个技能，却不记得它放在哪条动作栏；想改一个设置，却不记得它藏在哪层菜单。荔枝让你从**名字**出发：找到它，然后施放、使用、切换，或打开对应页面。

<a id="search"></a>

## 试着搜一下

| 想做什么 | 输入什么 | 找到之后 |
| :--- | :--- | :--- |
| 找角色已学会的技能 | `变形术` | 点击施放，也能拖到动作栏 |
| 找背包里的东西 | `炉石` | 点击使用；右键可定位背包格子 |
| 打开游戏页面 | `传家宝` | 直接打开传家宝收藏 |
| 打开主音量设置 | `主音量` | 左键打开暴雪设置并定位；右键可设置别名或固定到首页 |
| 分享一个成就 | `引领潮流` | 找到成就，Shift + 左键贴入聊天框 |
| 看小队钥匙 | `key`、`钥匙` 或 `分数` | 显示队伍钥匙和分数（正式服） |
| 只找技能，不混入其他内容 | `技能：变形术` | 仅显示玩家技能中的匹配项 |

技能、背包和成就的结果取决于当前角色及客户端。慢来源准备期间会显示轻量等待状态；已有的当前搜索结果先显示，不必等所有来源一起完成。

### 常用的，留在手边

- **固定**：把常用内容放在搜索首页，空着搜索框就能用。
- **别名**：右键给某个条目起个好记的名字，例如给传送门设为 `回家`；在设置里统一管理。
- **记住选择**：同一个搜索词，下次优先照顾你之前选过的结果。
- **命中高亮**：中文、英文匹配部分直接标出，扫一眼就能确认。

### 搜索范围，由你决定

在 **设置 → 功能来源 → 选择一个功能** 中，可以分别调整：

| 设置 | 用起来是什么样 |
| :--- | :--- |
| 普通搜索 | 直接输入内容名称，就能找到这个功能的结果 |
| 搜索前缀 | 输入 `技能：变形术`，只查玩家技能 |
| 快捷关键词 | 将 `abc` 设为入口，完整输入 `abc` 时直接显示该功能的结果 |

功能来源开关只决定该来源是否参与搜索，不会卸载插件或关闭它的后台功能。已有固定项、最近记录等明确引用仍可尝试恢复；来源实际不可用时会说明原因。

三种入口可以同时存在。**别名对应一个条目，快捷关键词对应整个功能来源**；例如 `回家` 找一个传送门，`key` 查看队伍钥匙。

<table>
<tr>
<td width="50%" align="center"><a href="docs/media/search-achievements.png"><img src="docs/media/search-achievements.png" alt="成就搜索实机截图：显示完成状态和 Shift 点击分享提示。"></a></td>
<td width="50%" align="center"><a href="docs/media/provider-settings.png"><img src="docs/media/provider-settings.png" alt="功能来源管理实机截图：分别启用、关闭和管理各个功能。"></a></td>
</tr>
<tr>
<td align="center"><strong>找到成就，顺手分享</strong><br>完成状态与聊天分享入口放在结果旁</td>
<td align="center"><strong>用哪些功能，自己选</strong><br>按来源开关，也能单独调整搜索入口</td>
</tr>
</table>

<sub>点击截图查看原图。</sub>

<a id="integrations"></a>

## 插件里的设置，也能直达

正式服安装对应插件后，在功能来源里启用集成，再用前缀搜索：

| 插件 | 搜索示例 | 打开哪里 |
| :--- | :--- | :--- |
| **Ellesmere UI** | `EUI：悬停施法` | 已收集到的设置页；有定位信息时可跳到分区或控件 |
| **Ellesmere UI** | `EUI：解锁` | 解锁模式 |
| **Exwind** | `EX：自动修理` | ExwindTools、ExBoss 等已注册模块中的对应设置页 |
| **Exwind** | `EX：解锁` | 编辑模式 |

默认只有带前缀的搜索会进入这两个集成。`EUI:` / `eui:`、`EX:` / `ex:` 和中文冒号都可以。

目录从已安装插件的注册数据中收集。尚未生成或未公开注册的设置可能暂时搜不到；集成不会保证覆盖插件里的每一个选项。

**不知道一个界面属于哪个插件？** 搜索 `插件识别`，进入后用鼠标指向它：浮窗跟随鼠标，显示来源或推测结果；按住 <kbd>Shift</kbd> 展开详情，<kbd>Esc</kbd> 退出。

## 荔枝大米助手（仅正式服）

直接搜索小怪名、Boss 名、技能名或 NPC／技能 ID，也可以输入 `毒牙老二`、`毒牙二号boss`。点击结果在荔枝内查看游戏模型、基础资料和技能，技能命中会定位到对应技能。默认参与全局搜索，也支持可选的 `ldt:` 前缀。

荔枝大米助手内置当前16个副本的462条怪物记录，无需额外插件。技能名称、图标和说明按客户端语言动态读取；未缓存的游戏数据可能需要等待加载。基础生命和进度不是当前难度下的实时数值。其他客户端不会加载 LDT。

## 团本首领（仅正式服）

直接搜索团本首领名、技能名或技能 ID；`团本首领：` / `bosses:` 可限定来源。输入 `史诗 技能名`、`英雄 首领名` 或 `normal spell name` 可选难度。结果副标题列出适用难度，点击打开冒险者指南对应技能；附加动作可切换到其他适用难度。

同一首领的同一技能跨难度合为一条，不合并不同 ID 的同名技能。数据关系来自游戏内冒险者指南的版本快照；老团本没有指南技能时只提供首领入口。该来源不再收录地下城首领；荔枝大米助手目前覆盖16个副本，并非所有历史地下城。

<a id="install"></a>

## 安装

1. [下载仓库 ZIP](https://github.com/Follen/Lychee/archive/refs/heads/main.zip)，解压。
2. 把里面的 **`addon/Lychee` 整个文件夹**复制到你所用客户端的 `Interface/AddOns/`。
3. 重启游戏，在插件列表启用 **荔枝启动器**，按 <kbd>Alt</kbd> + <kbd>Space</kbd>。

最终目录应是这样：

```text
Interface/
└── AddOns/
    └── Lychee/
        ├── Lychee.toc
        ├── Lychee_Mainline.toc
        ├── Bootstrap.lua
        └── …
```

本分支的自带功能合并在一个 `Lychee` 插件内。曾安装多包开发版的用户，请按[转换交付步骤](docs/guides/DELIVERY.md#从多包开发版转换)备份并隔离旧的自带包，避免重复注册；独立第三方插件不在清理范围。

**不要把解压后的整个仓库放进 AddOns。** `lychee-sdk`、`docs` 和 `assets` 都不需要安装。仓库 ZIP 是当前开发版本。

快捷键已被其他功能占用时，荔枝不会覆盖它；可在游戏的按键设置里重新绑定。

| 操作 | 按键 |
| :--- | :--- |
| 打开搜索 | <kbd>Alt</kbd> + <kbd>Space</kbd>（默认） |
| 选择结果 | <kbd>↑</kbd> / <kbd>↓</kbd> |
| 执行普通动作 | <kbd>Enter</kbd> 或左键 |
| 查看条目动作 | 右键 |
| 退出 | <kbd>Esc</kbd> |

受游戏安全规则限制，战斗中不能呼出搜索；施放技能等安全动作需要真实鼠标点击。

<a id="clients"></a>

## 客户端与语言

同一个安装目录包含四套客户端加载清单，按客户端提供适用的功能。

| 客户端 | 通用功能¹ | 坐骑 · 装备方案 · 成就 | 正式服功能² |
| :--- | :---: | :---: | :---: |
| **World of Warcraft** · 正式服 | ✓ | ✓ | ✓ |
| **Mists of Pandaria Classic** · 熊猫人之谜怀旧服 | ✓ | ✓ | — |
| **Titan Reforged** · 泰坦重铸「时光」 | ✓ | ✓ | — |
| **Burning Crusade Classic Anniversary Edition** · 燃烧的远征周年纪念版 | ✓ | — | — |

¹ 技能、背包、游戏菜单、暴雪设置、插件识别。背包定位适配暴雪原生、ElvUI、NDUI 和 Ellesmere 背包界面。

² 纹章、宏伟宝库、天赋方案、首领指南、队伍钥匙，以及 Ellesmere UI / Exwind 集成。

以上为当前声明的适配范围，**不代表所有客户端都已完成实机验证**；具体入口也会检查当前客户端是否提供相应 API。版本基线见[开发文档](docs/guides/DEVELOPMENT.md)。

界面支持 **简体中文、English**，跟随游戏语言；繁体中文客户端暂用简体文案。物品、技能等游戏内容使用客户端本身的名称。

<a id="developers"></a>

## 把你的插件接进来

SDK / Provider API 为 **1.0.0**。一个 Provider 提供内容和动作，荔枝负责搜索、排序和展示。简单接入可提交 `entries` 和动作；有按需加载、参数调用或大目录需求时再使用相应能力。第三方仍是独立插件，维护自己的代码、存档和媒体，不读取 Host 私有模块。

你可以声明支持的客户端、注册自己的中英文文案，并为不同客户端提供不同实现。[加载约定](lychee-sdk/docs/zh-CN/LOADING.md)说明未加载插件如何被发现，[参数调用](lychee-sdk/docs/zh-CN/INVOCATIONS.md)说明如何把具体参数交给动作执行。

**[从 SDK 接入开始 →](lychee-sdk/docs/zh-CN/GETTING_STARTED.md)** · [协议参考](lychee-sdk/docs/zh-CN/PROTOCOLS.md) · [示例与类型定义](lychee-sdk/README.md)

<details>
<summary><strong>维护与验证</strong></summary>

- [项目结构](docs/guides/PROJECT_STRUCTURE.md)：运行时、SDK、工具和文档各放在哪里。
- [架构](docs/ARCHITECTURE.md)：搜索与 Provider 的职责边界。
- [开发与验证](docs/guides/DEVELOPMENT.md)：环境、检查和客户端验收。
- [设计规范](DESIGN.md) · [性能约定](PERFORMANCE.md)。

在仓库根目录运行 `pwsh -File tests/check_contract.ps1`。需要 Lua 5.1、Python 和 ripgrep；离线测试不能替代游戏内的战斗、安全动作和视觉验证。

`analyze/` 是本地研究资料，受 Git 忽略规则保护，不进入仓库或插件安装包。

</details>

## 反馈与授权

[报告问题或提建议](https://github.com/Follen/Lychee/issues)。请带上客户端类型、荔枝版本、复现步骤；涉及其他插件时也附上它的版本。有 Lua 报错的话，贴完整报错比只发截图更有用。

**免费使用 · 原版完整分发须署名 · 禁止商用 · 禁止冒名发布。** 发布修改版需取得书面授权；用于向本项目提交改进的明确标注 Fork 按许可证中的贡献例外处理。

本项目采用[自定义非商业署名许可证](LICENSE)，属于源码可见项目，不使用开源许可证。完整条款以许可证为准；[第三方素材](THIRD_PARTY_NOTICES.md)保留各自授权。

分发署名：**Lychee（荔枝启动器）— Follen · https://github.com/Follen/Lychee**

### 0.2.5：斜杠命令

新增四客户端通用的斜杠命令来源，动态搜索已注册的普通命令（含第三方插件），输入 `dev` 或 `/dev` 后左键运行。输入 `rs` 可找到露露提亚工具箱，并复用已安装 RurutiaSuite 的 Logo。未知归属使用命令图标；不枚举子命令或绕过受保护命令。支持中英文与 `cmd:` / `命令:` 前缀。
