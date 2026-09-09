# lychee-sdk

Provider API 2 / revision 1 的开发包。它不是独立 AddOn，不要整包复制到正式服 AddOns。

- [接入教程](../docs/SDK.md)
- [协议参考](../docs/PROTOCOLS.md)
- `ApiStubs.lua`：LuaLS 类型声明，仅供编辑器使用，不写入运行时 TOC。
- `LycheeAPI.lua`：可选的 facade 检测、版本判断和 RegisterProvider 转发。
- `examples/ThirdPartyFixture/`：可独立安装的演示 AddOn，覆盖普通动作、信息条目、拖动与托管视图。
- `examples/DeferredProvider.lua`：可调用的延迟查询示例。

实际插件只依赖 Host `_G.Lychee`。TOC 使用 `## OptionalDeps: Lychee`。先判断 `Supports(2,1)`，再调用一次 RegisterProvider；后续通过返回句柄更新或注销。

API 2 不保留旧 Extension/Command 多角色接入流程，也不迁移旧数据。内置玩家技能使用相同公共入口，可以作为较完整的事件驱动实现参考。
