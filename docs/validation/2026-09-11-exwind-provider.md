# Exwind Provider

## 范围与成本预算

- 正式服专用、默认关闭；启用后以 `ex:` / `ex：` 路由，大小写由 Host 统一处理，普通搜索不加载/查询。复用 Provider API 2 revision 6，不改搜索引擎、不复制 EUI 收集 hook。
- 只读 UnifiedPanel.Providers/ProviderMeta、ModuleList、EditModeState.modules/routers、ModuleDefinitions.definition.settings.layout 和 RegisteredLayouts。旧布局与新声明都支持；不执行函数布局、getter、预览构建、可见性回调，不遍历 SavedVariables 或框架树。HideCfg/hidden/visible 排除项保留。
- 工具模块与 ExBoss 编辑模块动态读取名称、路由；ExBoss.ModuleList 的 PanelTab 支持禁用但仍可配置的工具。没有声明目录的内部私有页面不伪造地址。语音/语言/数据包没有单独注册面板时不制造重复入口。
- 静态设置名称匹配后显示所在模块与命中名称，点击进入设置页，不声称控件滚动/高亮。`ex:解锁` / `ex:unlock` 使用 ToggleEditMode(true)，已激活时不反向退出。
- 不增加 Frame、hook、事件、空闲 ticker；无持久索引，引用不跨会话保留；查询结束/取消/禁用释放协程、候选与 timer。每批 32 次检查或 1 ms，总检查上限 32768，模块候选上限 1024，保留前 50 个。布局循环去重、深度 8、单层 2048 项；超限明确报错。
- 验证预算：1000 个静态设置的 20 次查询分配 < 16 MiB，GC 后增长 < 256 KiB；不产生设置 UI，不执行任何 get/set/build 回调。分别报告查询总耗时与离线局限。点击仍使用 Exwind 自身布局工作，实际首次开页耗时待游戏测试。

## 源码依据

wowdoc 当前 source catalog 不含 Exwind，适配依据是本机安装包（只读，不修改第三方源码）：ExwindCore 6.0.0 / Interface 120100，ExwindTools 1.0 / 120100，EXBoss 1.0.0 / 120007。安装文件哈希在验证时记录；不伪称为上游 Git commit。

- `ExwindCore/Core/Panel/ExwindUnifiedPanel.lua:25`：公开 Providers、ProviderMeta；1072 Show(providerID, route) 负责实际打开。
- `ExwindCore/Core/Panel/ExwindToolsPanelProvider.lua:121`：ApplyRoute 使用 route.moduleKey 进入 ModuleSettings。
- `ExwindCore/Core/ExwindTools.lua:104`：ModuleList 是工具导航真源；855 RegisterModuleLayout 保存 RegisteredLayouts。
- `ExwindCore/Core/Renderer/ExwindModuleDefinition.lua:136`：ModuleDefinitions 保存 controller.definition；settings.layout 可以是表或函数，本适配仅读表。
- `ExwindCore/Core/Renderer/ExwindEditMode.lua:62`：公开 EditModeState；1010 注册声明含 addon、key、name、settingsPage；1061 OpenModuleSettings 调用已注册 router；1071 ToggleEditMode(forceState) 支持 true。
- `EXBoss/Core/ExBoss_ModuleRegistry.lua:21`：ModuleList 元数据含 Key、Name、PanelTab；`EXBoss/Core/ExBoss_ModuleSettingsRouter.lua:24` 是 EXBoss 设置导航白名单，禁止从模块名字猜 tab。
- `EXBoss/ExBossGUI/UnifiedPanelProvider.lua:34`：ApplyRoute 接收 route.tab。
- wowdoc sourceId `wow-ui-source` / product `retail` / requestedRef `latest` / resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39` 声明 NewTimer(seconds, callback)。

## 验证结果

- `tests/check_contract.ps1` 全套通过，包括 Lua/XML/TOC、客户端清单、国际化、SDK、搜索回归和性能检查。
- `tests/exwind_provider.lua` 覆盖大小写/全半角冒号、全局隔离、缺依赖、静态旧布局与模块定义、隐藏项、循环布局、动态增删、页面路由、解锁幂等、战斗限制、取消与停用、超限提示。回归测试捕获并修复了无 ModuleDefinitions 时静态布局回退被 false 截断的问题。
- 1000 个设置：首次查询 CPU 8 ms；20 次查询合计 413 ms，分配 1556.2 KiB，GC 后增长 0 KiB，新增 Frame 0。查询分批执行；这是离线 Lua 测试，不代表游戏帧耗时。无查询时无工作。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：75 个 Lua 文件通过，无诊断。
- 新增 TOC 模块，需要重启客户端后在功能来源中启用 Exwind；实际游戏导航、首次开页耗时与编辑模式仍待实机验证。

## 本机源码 SHA256

| 文件 | SHA256 |
| --- | --- |
| `ExwindCore/Core/Panel/ExwindUnifiedPanel.lua` | `3BA2C70A4187158467DB15A9A8837CCD1ECBDF87D767A317A3ED1AFD95EA6228` |
| `ExwindCore/Core/Panel/ExwindToolsPanelProvider.lua` | `C4BEB794A997862386DCDF3A465968F978056E568F1B452E9FC8D2D0FBB989D1` |
| `ExwindCore/Core/ExwindTools.lua` | `16B8D6CD89A63872D50C1B8255C2E7553AA635F3C6C64D2E1951BE558548FBF8` |
| `ExwindCore/Core/Renderer/ExwindEditMode.lua` | `4C56A15BE3052742D8D457005BD1E25CD279C3F64BA483664F795CEF14C6207C` |
| `ExwindCore/Core/Renderer/ExwindModuleDefinition.lua` | `1367F71AA7D77D316B779E1847CC1AA67283B7396A706E7985358E942A3482B8` |
| `EXBoss/Core/ExBoss_ModuleRegistry.lua` | `AAC3166012F9ACCFFEB4CB00DCE397566F4FDDF4691EA9E27D59EEF07714A524` |
| `EXBoss/Core/ExBoss_ModuleSettingsRouter.lua` | `F3AA573D259227A9BD54C40288E144CB5CA0731BA8F5E0EC33BA8889BCE75213` |
| `EXBoss/ExBossGUI/UnifiedPanelProvider.lua` | `5E8CF020F1B3749BDAFD21764A95318A4091DF8F84A0F1526E3BEE8451D1C759` |
