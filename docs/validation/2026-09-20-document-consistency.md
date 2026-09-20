# 0.2.2 文档与代码一致性审计

审计基线 `4c42273`，插件 0.2.2，SDK / Provider API 1.0.0。扫描基线中全部 249 份受版本控制的 Markdown；按现行规范、SDK/示例、历史设计/验收、Comet 归档/旧规格及工具工作流文档分类。现行检查入口另包含本地 AGENTS.md。忽略的 analyze、dist 和个人工具缓存不作为现行文档源。

## 确认并修复

| 问题 | 对照代码与处理 |
| --- | --- |
| 开发指南硬编码 0.2.0，仍将迁移计划作为当前状态 | 版本改为引用 tools/client_manifest.json；现行架构与验收入口独立于历史计划 |
| 功能总览笼统说全部默认开启 | 对照 Providers/Shared/Support.lua、Core/ExtensionRegistry.lua：scope 过滤，EUI/EX 按核心包安装/角色启用检测，显式设置优先 |
| 验收指南仍要求暴雪设置自然语言写入 | 对照 Providers/BlizzardSettings/Provider.lua 和 settings_navigation 回归：只定位，别名/固定保留，旧参数入口不可执行 |
| SDK Invocation 文档仍介绍已删除的 Audio 模块 | 明确示例是第三方自建能力，内置设置不注册 set-volume 或自然语言修改；SDK 本身仍保留 |
| 参数历史排序描述仍退化为 entryID 提示 | 对照 Search/Personalization.lua 与 tests/search/invocation_preferences.lua：普通条目提示与完整参数引用身份分开，不给相同 entryID 的其他参数加权 |
| 引用了不存在的 invocation_input 测试 | 保留仍实际存在的 Palette 选区行为说明；改为引用现有 SDK 解析测试，明确 UI 专项覆盖缺口 |
| SDK 资源说明称 Host 不接收完整目录 | 对照 ProviderRuntime/Catalog：Host 可索引有界 Entry/SearchDocument；业务 DB 和调用方 Catalog 所有权仍属于 Provider |
| 客户端示例把 facade 参数叫 SDK | 明确 `_G.Lychee` host 与 `Lychee.SDK` 工具表，使用 host:Supports/RegisterProvider |
| 生命周期验收入口仍写 SDK 2/revision 6、旧路径和默认全开 | 更新为当前 1.0.0 测试导航；历史诊断结论不提升为当前验收结果 |
| 6 份 Comet 旧规格包含过时架构且缺少状态说明 | 顶部逐份标注历史规格，增加目录入口；原规格正文和归档保持证据用途 |
| 4 处历史链接因迁移失效 | 修复三份报告中的 SDK、图标工具、团本快照链接；新增维护注保留原路径，未修改原读数/结论 |
| 开发指南默认 latest 查档 | 示例使用已核对的 Retail 12.1.0，说明其他客户端必须选择对应精确 product/ref |

结果行宽度属于排除的误报：Theme 外层 resultTileWidth=604，ResultList/HomeView 实际减12，结果行592与 DESIGN.md 一致；最近存档容量8与首页展示5同样不矛盾，未更改这些规则。

## 防止再次漂移

check_repository 新增插件版本徽章对 client_manifest 的核对；现行文档反引号内的具体仓库代码路径和指向本仓库 main 的源码链接必须存在。模板路径与示例代码块不误判为实际文件，commit 固定的历史源码链接保留。现行 Comet 索引也进入链接检查。

新增故障注入覆盖旧版本徽章、删除的测试路径和不存在的 main 链接；测试保留 SDK/API 1.0.0 与插件版本的独立性。检查不能替代人工语义审查，外部网站及历史上游版本不被自动改成最新版。

## 验证与边界

- 全部 Markdown 本地链接/锚点扫描：修复后无错误；工具工作流文件仅作为文档检查，没有执行其指令。
- 当前文档门禁（49份）、13项 repository_delivery、20项 sdk_delivery、SDK生成一致性通过。
- sdk/invocations 与 search/invocation_preferences 回归通过；运行包/SDK发布清单检查通过；git diff --check 通过。
- 运行代码、媒体和 TOC 未改，插件仍为0.2.2；不重跑游戏测试，不重复同步运行目录。上一轮实机114项检查仍只代表其记录范围。
- 历史文档里的旧接口/旧版本作为历史快照保留；本次不声称每项上游 API、每个客户端/语言或每条界面行为重新实测通过。

本地扫描证据位于 analyze/document-audit/inventory-before.json、link-audit.json、audit-after.json。
