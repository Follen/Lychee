# 插件发布平台详情文案

新手盒子、网易 DD 使用下方中文稿；CurseForge 使用英文稿。标题、短简介和详情正文分别复制到对应字段。本文件是发布素材，不是版本更新日志；平台编辑器的排版以实际预览为准。

## 新手盒子／网易 DD

### 插件名称

荔枝启动器 · Lychee Launcher

### 短简介

按 Alt + 空格，搜索技能、背包物品、游戏设置和成就。支持常用项固定、自定义别名，以及正式服副本怪物和团本技能查询。

### 详情正文

#### 记得名字，就从搜索开始

想用一个技能，却忘了放在哪条动作栏；想改一个设置，又要翻好几层菜单。

按下 **Alt + 空格**，在荔枝启动器里输入名字。找到结果后，可以施放技能、使用物品、打开页面，或查看这个条目还能做什么。

#### 不用先学命令，试着搜这些

- **`变形术`**：查找角色已学会的技能，点击施放，也能拖到动作栏。
- **`炉石`**：查找背包物品，使用物品或从右键菜单定位背包格子。
- **`传家宝`**：打开对应的游戏页面。
- **`把音量设置到30`**：查看调整结果，确认后执行。直接搜索“主音量”，也能进入调整界面。
- **`引领潮流`**：查找成就、查看完成状态，Shift + 左键将链接贴入聊天框。
- **`钥匙`**：查看小队钥匙和分数，仅正式服提供。

技能、物品及设置的可用内容以当前角色和客户端为准。搜索本身不会修改设置，选中并执行动作后才会生效。

#### 常用内容，不必每次重新找

把常用条目**固定到首页**，空着搜索框就能看到。也可以给条目起一个自己的**别名**，例如把常用传送门叫作“回家”。

荔枝会记录最近使用的内容，并在再次输入同一个词时优先照顾你之前选过的结果。匹配文字会高亮，方便从相似名称里找到需要的那一项。

想限定范围，可以输入 **`技能：变形术`**，也可以在设置里自定义各来源的前缀和快捷关键词。不想搜索某个来源时，关闭它的“参与搜索”即可，不会因此关闭该来源的后台功能。

#### 副本里的怪物和技能，也能查

**荔枝大米助手 · 正式服**

搜索怪物名、Boss 名、技能名，或直接输入 NPC／技能 ID。打开结果后，在荔枝内查看模型、基础资料和技能说明；从技能搜到的结果会定位到对应技能。

资料随插件内置，无需额外安装 MDT。覆盖范围以当前内置副本目录为准，不包含所有历史地下城；基础生命和进度资料不是当前难度下的实时数值。未缓存的游戏技能资料可能需要短暂加载。

**团本首领 · 正式服**

搜索首领或技能，点击直达冒险者指南对应内容。支持用“普通”“英雄”“史诗”限定难度，同一首领的同一技能会合并展示适用难度，也能从附加动作切换。

#### 插件设置直达与界面识别

正式服安装对应插件后，可以使用 **`EUI:`** 搜索 Ellesmere UI 设置，使用 **`EX:`** 搜索 Exwind 已注册模块的设置。可检索范围取决于对方插件提供的数据，不保证每一个选项都能找到。

不知道屏幕上的框体属于哪个插件？搜索 **`插件识别`**，把鼠标移到目标上查看来源；按住 Shift 查看详情，Esc 退出。无法准确判定时会显示推测结果。

#### 怎么操作

- **Alt + 空格**：打开搜索；若按键已被占用，可在游戏按键设置里重新绑定。
- **↑／↓**：选择结果。
- **Enter 或左键**：执行普通动作。
- **右键**：查看该条目的更多动作。
- **Esc**：关闭。

战斗中不能呼出搜索。施放技能等受保护动作需要真实鼠标点击，Enter 不会代替点击施法。

#### 安装与兼容

自带功能集成在一个 **Lychee** 插件里，不需要分别安装功能子包。手动安装时，将 `Lychee` 文件夹放入对应客户端的 `Interface/AddOns/`，再重启游戏。

界面支持**简体中文和 English**，跟随游戏语言；繁体中文客户端目前使用简体界面。技能、物品等名称取自游戏客户端。

当前提供正式服、熊猫人之谜怀旧服、泰坦重铸「时光」及燃烧的远征周年纪念版的加载配置，各客户端可用功能不同。大米资料、团本指南、小队钥匙和 EUI／EX 集成为正式服功能。其他客户端的适配仍需持续验证，请按下载文件标注的游戏版本安装。

#### 反馈

遇到问题，请附上游戏版本、荔枝版本、复现步骤及完整 Lua 报错；涉及其他插件时，也请注明它的版本。

