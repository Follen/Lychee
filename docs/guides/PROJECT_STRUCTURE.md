# 项目结构与维护入口

## 目录职责

| 位置 | 放什么 |
| --- | --- |
| `addon/Lychee/` | 游戏运行时；只从这里交付 |
| `addon/Lychee/Builtin/<功能>/` | 该功能的实现、独立语言资源和专用数据 |
| `addon/Lychee/Builtin/Shared/` | 内置功能共用的目录刷新、支持范围读取和界面动作 |
| `addon/Lychee/Builtin/Definitions.lua` | 工具生成的支持声明，不手改 |
| `addon/Lychee/Builtin/Init.lua` | 按生成声明启动功能，不维护另一张功能名单 |
| `addon/Lychee/Core/`、`Search/` | Host 的注册、调度、搜索与记录生命周期 |
| `addon/Lychee/UI/`、`Secure/` | 界面交互与受保护动作执行 |
| `addon/Lychee/PublicAPI/SDK.lua` | 游戏里真正使用的公开入口，必须保留 |
| `addon/Lychee/Locales/` | Host 界面文案；不收纳 Provider 文案 |
| `lychee-sdk/` | 第三方开发文档、类型和示例，不是第二个运行时插件 |
| `tools/` | 构建期生成工具和输入清单，不进入游戏 |
| `tests/` | 离线行为验证和性能门禁 |
| `lychee-sdk/docs/` | 随SDK发布的教程、协议和专题；性能规范是生成副本 |
| `dist/` | 生成的ZIP和哈希清单，忽略Git；legacy保存旧产物 |
| `docs/guides/` | 现行开发、构建和维护步骤 |
| `docs/architecture/` | 设计与来源调查，入口注明当前/历史状态 |
| `docs/validation/` | 验证证据；历史报告保留当时的路径 |

单文件功能用 `<功能>/Provider.lua`；复杂功能可以在自己的目录内拆分，不要求每个功能都具备相同数量的文件。技能别名在 `Builtin/PlayerSpells/Aliases.lua`，首领目录在 `Builtin/Bosses/JournalCatalog.lua`，不再混放到通用 Data 目录。

首领目录由`tools/build_journal_catalog.py`从保存的源快照生成，内部encounters使用
`encounterID, instanceID, canonicalName`连续三字段，`encounterCount`记录条数；
`tests/journal_catalog.py`逐条验证源快照，禁止手工修改生成行。
Elles的上游版本敏感访问放在`Builtin/Ellesmere/Adapter.lua`，Provider保留业务查询、排序和取消。
面板会话由`UI/ViewHost.lua`维护，SDK样例的缓存与清理由Provider所有，见`lychee-sdk/docs/VIEW_LIFECYCLE.md`。

## 新增或调整内置 Provider

1. 在对应功能目录放置实现与 `Locales.lua`，继续独立注册该 Provider 的 i18n。
2. 在 `tools/client_manifest.json` 的 `providers` 中维护唯一声明：稳定 `id`、运行时 `module` 名称、`products`、有序业务 `files`、`locales` 路径和可选必需函数 `requires`。
3. 在同一清单的 `files` 中放置一次 `{ "provider": "对应 id" }`，只决定加载位置，不重复声明支持范围。唯一的 `providerLocales` 位置先加载各客户端适用的语言文件。
4. 执行 `python tools/build_client_tocs.py`，一起生成四客户端 TOC、正式服 fallback、运行时声明和 SDK 示例 TOC。
5. 非目录型内置功能通过 `I.Builtin.Support:Scope(id)` 取得注册范围；目录型功能由共享 CatalogProvider 处理。不要在实现里再维护 products 数组，也不要依赖默认正式服。
6. 新增或移除运行文件时同步 `tools/release_manifest.json`，确认发布资源闭包。
7. 运行 `powershell -NoProfile -File tests/check_contract.ps1`；加载文件变化后需要重启游戏客户端。

`requires` 是启动前的函数存在性检查，例如 `C_EquipmentSet.UseEquipmentSet`，不调用该函数、不扫描数据。它不能代替版本化源码证据，也不替代动作执行时的条件检查。注册仍走现有 `_G.Lychee:RegisterProvider`，生成支持表不是另一个注册或启停系统。

## 不同客户端的不同实现

支持范围回答“能在哪用”，功能内部的实现选择回答“在这里怎么做”。现有技能书和游戏菜单已有真实分支；选择在各自功能内完成，不移到 Host。只有确实不同的业务才拆实现文件，不创建四份空实现。

以后需要按 interface/build 区间选择多个实现时，先按 [客户端差异约定](../../lychee-sdk/docs/CLIENT_VARIANTS.md) 明确唯一匹配、稳定身份、缓存版本和清理规则，再扩展构建清单与验证；当前清单不接受未经实现的新字段。不要把内部 Support 当作第三方 SDK。

## 目录刷新与语言资源

共享 CatalogProvider 管理单任务、取消、战斗暂停、分批读取、差量提交和完成通知。功能保留自己的缓存与业务判断，通过 `hasWork`、`onPause`、`onReady` 等内部协作点参与，不覆盖共享 MarkDirty，也不直接通知 Search.Session。`onReady` 返回 true 表示已经恢复等待查询，共享代码无需再次通知。

禁用目录时停止事件和任务，只保留最多 4096 个已提交 ID（值置 false），供恢复时删除过期记录；注销清空。这里不保留条目 payload，也不再读取 Host 私有 recordMap。新增目录类型必须验证禁用后数据删除、迟到任务和重新启用。

各功能的 `Locales.lua` 发布独立资源。同一个内置 ID 共用一个翻译器缓存，名单来自生成声明；资源根表、语言表或语言选择变化会失效。发布后的资源不可原地修改，更新时替换表。第三方注册继续使用独立编译和输入隔离，不进入这个内置缓存。

增加中英文文案时，验证实际搜索结果和动作消息，不仅检查字典能否编译。装备方案与天赋方案的同名键冲突测试用于防止跨功能误用翻译器。
