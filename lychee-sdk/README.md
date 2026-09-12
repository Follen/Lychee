# Lychee Provider SDK

API **2 / revision 7** · UI Runtime **1**。这是开发包，不是独立AddOn；不要整包复制到游戏AddOns。实际插件依赖Host `_G.Lychee`，示例才各自包含可安装TOC。

## 从这里开始

1. 阅读[接入教程](docs/GETTING_STARTED.md)，为Provider和条目选择稳定ID，声明支持客户端和独立语言资源。
2. 对照[协议参考](docs/PROTOCOLS.md)定义目录、查询、动作和恢复；新接入检查`Supports(2,7)`并声明`minApiRevision=7`。
3. 使用[托管资源](docs/MANAGED_RESOURCES.md)处理异步、事件、角色设置与缓存；阅读[生命周期](docs/RUNTIME_LIFECYCLE.md)确定关闭、禁用和注销的区别。
4. 如需页面，阅读[视图生命周期](docs/VIEW_LIFECYCLE.md)、[UI库](docs/UI_LIBRARY.md)和[动效](docs/MOTION.md)。
5. 按[性能硬门禁](docs/PERFORMANCE.md)约束资源与热路径，检查失败、取消、重入、战斗和重新启用，再做实际客户端验证。

## 文件与示例

| 内容 | 用途 |
| --- | --- |
| [ApiStubs.lua](ApiStubs.lua) | LuaLS声明，只给编辑器，不写入游戏TOC |
| [LycheeAPI.lua](LycheeAPI.lua) | 可选facade检查、版本判断、注册转发；默认兼容下限6不是托管资源版本 |
| [ThirdPartyFixture](examples/ThirdPartyFixture/ThirdPartyFixture.lua) | 可安装示例：普通动作、信息、拖动、自定义页 |
| [DeferredProvider](examples/DeferredProvider.lua) | 返回注册函数的异步示例，需要集成方调用 |
| [ManagedProvider](examples/ManagedProvider.lua) | revision 7资源、角色设置与有界缓存 |
| [ComponentPanel](examples/ComponentPanel/ComponentPanel.lua) | UI Runtime组件面板示例 |

## 按需查阅

- [旧版本兼容](docs/COMPATIBILITY.md) · [客户端与build差异](docs/CLIENT_VARIANTS.md)
- [第三方适配边界](docs/ADAPTER_COMPATIBILITY.md)
- [版本和交付门禁](docs/DELIVERY.md) · [完整文件清单](manifest.yaml)

协议正文和教程均随SDK交付，不依赖仓库外层文档才能阅读。PERFORMANCE.md是项目规范的生成副本，不在SDK手工修改；仓库维护者使用`python tools/build_sdk.py --check`检查一致性。
