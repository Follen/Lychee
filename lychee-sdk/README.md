# lychee-sdk

Provider API 2.2 / revision 2 的开发包。它不是独立 AddOn，不要整包复制到正式服 AddOns。

- [接入教程](../docs/SDK.md)
- [协议参考](../docs/PROTOCOLS.md)
- [开发与验证](../docs/DEVELOPMENT.md)：示例安装、依赖与检查步骤。
- `ApiStubs.lua`：LuaLS 类型声明，仅供编辑器使用，不写入运行时 TOC。
- `LycheeAPI.lua`：可选的 facade 检测、版本判断和 RegisterProvider 转发。
- `examples/ThirdPartyFixture/`：可独立安装的演示 AddOn，覆盖普通动作、信息条目、拖动与托管视图。
- `examples/DeferredProvider.lua`：可调用的延迟查询示例。

实际插件只依赖 Host `_G.Lychee`。TOC 使用 `## OptionalDeps: Lychee`。先判断 `Supports(2,2)`，再调用一次 RegisterProvider；后续通过返回句柄更新或注销。

API 2 不保留旧 Extension/Command 多角色接入流程，也不迁移旧数据。内置玩家技能使用相同公共入口，可以作为较完整的事件驱动实现参考。

## API 2.2：产品和语言归 Provider 所有

新注册声明 `minApiRevision=2`、`scope.products` 和 `i18n`。产品数组包含 1–4 个不重复的 `retail`、`classic`、`titan`、`anniversary`；只声明已验证的客户端，不能凭相似 API 自动跨服启用。旧 API 2.1 没有产品声明时仅在正式服启用。

每个 Provider 独立注册 `i18n={enUS={KEY="English"},zhCN={KEY="中文"}}`，可增加 enGB／zhTW。enUS 是完整基线，其他语言可缺键，不能添加基线不存在的键。单语言最多 256 键，键最长 96 字节、值最长 1024 字节、全部资源不超过 128 KiB；翻译必须保留格式参数类型和顺序。回退顺序为精确 locale、同族 zhCN／enUS、enUS。

显示字段和动作标题使用严格的 `{key="KEY"}`；引用对象不能附带 locale、scope 或其他字段。aliases／keywords 可以包含键引用数组，普通字符串保持字面内容。`handle:Text("KEY", ...)` 用于格式化提示：最多 16 个参数，字符串参数不超过 1024 字节，输出不超过 32768 字节。相同键在不同 Provider 中相互隔离。

显示品牌：中文 `|cffd53c49荔枝|r启动器`，英文 `|cffd53c49Lychee|r Launcher`；描述分别为“魔兽世界万用启动器”和“Universal launcher for World of Warcraft”。客户端 locale 决定语言，与正式服／经典服产品身份独立。

示例 ThirdPartyFixture 提供 Mainline／Mists／Wrath／TBC 四份客户端 TOC，由仓库 `tests/build_client_tocs.py` 同步生成。新增客户端声明时须同步核对 TOC 和实际 API，不能只扩充 products 数组。
