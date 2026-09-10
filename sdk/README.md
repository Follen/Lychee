# Lychee SDK 文档入口

当前开发包位于 [lychee-sdk](../lychee-sdk/README.md)，接口版本与接入约定以该开发包为准。本目录仅保留旧路径的文档导航，没有 SDK 代码，不是另一个开发包或可安装 AddOn。

Lychee 是游戏内通用搜索工具。内置功能和第三方插件通过 `_G.Lychee:RegisterProvider(definition)` 提供条目及交互；Host 统一搜索、排序、展示和执行校验。不提供旧多角色注册流程的兼容层。

- [SDK 接入](../docs/SDK.md)：注册、更新、延迟查询、动作、拖动和托管视图。
- [客户端与 build 差异](../lychee-sdk/CLIENT_VARIANTS.md)：同一 Provider 的多版本业务实现约定。
- [协议参考](../docs/PROTOCOLS.md)：字段、生命周期、限制与错误码。
- [架构](../docs/ARCHITECTURE.md)：Host 与 Provider 的职责边界。
- [开发与验证](../docs/DEVELOPMENT.md)：安装、运行测试和客户端验收。

当前运行时代码位于 `package/Lychee`。`docs/comet/` 为历史工作流资料，当前接口以以上文档和 `lychee-sdk` 为准。