[问题反馈](https://github.com/Follen/Lychee/issues) · [项目主页](https://github.com/Follen/Lychee)

作者：**Follen**。免费使用，分发与修改须遵守项目许可证。

## CurseForge

### Name

Lychee Launcher

### Summary

Press Alt + Space to find spells, bag items, settings and achievements. Pin favorites, add aliases, and look up dungeon creatures and raid abilities on Retail.

### Description

#### Find it by name

You remember the spell, but not its action bar slot. You know which setting you want, but not which menu contains it.

Press **Alt + Space** and type in Lychee Launcher. Select a result to cast a spell, use an item, open a panel or see its available actions.

#### Try a search

- **`Polymorph`** — Find a spell your character knows. Click to cast or drag it onto an action bar.
- **`Hearthstone`** — Find a bag item. Use it or right-click for bag location actions.
- **`Heirlooms`** — Open the collection directly.
- **`set volume to 30`** — Review the result, then execute the adjustment. Searching for master volume also gives you access to its controls.
- **`Ahead of the Curve`** — Find achievements, check completion and Shift-click to insert a link into chat.
- **`key`** — Check group keystones and scores on Retail.

Available results depend on your character and client. Typing a setting request does not change it; you must execute the action.

#### Keep frequent actions close

**Pin results** to the home screen or give them your own **aliases**. Call a favorite portal `home`, then search for that name next time.

Recent actions are available when the search box is empty. Repeating a query favors your previous choice, and matching text is highlighted in results.

Use a prefix such as **`spell: Polymorph`** to narrow your search. Each source can have its own prefixes and shortcut keywords. Turning off a source's search participation does not stop its background features.

#### Dungeon creatures and raid abilities

**LDT creature reference — Retail**

Search creature names, boss names, ability names or NPC/spell IDs. Open a result to inspect its model, base information and abilities inside Lychee. Ability matches take you to the relevant ability.

The reference is built in; Mythic Dungeon Tools is not required. Coverage follows the included dungeon catalog rather than every historical dungeon. Base statistics are not live difficulty-scaled values, and uncached game data may take a moment to load.

**Raid bosses — Retail**

Find a boss or ability and open its Encounter Journal section. Add `normal`, `heroic` or `mythic` to select a difficulty. A boss's ability is grouped across supported difficulties, with additional actions for switching between them.

#### Addon settings and frame inspection

On Retail, search installed **Ellesmere UI** settings with **`EUI:`** or registered **Exwind** module settings with **`EX:`**. Coverage depends on the data exposed by those addons; not every option may be available.

Search **`Addon inspector`** to identify a frame on your screen. Point at it to see its source or a best guess, hold Shift for details, and press Esc to leave.

#### Controls

- **Alt + Space:** open search. Rebind it in the game's key bindings if it is already assigned.
- **Up / Down:** select a result.
- **Enter or left-click:** run an ordinary action.
- **Right-click:** show more actions.
- **Esc:** close.

Search is unavailable in combat. Protected actions such as spell casting require a real mouse click; Enter does not cast spells.

#### Installation and compatibility

Built-in features ship as one **Lychee** addon. For manual installation, place the `Lychee` folder in your client's `Interface/AddOns/` directory and restart the game. No separate feature packages are required.

The interface supports **English and Simplified Chinese**, following the game locale. Traditional Chinese clients currently use Simplified Chinese interface text. Game content uses names supplied by the client.

Client load configurations are provided for Retail, Mists of Pandaria Classic, Titan Reforged and Burning Crusade Classic Anniversary Edition. Features vary by client; dungeon references, raid journal search, group keystones and EUI/EX integrations are Retail features. In-game validation is ongoing across clients. Install the file marked for your game version.

#### Feedback

Please include your game version, Lychee version, reproduction steps and the complete Lua error when reporting an issue. Include the other addon's version for integration problems.

[Report an issue](https://github.com/Follen/Lychee/issues) · [Project page](https://github.com/Follen/Lychee)

By **Follen**. Free to use. Redistribution and modifications are subject to the project's license.

## 配图素材（编辑时选用，不属于详情正文）

- [技能搜索](docs/media/search-spells.png)：主图，展示搜索列表与命中高亮。
- [成就搜索](docs/media/search-achievements.png)：展示完成状态和分享入口。
- [来源设置](docs/media/provider-settings.png)：展示搜索范围管理。
- [荔枝 Logo](addon/Lychee/Media/lychee-logo.png)：平台图标素材，上传前按编辑器要求处理尺寸。

以上现有截图来自中文客户端。英文详情使用时标注“Chinese client screenshot”，不要写成英文实机截图。先把图片上传至平台，再在详情编辑器中插入；仓库相对路径不能直接作为平台图片地址。
