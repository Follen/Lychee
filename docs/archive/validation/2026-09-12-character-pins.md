# 固定项按角色存储

问题：账号共用`LycheeDB.palette.pinned`使骑士看到法师固定的传送技能。技能不可解析时条目禁用，无法成为选中项，因此也没有选中下划线；下划线样式未被删除。

按用户要求不迁移旧数据。登录初始化以及固定列表读取入口直接清除旧共用pinned字段。新数据存入`LycheeCharacterDB.pinned`，由所有客户端TOC的`SavedVariablesPerCharacter`声明交给游戏按角色读写，不维护GUID映射或猜测当前职业。

首页、管理页、固定/取消、排序、删除和撤销继续共用UserPreferences接口。删除旧的无归属字符串ID迁移函数和调用；每角色64项上限保持。其他账号设置沿用现有存储。

成本：登录初始化仅删除一个旧字段并懒建当前角色数据表；不枚举其他角色，不读取其他角色目录，不复制旧列表。无新增Frame、事件、timer或OnUpdate。重复10000次GetPins累计分配0.00KiB。角色切换由客户端加载不同的角色保存库，不让运行中的页面跨角色复用。

复现：`lua tests/character_pins.lua`在旧代码下失败于“new character must not inherit the account's mage portal pin”。修复后覆盖两角色隔离、空列表、旧字段丢弃、排序/删除/撤销、重新加载、损坏数据及64项上限；并验证全部5个生成TOC均声明角色保存库。

完整`tests/check_contract.ps1`通过，日志位于本机临时目录`lychee-character-pins-check.log`；包括各客户端TOC生成一致性、角色隔离、首页/管理页与SDK集成、既有性能预算。wowdoc validate检查79个Lua文件，valid=true，无诊断；git diff --check通过。

实机角色切换与再次登录后的磁盘持久化仍待确认。此变更新增TOC保存变量声明，必须完整退出并重启客户端；退出时旧内存先写回磁盘，新版加载后删除旧共用字段，后续/reload或退出完成落盘。不能仅凭离线模拟宣称实机已保存成功。

版本证据见`2026-09-12-character-pins-wowdoc.json`：wow-ui-source/retail/latest/8ea15b61e45c0ed4eba01439c90757f86eb78d34，Blizzard_AuctionHouseUI_Mainline.toc第6行使用SavedVariablesPerCharacter。
