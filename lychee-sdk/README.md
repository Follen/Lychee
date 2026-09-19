# Lychee Provider SDK

SDK **1.0.0** / Provider API **1.0.0** / UI Runtime **1**。这是开发包，不是独立游戏插件。Host 自带功能作为一个游戏插件发行，第三方保持独立 AddOn。本文描述当前接口；各客户端的实际验证范围见兼容说明，接口存在不代表所有实机场景均已通过。

1. 从[接入教程](docs/GETTING_STARTED.md)开始。普通来源直接交 `entries`，不必学习冷加载、预热或紧凑存储。
2. 对照[协议](docs/PROTOCOLS.md)定义条目、普通动作和恢复。参数动作按[Invocation](docs/INVOCATIONS.md)声明目标、动作和参数。
3. 需要冷加载时先运行完整独立 [ColdProvider](examples/ColdProvider/README.md)，再阅读[发现与加载](docs/LOADING.md)，需要大目录时阅读[目录工具](docs/CATALOG.md)。这些都是可选能力。
4. 数据仍属于你的插件：[独立存储](docs/STORAGE.md)、[可选紧凑存储](docs/COMPACT_STORAGE.md)、[资源](docs/MANAGED_RESOURCES.md)、[生命周期](docs/RUNTIME_LIFECYCLE.md)。
5. 页面使用[视图](docs/VIEW_LIFECYCLE.md)、[UI 库](docs/UI_LIBRARY.md)和[动效](docs/MOTION.md)，客户端差异见[多客户端](docs/CLIENT_VARIANTS.md)。

| 文件 | 用途 |
| --- | --- |
| [LycheeAPI.lua](LycheeAPI.lua) | 可选入口检查；精确匹配字符串版本。 |
| [ApiStubs.lua](ApiStubs.lua) | 编辑器类型，不写入游戏 TOC。 |
| [Storage.lua](Storage.lua) | 可嵌入的独立设置工具，需要自己的 SV 和就绪条件。 |
| [CompactStore.lua](CompactStore.lua) | 可选有界存储工具，不是集中业务数据库。 |
| [ThirdPartyFixture](examples/ThirdPartyFixture/ThirdPartyFixture.lua) | 普通动作、条目和页面示例。 |
| [ColdProvider](examples/ColdProvider/README.md) | 独立 TOC 冷声明、存档就绪、按前缀加载与普通动作；仅声明 Retail。 |
| [ManagedProvider](examples/ManagedProvider.lua) | 托管查询资源示例。 |
| [ComponentPanel](examples/ComponentPanel/ComponentPanel.lua) | 可复用页面示例。 |

第三方独立拥有代码、媒体、SV 与业务事实，不访问 LycheeInternal。Lychee 自带功能装配为一个包，不要求第三方采用其项目结构。支持版本、交付文件和性能说明分别见[兼容](docs/COMPATIBILITY.md)、[交付](docs/DELIVERY.md)、[性能](docs/PERFORMANCE.md)。性能页由仓库根规范生成，不能独立修改。
