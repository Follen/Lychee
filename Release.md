# 插件发布平台详情文案

新手盒子、网易 DD 使用下方中文稿；CurseForge 使用英文稿。标题、短简介和详情正文分别复制到对应字段。本文件是发布素材，不是版本更新日志；平台编辑器的排版以实际预览为准。

## 新手盒子／网易 DD

### 插件名称

荔枝启动器 · Lychee Launcher

### 短简介

魔兽世界万用搜索器。Alt + 空格启动，输入你想找的内容，快速获取搜索结果，直接施放技能、使用物品或调整设置。

### 详情正文

#### 荔枝启动器

背包里的炉石、藏在菜单里的设置，都可以直接搜名字找。按 Alt + 空格打开荔枝，搜“炉石”就能点击使用，输入“把音量设置到30”就能确认调整。

常用传送门可以起名叫“回家”，下次搜这两个字就能找到。技能和物品也能固定到首页，打开就能点。正式服还内置副本怪物资料，可以看模型、查技能，团本技能则能直接打开冒险者指南。

#### 可以搜什么

- `变形术`：查找角色已学会的技能，点击施放，也能拖到动作栏。
- `炉石`：查找背包物品，使用物品或从右键菜单定位背包格子。
- `传家宝`：打开对应的游戏页面。
- `把音量设置到30`：将主音量设为 30%。输入后需要点击执行；也可以搜索“主音量”，打开调整界面。
- `引领潮流`：查找成就、查看完成状态，Shift + 左键将链接贴入聊天框。
- `钥匙`：查看小队钥匙和分数，仅正式服提供。

技能、物品及设置的可用内容以当前角色和客户端为准。搜索本身不会修改设置，选中并执行动作后才会生效。

#### 固定、别名和最近使用

常用的技能或物品可以固定到首页，打开就能看到。名字太长，就给它起个别名：比如把常用传送门叫作“回家”，下次搜“回家”就行。

首页也会显示最近使用的内容。再次搜索同一个词时，之前选过的结果会优先显示；命中的文字会高亮。

只想找技能，可以输入 `技能：变形术`。各来源的前缀和快捷关键词都能在设置里修改。不想看到某一类结果，就关闭这个来源的“参与搜索”；它的后台功能仍会运行。

#### 副本资料（正式服）

**荔枝大米助手**

输入怪物名、Boss 名或技能名，可以查看模型、基础资料和技能说明。也支持直接搜 NPC／技能 ID。搜的是技能，打开结果就会定位到那条技能。

资料已内置，不需要安装 MDT。目前只收录部分副本。生命值和进度等基础资料不代表当前难度下的实时数值；首次查看未缓存的技能时，可能需要等游戏加载资料。

**团本首领**

搜索首领或技能，点击打开冒险者指南里的对应内容。搜索词里加上“普通”“英雄”或“史诗”，就能限定难度。同一首领的同一技能会合并显示适用难度，也可以在更多操作里切换。

#### 其他插件的设置与来源识别

正式服安装对应插件后，可以使用 `EUI:` 搜索 Ellesmere UI 设置，使用 `EX:` 搜索 Exwind 已注册模块的设置。能搜到哪些设置，取决于对方插件提供的数据。

不知道屏幕上的框体属于哪个插件？搜索 `插件识别`，把鼠标移到目标上查看来源；按住 Shift 查看详情，Esc 退出。无法准确判定时会显示推测结果。

#### 怎么操作

- **Alt + 空格**：打开搜索；若按键已被占用，可在游戏按键设置里重新绑定。
- **↑／↓**：选择结果。
- **Enter 或左键**：执行普通动作。
- **右键**：查看该条目的更多动作。
- **Esc**：关闭。

战斗中不能呼出搜索。施放技能等受保护动作需要真实鼠标点击，Enter 不会代替点击施法。

#### 安装与兼容

只需安装一个 Lychee 插件，以上自带功能都在里面。手动安装时，将 `Lychee` 文件夹放入对应客户端的 `Interface/AddOns/`，再重启游戏。

界面支持简体中文和英文，跟随游戏语言；繁体中文客户端目前使用简体界面。技能、物品等名称取自游戏客户端。

当前提供正式服、熊猫人之谜怀旧服、泰坦重铸「时光」及燃烧的远征周年纪念版的加载配置，各客户端可用功能不同。大米资料、团本指南、小队钥匙和 EUI／EX 集成为正式服功能。其他客户端尚未完成全部实机验证，请按下载文件标注的游戏版本安装。

#### 反馈

遇到问题，请附上游戏版本、荔枝版本、复现步骤及完整 Lua 报错；涉及其他插件时，也请注明它的版本。

