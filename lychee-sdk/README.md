# Lychee Provider SDK

[简体中文](README.md) · [English](README.en.md)

SDK **1.0.0** / Provider API **1.0.0** / UI Runtime **1**。这是可独立解压的开发包，不是游戏插件。第三方拥有自己的 AddOn、数据与媒体。

## 开始接入

- [接入教程](docs/zh-CN/GETTING_STARTED.md)
- [协议参考](docs/zh-CN/PROTOCOLS.md)
- [版本与兼容](docs/zh-CN/COMPATIBILITY.md)

## 搜索与动作

- [发现、加载与准备](docs/zh-CN/LOADING.md)
- [搜索目录与排名](docs/zh-CN/CATALOG.md)
- [参数调用与历史](docs/zh-CN/INVOCATIONS.md)

## 数据与生命周期

- [独立存储](docs/zh-CN/STORAGE.md)
- [可选紧凑存储](docs/zh-CN/COMPACT_STORAGE.md)
- [资源作用域与缓存](docs/zh-CN/MANAGED_RESOURCES.md)
- [运行时生命周期](docs/zh-CN/RUNTIME_LIFECYCLE.md)

## 页面与适配

- [页面生命周期](docs/zh-CN/VIEW_LIFECYCLE.md)
- [UI 库](docs/zh-CN/UI_LIBRARY.md)
- [动效](docs/zh-CN/MOTION.md)
- [客户端与 build](docs/zh-CN/CLIENT_VARIANTS.md)
- [第三方适配](docs/zh-CN/ADAPTER_COMPATIBILITY.md)

## 验证与交付

- [性能要求](docs/zh-CN/PERFORMANCE.md)
- [SDK 交付](docs/zh-CN/DELIVERY.md)

## 示例与文件

[示例导航](examples/README.md)：普通注册、冷加载、托管任务与可复用页面。

[LycheeAPI.lua](LycheeAPI.lua) 是可选版本/错误辅助，[ApiStubs.lua](ApiStubs.lua) 仅供编辑器。按需嵌入 [Storage.lua](Storage.lua) 或 [CompactStore.lua](CompactStore.lua)，不访问 LycheeInternal，不把整个 SDK 放进 AddOns。
