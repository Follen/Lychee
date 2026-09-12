# 项目结构与维护入口

运行时源统一位于 `addon/` 下的五个包：Lychee、Lychee_Player、Lychee_Encounters、Lychee_Integrations、Lychee_Inspector。职责见[架构](../ARCHITECTURE.md)。没有 Builtin 或类似的集中业务目录。

每个功能在所属子插件内维护 Provider.lua、Locales.lua 和必要的专用数据/视图；只有真正复杂的功能拆更多文件。Player 拥有钥匙和所有玩家/暴雪界面功能；Host 只提供通用搜索与 UI。

`tools/client_manifest.json` 是唯一包归属和客户端支持清单；每个 Provider 声明 package/id/module/products/requires/locales/files/presentation。packages 中每个 Provider 只能有一次加载位置，语言资源先加载，不能跨包引用或重复路径。

运行 `python tools/build_client_tocs.py` 生成五包×四客户端 TOC、正式服 fallback、各自 Manifest/Bootstrap/Activate，以及 SDK 示例 TOC。模板仅用于本项目，不是 SDK 的公共装配接口。Player 的 SDK/Storage.lua 来自开发包；两包相同目录辅助代码以 Player 副本为生成源，构建检查漂移。

新增文件须更新 `tools/release_manifest.json` 对应包的明确清单。`tools/build_release.py --check` 拒绝未列文件、文档混入运行时、越界路径、符号链接和不完整 TOC。SDK、docs、assets、analyze 不进 AddOns。

首领关系和 LDT 事实数据由构建工具生成并用独立快照校验，不手改生成行。首领技能关系用内部 base36 差值编码节省只读字符串；这不是 SDK 条目格式，也不改变 ID、难度或动作。

新增功能按[国际化规则](../../i18n.md)、[设计规则](../../DESIGN.md)和[性能硬门禁](../../PERFORMANCE.md)实施。第三方只需[公开 SDK](../../lychee-sdk/docs/GETTING_STARTED.md)，不得依赖任何项目 Manifest、Modules 或 LycheeInternal。
