# 0.2.2 目录整理验收

基线：`1662562b4abe053141986599b0e5cdbd95cbd1ff`。本次是小更新；SDK / Provider API 仍为 1.0.0。版本策略写入本地 AGENTS.md，并在现行交付指南保存可追踪说明。

## 实际变更

- `addon/Lychee/Builtin` → `Providers`；内部模块表 `I.ProviderModules`、词典数据 `I.ProviderLocaleData`、别名数据 `I.ProviderData`、翻译器 `ProviderLocales:Module`。Host 的 `I.Providers` 注册表独立不变。
- 16 个 `builtin.*` 稳定 ID 及来源分类保持不变，不迁移玩家存档。
- 删除 Audio 五个文件和 BlizzardSettings/Invocations、View 两个退役注释槽，同步资源与客户端清单。
- 测试按 core/providers/search/ui/sdk/integration/performance/build 分组；support 和 fixtures 保持共享装配职责。
- 团本 TSV/校验元数据迁到 assets/data/raid-journal，原始字节和 Git 二进制属性不变；平台文案移到 assets/release/DESCRIPTION.md，并去掉过时的音量直接编辑描述。
- 根目录保留共享规范；现行文档、生成器及入口命令同步更新。历史报告保留当时路径，索引解释新路径。空 package 目录移除，本地历史证据与工具状态不批量搬迁。

## 离线验证

完整 `tests/check_contract.ps1` PASS；包含四客户端真实 TOC 装配、四语言设置导航、Provider 生命周期/取消/重试、别名/固定/历史恢复、SDK 和性能门禁。测试分组不减少原入口用例。

迁移对照：107 个运行文件字节相同、54 个只有预先列明的标识替换；5 份 TOC 除版本/路径和 7 个注释槽外，所有剩余加载文件顺序相同。16 个 Provider ID 顺序和范围未改。原始数据逐条校验通过：490 首领、14392 难度关系。

Lua 5.1 语法、XML 解析、生成器漂移、文档链接与 git diff --check 通过。发布闭包为 Lychee 166 文件、独立 SDK 37 文件。插件只含运行代码/媒体/许可证；运行包 SDK 目录是执行代码，开发文档/示例在独立 SDK 包。

同机器同脚本离线 Mainline 加载：基线 111 文件、29 ms、累计分配 5207.0 KiB、回收后 2278.6 KiB；迁移后 104 文件、28 ms、累计分配 5197.0 KiB、回收后 2274.6 KiB。均为 2 框体/4 事件。属于一次加载样本，不声称稳定性能提升；没有增加缓存、轮询、订阅或业务数据副本。全量门禁保留原 CPU/生命周期阈值。

wowdoc：sourceId `wow-ui-source`，product `retail`，requestedRef/matchedTag `12.1.0`，resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。源码 `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:347–359`：`LoadAddOn` 接收 `name: uiAddon`，返回 `loaded: bool` / `value: string`；本次未引入新 API。递归静态检查 104 Lua、0 diagnostics；此结果不代表客户端 TOC 路径已实机加载。四客户端装配另由完整契约覆盖。

本地证据：`analyze/directory-reorganization/` 下的 before.json、mapping.json、equivalence.json、contract.log、loading-before.log、loading-after.log、wowdoc-validation.json。历史证据不进入发布包。

## 实机覆盖计划与当前边界

TOC 路径已变化，按 AGENTS.md 需要完整重启客户端，不能把旧会话或仅重载当成新目录验收。准备好的 lychee-dev 有界探针检查新版本/模块与词典/注册，以及暴雪设置多个类型的实际定位、菜单保留、固定/取消固定、别名打开/取消、历史恢复、关闭重开、退役动作拒绝与清理。隔离并恢复临时历史/固定/偏好，不改变音量。

当前实机待验收：重启后的 Retail zhCN 功能探针与 ACK；其他客户端/语言、受保护动作硬件点击和战斗场景未实测。离线四客户端/四语言通过不能替代这些边界。未宣称全量实机功能或性能通过。