[问题反馈](https://github.com/Follen/Lychee/issues) · [项目主页](https://github.com/Follen/Lychee)

作者：Follen。免费使用，分发与修改须遵守项目许可证。

## CurseForge

### Name

Lychee Launcher

### Summary

An all-in-one search tool for World of Warcraft. Press Alt + Space, type what you need, and quickly find results you can act on: cast spells, use items or change settings.

### Description

#### Lychee Launcher

Find your Hearthstone without opening your bags, or change a setting without hunting through menus. Press Alt + Space, search for Hearthstone and click to use it. Type `set volume to 30` and click to apply the change.

Give your usual portal the alias `home`, or pin frequently used spells and items so they are there when you open Lychee. On Retail, you can also inspect dungeon creatures and their abilities, or jump straight to a raid ability in the Encounter Journal.

#### Try a search

- `Polymorph`: Find a spell your character knows. Click to cast or drag it onto an action bar.
- `Hearthstone`: Find a bag item. Use it or right-click to locate it in your bags.
- `Heirlooms`: Open the collection directly.
- `set volume to 30`: Set master volume to 30%. Click to apply the change, or search for master volume to open its controls.
- `Ahead of the Curve`: Find achievements, check completion and Shift-click to insert a link into chat.
- `key`: Check group keystones and scores on Retail.

Available results depend on your character and client. Typing a setting request does not change it; you must execute the action.

#### Pins, aliases and recent actions

Pin frequently used spells and items to the home screen. You can also give them aliases: name a favorite portal `home` and search for that next time.

The home screen also shows your recent actions. Search for the same term again and your previous choice gets priority. Matching text is highlighted in the results.

Use a prefix such as `spell: Polymorph` to narrow your search. Each source can have its own prefixes and shortcut keywords. You can hide a source from search without stopping its background features.

#### Dungeon creatures and raid abilities

**Dungeon creatures (Retail)**

Search creature names, boss names, ability names or NPC/spell IDs. Open a result to inspect its model, base information and abilities inside Lychee. Ability matches take you to the relevant ability.

The creature reference is included with Lychee; you do not need Mythic Dungeon Tools. It covers a selection of dungeons. Base stats do not reflect the current difficulty, and uncached game data may take a moment to load.

**Raid bosses (Retail)**

Find a boss or ability and open its Encounter Journal section. Add `normal`, `heroic` or `mythic` to select a difficulty. The same ability for a given boss appears as one result with its available difficulties. You can also switch difficulty through the result's additional actions.

#### Addon settings and frame inspection

On Retail, search installed **Ellesmere UI** settings with `EUI:` or registered **Exwind** module settings with `EX:`. The available settings depend on what those addons expose.

Search `Addon inspector` to identify a frame on your screen. Point at it to see its source or a best guess, hold Shift for details, and press Esc to leave.

#### Controls

- **Alt + Space:** open search. Rebind it in the game's key bindings if it is already assigned.
- **Up / Down:** select a result.
- **Enter or left-click:** run an ordinary action.
- **Right-click:** show more actions.
- **Esc:** close.

Search is unavailable in combat. Protected actions such as spell casting require a real mouse click; Enter does not cast spells.

#### Installation and compatibility

All built-in features come in a single Lychee addon. For manual installation, place the `Lychee` folder in your client's `Interface/AddOns/` directory and restart the game.

The interface uses English or Simplified Chinese to match your game language. Traditional Chinese clients currently use Simplified Chinese interface text. Game content uses names supplied by the client.

Client load configurations are provided for Retail, Mists of Pandaria Classic, Titan Reforged and Burning Crusade Classic Anniversary Edition. Features vary by client; dungeon references, raid journal search, group keystones and EUI/EX integrations are Retail features. Full in-game testing has not been completed on every client. Install the file marked for your game version.

#### Feedback

Please include your game version, Lychee version, reproduction steps and the complete Lua error when reporting an issue. Include the other addon's version for integration problems.

[Report an issue](https://github.com/Follen/Lychee/issues) · [Project page](https://github.com/Follen/Lychee)

By Follen. Free to use. Redistribution and modifications are subject to the project's license.

## 配图素材（编辑时选用，不属于详情正文）

- [技能搜索](docs/media/search-spells.png)：主图，展示搜索列表与命中高亮。
- [成就搜索](docs/media/search-achievements.png)：展示完成状态和分享入口。
- [来源设置](docs/media/provider-settings.png)：展示搜索范围管理。
- [荔枝 Logo](addon/Lychee/Media/lychee-logo.png)：平台图标素材，上传前按编辑器要求处理尺寸。

以上现有截图来自中文客户端。英文详情使用时标注“Chinese client screenshot”，不要写成英文实机截图。先把图片上传至平台，再在详情编辑器中插入；仓库相对路径不能直接作为平台图片地址。
