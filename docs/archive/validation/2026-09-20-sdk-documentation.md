# 文档分层与双语 SDK

基线 `d1aae2b`。插件小更新 0.2.3；SDK / Provider API 仍为 1.0.0，UI Runtime 1。

## 本次改动

- 删除已退役接口的专属设计、验收材料与版本说明，清理内部注册器的冗余字段判断和对应专项测试。公开注册继续执行字段白名单与精确版本校验，构建合同改用完整字段白名单。
- 当前开发指南保留在 docs/guides；历史设计与验收集中到 docs/archive/design 和 docs/archive/validation；Comet 资料保留其工作流目录，单独标明历史属性。
- SDK 的 17 个专题按 docs/zh-CN 与 docs/en 配对；双语首页、专题目录、示例目录和 ColdProvider 说明均可独立浏览。英文性能页是 SDK 接入指南，链接完整中文政策，未将内部历史测量伪装成逐字译本。
- 构建清单包含全部双语文件；生成的中文性能页继续来自根政策。加入翻译缺页、语言切换、首页漏入口、英文漏交付及未知合同字段的故障注入检查。
- 本地 AGENTS.md 同步删除过时版本说明；该文件继续按项目政策留在本地。

## 验证

- 全部文档本地链接与锚点扫描通过；现行文档检查通过。原始 JSON、图片和测量数值未因路径搬移改写；按要求移除的旧接口输出行与专属文件可从 Git 历史追溯。
- repository_delivery 16 项、sdk_delivery 21 项通过；完整 tests/check_contract.ps1 通过。
- Lua 语法、Bindings XML、四客户端 TOC 与正式服 fallback、SDK 和发布清单通过。SDK 开发包 60 文件，游戏运行包 166 文件。
- 运行逻辑仅删除内部注册器的一项冗余判断，无新分配、事件、计时器或数据 schema 变化；其他运行改动为版本元数据。所有客户端的 TOC 加载文件和顺序不变。
- wowdoc 对实际改动的 ExtensionRegistry.lua 校验通过：checkedLua=1、diagnostics=[]、valid=true。完整 Mainline TOC 扫描持续数分钟仍无结果，已停止，不记作完整加载闭包静态验证通过。实机结果在交付后补充。
- 9 份当前构建数据/预览另迁到 assets/data/journal、assets/menu-icons/previews 和 assets/provider-icons/previews，SHA-256 均保持一致；怪物目录生成检查通过。
- 自动审批以 blocked by policy 拦截本地旧空目录/可再生 Python 缓存的清理。它们未受 Git 跟踪、未进入发布包，本轮保留。

wowdoc 依据：sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:165–179，GetAddOnMetadata 的参数为 name/variable，返回 value。未修改任何原生 API 调用；注册器清理由现行公开边界和完整契约核对。

未将历史记录的通过状态继承为当前结果；英文 SDK 内容人工对照现有协议与示例，自动检查仅负责配对、入口、链接、版本与交付闭包，不能证明译文语义本身。
