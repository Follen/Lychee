# Provider 结构整理与生命周期验证

基线提交：`87c5929`。本次包含内置声明统一、按功能归档、语言所有权修正和目录刷新收敛。

## 改动和成本约束

- `tools/client_manifest.json` 是 13 个内置功能的唯一支持声明，生成四客户端 TOC、正式服 fallback 和 `Builtin/Definitions.lua`。文件加载、启动筛选、注册 scope 以及内置翻译缓存的已知 ID 均消费该声明。
- 运行期支持表只含固定声明，不扫描角色数据；启动时检查一次客户端和所需函数。无新增 Frame、事件、timer、hook 或 OnUpdate。未选中功能的业务文件和语言文件不加载。
- 各功能实现、语言和专用数据放在 `Builtin/<功能>/`；通用支持、界面动作和目录刷新在 Shared。Core、Search、UI、Secure、PublicAPI 的原有职责保留。
- 同一内置 ID 缓存一个翻译上下文，上限由声明集合约束。资源或语言表替换、locale 变化使其失效；发布后不支持原地改表。第三方独立注册时的编译和输入隔离保持。
- 每目录仍最多 1 个活动任务、1 个复用事件 Frame；读取按原数量上限和 1 ms 检查分批，提交最多 16 条一批。战斗暂停、恢复重试、禁用取消保持。
- 禁用后保留最多 4096 个已提交 ID，值为 false，不保留条目 payload；用于重新启用时删除过期记录。注销清空。共享代码不再读取 Host 的私有 recordMap。
- 成就保留自己的缓存和异步查询生命周期；共享代码负责完成通知，避免业务重复协调 Search.Session。
- 复审发现并补修成功提交后同步禁用的 ID 遗漏；记录成功提交时校验句柄与账本身份。注销并重新注册后，旧提交不得写入新账本。

预算沿用 PERFORMANCE.md，不提高现有阈值：固定搜索常驻低于 7.25 MiB、48 次查询累计分配低于 4 MiB、重复保留增长低于 512 KiB；功能目录、UI 池、取消与事件生命周期仍受原测试门禁约束。此轮主要提高维护可靠性，不宣称游戏帧率收益。

## 自动验证

完整 `powershell -NoProfile -File tests/check_contract.ps1` 通过。新增验证：

- 构建清单覆盖四客户端、13 个功能归属；拒绝重复 ID、未知产品、重复加载、无效能力名称与越界路径；支持声明改变会同时反映到文件选择与运行时 scope。
- 四 TOC × 两语言实际加载；补充所有必需函数齐备时每个支持功能只启动一次，逐个缺失函数时拒绝启动，未知客户端不启动。
- 装备与天赋给同名键设置不同文案，通过实际目录扫描和动作错误消息验证语言所有权；20,000 次热读取零重新编译、回收后增长 0.0 KiB。
- 目录测试不提供 Host 私有 Registry：提交失败重试、禁用期间删除、迟到回调、战斗暂停、完成时禁用、提交中禁用、提交中注销重注册全部通过。100 次启停 Frame=1、闲置任务=0、回收后增长 0.00 KiB。
- 原有搜索匹配、最近使用与空格、动画、背包四种界面定位、成就十角色缓存、第三方注册与安全交互回归全部通过。
- 66 个 Lua 文件通过 luac；XML 可解析；TOC 生成检查和 Python 语法通过；git diff --check 通过。
- wowdoc 四产品 validate 均返回 `valid=true`，各检查 66 个 Lua 文件，无诊断。

## 离线测量

环境：本机 Windows、Lua 5.1；同一固定输入。下表为改前与最终改后单次样本，不用计时波动推断稳定加速或回退。

| 场景 | 改前 | 最终改后 |
| --- | ---: | ---: |
| 2,689 条记录，回收后常驻 | 7,233.5 KiB | 7,235.7 KiB |
| 48 次查询累计分配 | 1,812.2 KiB | 1,812.2 KiB |
| 重复查询保留增长 | 0.1 KiB | 0.1 KiB |
| 平均查询耗时 | 0.354 ms | 0.354 ms |
| 英文首领固定 65 条、批次数 | 43 | 43 |
| 英文首领累计分配 | 2,822.8 KiB | 2,818.6 KiB |
| 英文首领停用后保留 | 137.3 KiB | 142.7 KiB |
| 英文首领单批峰值 | 2 ms | 3 ms |

首领停用保留增加来自已提交 ID 账本，用于恢复清理；其活动 timer 结束为 0，Frame 峰值 1。单批原生调用不可抢占，1 ms 检查不保证每批最多 1 ms；本轮不同样本峰值有 2–3 ms 波动，未宣称尾延迟改善。成就最终 warm10：53 ms、6,524.7 KiB 累计分配、0.0 KiB 保留增长、0 次成就信息读取；目录新增场景常驻 2,323.2 KiB，原预算通过。

本机完整原始输出保存在 `.codex/architecture-validation/contract.txt`，不随插件交付。

## wowdoc 来源

均为 `sourceId=wow-ui-source`、`requestedRef=latest`，已执行 source list/check。

| product | resolvedCommit | path / line / excerpt |
| --- | --- | --- |
| retail | `8ea15b61e45c0ed4eba01439c90757f86eb78d34` | `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39`，`Name = "NewTimer"`，seconds:number、callback:TickerCallback，返回 cbObject |
| classic | `ecadf9d3326fa87828cacca7f13c0ab5f41840a6` | 同路径 `:37`，相同参数与返回定义 |
| titan | `ba472e5e1b5580b557e3dbf02c9e5ff23b223347` | 同路径 `:37`，相同参数与返回定义 |
| anniversary | `d1a0a86b449c78ee352e8851ef4b011add16a2ff` | 同路径 `:37`，相同参数与返回定义 |

retail 另查：`BuildDocumentation.lua:10` 的 GetBuildInfo 返回 buildVersion、buildNumber、interfaceVersion；`EquipmentManagerDocumentation.lua:287` 的 UseEquipmentSet；`ClassTalentsDocumentation.lua:92` 的 GetConfigIDsBySpecID。上述文档路径均在 `Interface/AddOns/Blizzard_APIDocumentationGenerated/`，commit 同 retail。事件使用证据为 `Interface/AddOns/Blizzard_BoostTutorial/Blizzard_TutorialLogic.lua:1497` 的 `Class_LootCorpseWatcher:PLAYER_REGEN_DISABLED` 与 `Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua:193` 的注册关系。

## 交付与尚待实机验证

运行时同步到 `D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`；文件移动改变了 TOC，必须重启客户端，不能仅依赖 /reload。默认保留目标旧路径文件，新 TOC 不引用它们；不把保留旧文件描述为文件清单完全一致。

未运行真实客户端：登录、站立空闲、单目标/团本战斗、界面开关、受保护点击和 taint，以及其他三个客户端均待实机验证。没有新增姓名板相关逻辑；离线结果不能替代这些场景。回滚采用新 git revert 提交，验证后按项目约定同步。
