# lychee-sdk

当前 SDK 为 API 2 / revision 7，UI Runtime 仍为 1。新增公共资源生命周期、角色设置和有界缓存，见 [托管资源协议](MANAGED_RESOURCES.md)；旧 revision 1–6 的 Provider 保持兼容。

Provider API 2 / revision 7 的开发包。它不是独立 AddOn，不要整包复制到正式服 AddOns。

版本与文件交付由[构建期契约](DELIVERY.md)统一检查。helper 的 `API_REVISION=7` 表示当前能力，`MIN_API_REVISION=6` 保留省略参数时的旧兼容下限；使用 revision 7 功能必须显式检查 7。运行 `python tools/build_sdk.py --check` 可检查 Host、类型、helper 和交付清单是否同步。

统一控件、受控状态和懒创建面板参见 [UI 库](UI_LIBRARY.md)。UI Runtime 1 独立版本化，
可通过 AsView 接入既有 Provider 面板生命周期，不更改 Provider API 2.6 的业务协议。

自定义面板优先阅读[可复用视图与生命周期](VIEW_LIFECYCLE.md)：工厂每次调用、Provider显式缓存、
关闭时Unmount→Dispose、部分失败恢复与回调重入规则。TOC加载代码、Provider初始化、索引构建和UI创建是不同阶段，
“窗口按需创建”不代表对应Lua尚未加载。第三方适配契约见[适配与兼容性](ADAPTER_COMPATIBILITY.md)。

新接入推荐 revision 7，包含 revision 6 的搜索入口：`searchGlobal=true, searchPrefixes={"scope"}, searchKeywords={"openlist"}`，普通搜索与两类入口同时可用。检查 `Supports(2,7)` 并声明 `minApiRevision=7`；空词表移除对应入口，不与旧 searchMode 混用。旧 revision 1–5 声明保持原效果，用户可在管理页明确组合。详见 [SDK 接入](../docs/SDK.md)。

revision 5 新增 `searchMode="keyword", searchKeywords={"quick","快捷"}`。检查 `Supports(2,5)`，声明 `minApiRevision=5`；Host 负责精确触发和来源隔离，query 收到空文本及本来源 sourceID，无需重复判断触发词。用户可在管理页修改触发词或切换模式。触发词和冒号前缀互不混用；保留旧独立查询兼容。完整示例、冲突与生命周期语义见 [SDK 接入](../docs/SDK.md)。

revision 4 新增 `searchMode="global"|"prefix"` 和 `searchPrefixes={"前缀","prefix"}`，支持默认仅前缀搜索及用户管理页覆盖。使用时检查 `Supports(2,4)` 并声明 `minApiRevision=4`；与 `searchable=false` 的独立查询模式互斥。旧回调收到的 request.filter 结构不变，不暴露 Host 内部策略条件。

revision 3 新增可选 `searchable:boolean`，默认 true。`searchable=false` 的 entries 不参与通用搜索和别名召回，但仍支持更新、引用解析、动作及动态 query。使用时声明 `minApiRevision=3` 并检查 `Supports(2,3)`；旧 Provider 继续保持原行为。完整边界见接入教程。

- [接入教程](../docs/SDK.md)
- [协议参考](../docs/PROTOCOLS.md)
- [Ellesmere 动态设置适配](../docs/validation/2026-09-11-ellesmere-provider.md)：使用现有 revision 6 前缀、延迟查询、稳定引用和普通动作，不新增 Host 专用协议。上游没有索引枚举接口时，区分动态页面目录与被动收集的具体设置，不以 hook 宣称完整覆盖。
- [Exwind 动态设置适配](../docs/validation/2026-09-11-exwind-provider.md)：复用 revision 6，只读第三方公开的模块、静态布局与路由声明；分批搜索、点击时重新校验目标，不为索引执行布局生成函数或创建设置框体。
- [开发与验证](../docs/DEVELOPMENT.md)：示例安装、依赖与检查步骤。
- `ApiStubs.lua`：LuaLS 类型声明，仅供编辑器使用，不写入运行时 TOC。
- `LycheeAPI.lua`：可选的 facade 检测、版本判断和 RegisterProvider 转发。
- `examples/ThirdPartyFixture/`：可独立安装的演示 AddOn，覆盖普通动作、信息条目、拖动与托管视图。
- `examples/DeferredProvider.lua`：可调用的延迟查询示例。
- `examples/ManagedProvider.lua`：revision 7 托管资源、角色设置与缓存示例。

实际插件只依赖 Host `_G.Lychee`。TOC 使用 `## OptionalDeps: Lychee`。先判断 `Supports(2,2)`，再调用一次 RegisterProvider；后续通过返回句柄更新或注销。

用户自定义别名和查询选择记忆由 Host 管理，不需要增加 SDK 字段，也不改写 Provider 声明的 `aliases`。保持 Provider ID 与 entry ID 稳定；动态条目提供 `resolve` 才能跨查询恢复。来源停用或条目暂不可用时，用户别名不能绕过可用性和动作权限检查。名称翻译或改名不应改变业务 ID。

API 2 不保留旧 Extension/Command 多角色接入流程，也不迁移旧数据。内置玩家技能使用相同公共入口，可以作为较完整的事件驱动实现参考。

## API 2.2：产品和语言归 Provider 所有

新注册声明 `minApiRevision=2`、`scope.products` 和 `i18n`。产品数组包含 1–4 个不重复的 `retail`、`classic`、`titan`、`anniversary`；只声明已验证的客户端，不能凭相似 API 自动跨服启用。旧 API 2.1 没有产品声明时仅在正式服启用。

每个 Provider 独立注册 `i18n={enUS={KEY="English"},zhCN={KEY="中文"}}`，可增加 enGB／zhTW。enUS 是完整基线，其他语言可缺键，不能添加基线不存在的键。单语言最多 256 键，键最长 96 字节、值最长 1024 字节、全部资源不超过 128 KiB；翻译必须保留格式参数类型和顺序。回退顺序为精确 locale、同族 zhCN／enUS、enUS。

显示字段和动作标题使用严格的 `{key="KEY"}`；引用对象不能附带 locale、scope 或其他字段。aliases／keywords 可以包含键引用数组，普通字符串保持字面内容。`handle:Text("KEY", ...)` 用于格式化提示：最多 16 个参数，字符串参数不超过 1024 字节，输出不超过 32768 字节。相同键在不同 Provider 中相互隔离。

显示品牌：中文 `|cffd53c49荔枝|r启动器`，英文 `|cffd53c49Lychee|r Launcher`；描述分别为“魔兽世界万用启动器”和“Universal launcher for World of Warcraft”。客户端 locale 决定语言，与正式服／经典服产品身份独立。

示例 ThirdPartyFixture 提供 Mainline／Mists／Wrath／TBC 四份客户端 TOC，由仓库 `tools/build_client_tocs.py` 同步生成。新增客户端声明时须同步核对 TOC 和实际 API，不能只扩充 products 数组。

## 同一 Provider 的版本差异

允许不同客户端／build 使用不同业务实现。同一业务保持一个 Provider ID，由 Provider 在注册前选择唯一适配器，再向 Host 提交该实现的完整 scope、i18n 和回调。支持范围不等于实现相同；不能同时注册多个同 ID 分支。目录结构、选择规则、身份／缓存和验收要求见 [客户端与 build 差异约定](CLIENT_VARIANTS.md)。

动效接口与分层规范见 [MOTION.md](MOTION.md)；完整可安装示例见 [ComponentPanel](examples/ComponentPanel/ComponentPanel.lua)，仅供 SDK 开发使用，不随 Lychee 运行时同步。
