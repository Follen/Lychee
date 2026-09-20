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
- wowdoc 对实际改动的 ExtensionRegistry.lua 校验通过：checkedLua=1、diagnostics=[]、valid=true。完整 Mainline TOC 扫描持续数分钟仍无结果，已停止，不记作完整加载闭包静态验证通过。
- 9 份当前构建数据/预览另迁到 assets/data/journal、assets/menu-icons/previews 和 assets/provider-icons/previews，SHA-256 均保持一致；怪物目录生成检查通过。
- 自动审批以 blocked by policy 拦截本地旧空目录/可再生 Python 缓存的清理。它们未受 Git 跟踪、未进入发布包，本轮保留。

wowdoc 依据：sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:165–179，GetAddOnMetadata 的参数为 name/variable，返回 value。未修改任何原生 API 调用；注册器清理由现行公开边界和完整契约核对。

未将历史记录的通过状态继承为当前结果；英文 SDK 内容人工对照现有协议与示例，自动检查仅负责配对、入口、链接、版本与交付闭包，不能证明译文语义本身。

## 实机与交付

- 实现提交 `a99eb54437b9e570f8aeeed687373699430e4074`；游戏目录覆盖同步 166 个运行文件，逐一核对 SHA-256。插件清单版本为 0.2.3，原有 TOC 加载路径与顺序未变。
- lychee-dev 后台消息通路完成输入重载、执行、输出重载、完整报告读取与 ACK。客户端 Retail 12.1.0.69875 / Interface 120100 / zhCN；角色晴昼秋岚，白银之手。
- Ticket `LYCHEE-20260920-102750-0032`；task `docs-sdk-audit`，requestId `docs-sdk-20260920-01`，revision `docs-sdk-1`。报告 complete=true、outputTruncated=false，24 项通过、0 项失败。
- 覆盖 Host 就绪、精确版本协商、8 项能力声明、16 个内置 Provider 注册、暴雪设置导航动作声明、错误版本与未知字段拒绝，以及临时 Provider 的注册、更新、停用、恢复、注销和无残留检查。能力声明与动作声明检查不代表相关功能的完整交互验收。
- 完整 payload 为 `%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260920-102750-0032/content.json`，同目录保留 report.json 和 evidence.json。UTF-8 2518 字节，Adler-32 `010f5f3c`，SHA-256 `86e057722ea089bb9b1cc98622a9752dc29ac4f9abb27792645e52a9651247b6`。
- ACK received 已确认；nonce `req-20260920-022836-422511` 对应 ticket_ack_cleared 已记录。仅移除本次自有任务区块，保留其他任务。
- 构建得到 dist/Lychee.zip（166 文件）和 dist/lychee-sdk.zip（60 文件）；后者包含双语文档与示例。游戏包不包含 SDK、文档、测试和工具状态。

本轮未做其他客户端或语言的实机验收，也未重测完整搜索、界面交互和性能矩阵。探针的 expectedPlugin 字段是测试预期，不能替代客户端元数据观测；版本依据为提交清单与已同步文件。
