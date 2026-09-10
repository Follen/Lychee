# Ellesmere 设置页面 Provider

## 设计与成本预算

- 正式服专用。沿用 Provider API 2 / revision 6，默认关闭；启用后仅来源路由触发（默认 `EUI:` / `EUI：`）。输入只查询，点击才导航。普通搜索、登录、空闲不加载 EUI，不创建 Frame、不订阅事件。启用时若注册入口已存在则安装一次被动 hook；首次来源查询时也检查入口是否已经可用。
- 动态读取 `EllesmereUI._modules[folder].pages` 和 `L`、`TAB_LABEL_OVERRIDES`；不保存本机页面清单，不执行 buildPage，不提取私有 upvalue，不扫描框架树。完整动态页面目录独立于被动收集的具体设置，不能把后者声称为完整目录。
- 通过 `hooksecurefunc` 观察 `_RegisterSearchEntry`，同步检查 `_searchIndexSuppress`、裁剪名称、按模块/页/名称去重；保留 section、selectorSetter/key 和 label，点击交给 EUI 自己恢复选择项并导航高亮。不执行函数型 tooltip。最多 4096 条、2 MiB 字符串预算，单字段另有限额；selector 回调归上游所有，禁用时断开引用。hook 不可卸载，禁用时立即短路。
- 上游索引表、seen 表和 RunPrebuildPass 均为局部变量；没有可调用的枚举/补建接口。hook 前的首次注册无法回读，重新出现的同名注册只能以本次观察到的第一条为准，不能声称等同上游历史首条。首次查询不操纵 EUI 的搜索框，不强制其私有预建过程；具体设置随启用后的真实注册逐步补充。要无损导出历史且主动补齐，仍需 EUI 提供枚举和索引完成通知接口。
- 第一次前缀查询通过 EUI 自己的 EnsureLoaded 初始化设置代码，放到独立 timer 执行。其同步加载不可抢占、加载后的 EUI 数据由上游保留，不能把这部分成本说成已消除。游戏首次加载延迟待测。
- 每轮最多 128 个模块、4096 个页面、单模块 1024 页面；最多保留 50 个候选；每批最多 32 页或 1 ms。异常超限显示原因，不悄悄截断目录。无持久查询缓存；查询取消/结束/禁用后释放候选、协程和 timer。
- 页面标识可逆编码，和语言、排序无关。点击重新校验注册页面。解锁只调用 OpenUnlockMode，重复点击不切换退出。战斗中查询不加载、动作拒绝。
- 离线预算：1000 页 20 次查询累计分配 < 40 MiB，GC 后保留增长 < 256 KiB；每轮最多一个活动 timer，取消后为零；不增加 Frame/hook/event。耗时报告首次/热查询，不能换算游戏帧率。

## 版本证据

sourceId `ellesmereui`，product `main`，requestedRef/matchedTag `v9.1.8`，resolvedCommit `271ffc30d3265d9f77746b0e15224d918f0fafcb`。通过 wowdoc source list/check、inspect 核对：

- `EllesmereUI_GlobalSearch.lua:126` BuildCoarseCandidates：`for folder, config in pairs(EllesmereUI._modules or {})`；页面来自 `config.pages`，翻译来自 `EllesmereUI.L(page)`。
- `EllesmereUI_GlobalSearch.lua:22` `_RegisterSearchEntry`：先 `_searchIndexSuppress` 短路，再以模块/页/名称去重；存储译名、section、selectorSetter、selectorKey、isSection。`651` RunPrebuildPass 是局部函数，`879` RunSearch 从 sidebarSearchBox 触发，不能作为外部导出接口使用。
- `EllesmereUI.lua:5565` EnsureLoaded：加载 options addon 并执行 deferred inits；不等于逐页 buildPage。
- `EllesmereUI.lua:9316` NavigateToElementSettings：先 `_SplitFirstOpen`，随后 `Show / SelectModule / SelectPage`；section 为空时仍进入页面，不匹配任何滚动高亮目标。
- `EllesmereUI.lua:9860` RegisterModule：`modules[folderName] = config`。
- `EUI_UnlockMode.lua:12682` OpenUnlockMode：`ns.OpenUnlockMode()`；11915 开头已解锁则直接返回，战斗中拒绝；公开 `_unlockActive` 表示状态。
- 本机同版本 options：`EUI_RaidFrames_Options.lua:16` 为 `PAGE_CLICKCAST = "HoverCast"`，只有对应模块 namespace 存在才注册；`EllesmereUILocales/zhCN.lua:2427` 译为“悬停施法”。仅作为动态目录验收样本，不写入运行时映射。
- sourceId `wow-ui-source`，product `retail`，requestedRef `latest`，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`；`Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39` 定义 NewTimer(seconds, callback) 返回 cbObject。
- 同一暴雪版本，`Interface/AddOns/Blizzard_Dispatcher/Blizzard_Dispatcher.lua:260` 使用 `hooksecurefunc(functionOwner, functionName, function(...) ... end)` 观察 table 方法。

## 验证

- `tests/ellesmere_provider.lua`：真实 Host 前缀路由与普通搜索隔离、全角冒号、中英文、多字段词组、显示名称覆盖、模块增删、稳定引用、旧动作拒绝、战斗、缺失依赖、取消、禁用恢复、原生解锁幂等；细粒度收集排除/去重/动态 tooltip 不执行/分区与选择项恢复均通过。
- 1000 页查询一次离线总 CPU 6–8 ms，按 32 页或 1 ms 分批；20 次查询分配约 1664.8 KiB，GC 后未观察到保留增长，结束无活动 timer。首次三页替身低于本机时钟分辨率，不报告真实 EUI 初始化耗时。
- `powershell -NoProfile -File tests/check_contract.ps1` 全套通过；包含多客户端 TOC、语法与 i18n、SDK、搜索和性能检查。
- `wowdoc validate` 73 个 Lua 文件通过，无诊断；`git diff --check` 通过。
- **未执行游戏验证**：EUI 初次真实加载延迟、Hook 与 EUI 原生构建器组合、中文页面定位/高亮及解锁模式，须重启客户端后验证（新增 TOC 文件）。
