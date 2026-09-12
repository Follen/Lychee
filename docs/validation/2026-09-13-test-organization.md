# 五包 / API 3 测试整理与补充

基线提交：`67aea47fa8a7a1c8e14b075c8c4c63561e76eb72`。本轮修改测试、装配和文档，没有修改 addon 下运行代码、TOC、媒体或加载顺序。

## 结构与保留范围

- 72 份测试/替身文件按 SDK、搜索、功能包、UI、集成、性能、交付和 support 重新归位；旧路径映射在 `tests/path-migration.json`。旧入口直接或 foreach 指定的 68 份测试全部仍在新清单，没有遗漏原加载基线、双语团本或默认启用参数。
- `tests/run.py` + `tests/suites.json` 成为唯一执行清单，原 PowerShell 入口委托它。测试独立进程、串行运行；支持分组/单例/list/JSON 报告，失败继续收集但最终非零，不自动重试。
- 交互、Logo 几何和 SDK 冒烟回归独立登记，不再被其他测试反复执行。共用的原生替身与数据装配进入 support，不提供预期结果或业务成功状态。模块选择直接指向实际五包路径，退役的 Shared/Core/Modules 路径立即拒绝。
- 删除 `profile_search_memory.lua`：它依赖已经撤销的 Host 全量目录所有权；保留会给出无效归因。索引观测保留于 benchmarks，显式选择执行。其余业务/性能断言与所有原阈值保留。

## 新增覆盖

- 入口 13 项反向测试：漏登记、重复 ID/命令、缺失/越界/错误分组路径、独立参数、嵌套执行、support 分类、错误/空选择、失败/超时/启动错误、失败继续与证据、局部报告标识、环境变量不能关闭 Python 断言。
- 直接公共通知回归：IsAddOnLoaded 的 loadedOrLoading 与 loaded 区别；自身/无关事件、取消、重复交付、回调内取消/新增、错误隔离、64 项容量和额度回收。ObservePalette 覆盖相同的快照/回收语义。
- 六个独立真实 TOC 组合：Host 单独，四个子包分别单独，全部反序加载；覆盖登录后恢复、角色显式关闭、重复通知保持实例、缺包不注册、不创建 Player 业务 DB、Host 不保存全量目录、不提前建 UI。
- 装配回归补充旧路径拒绝与失败前不加载；Lua/XML/Python 静态解析纳入完整入口，校验实际 Lua 和 luac 都为 5.1。

## 实际验证

环境：Windows / Python 3.12 / Lua 与 luac 5.1 / PowerShell 7。

最终夹具清理后的完整复核同样 90/90 通过：`analyze/test-reorganization/final-review.json` / `final-review.log`。原 PowerShell 包装的单例筛选/list 另行验证通过。

`python tests/run.py --include-benchmarks --report analyze/test-reorganization/final.json`：90/90 通过，其中 89 条硬门禁命令、1 条无预算索引观测命令。原始输出保留在同目录 `final.log`。SDK 交付 16 项、运行包交付 14 项、入口 13 项反向测试均通过。静态解析覆盖 189 Lua、1 XML、17 Python；生成数据/SDK/TOC/交付漂移与文档链接检查通过。

初轮曾发现两处旧团本选择路径，并发现导航测试继承了另一测试的 Registry 就绪状态；均改为显式正确装配。组合测试最初把 Player 的正常暴雪设置 ADDON_LOADED 监听误判为 Host 存档监听，核对生产职责后改为分别验证 Host 监听结束及所有框体无常驻 OnUpdate。没有修改运行时来迎合夹具。

交互测试初轮触及原严格 5 ms 峰值门禁；保留失败于 `full-first.json`，未放宽断言，最终完整运行通过。输出保留小数精度有限，打印 5.000 不代表阈值改成了 ≤5。

夹具清理后的一次专项复核出现 7 ms 峰值（`fixture-cleanup.json`）。随后用基线提交原始 tests 与当前 tests、同一份未修改的运行文件交替测量三组：基线峰值 4/4/9 ms，当前 5/4/4 ms，双方各有一次未通过严格门槛，分配和对象数不变。全部样本在 `paired-ui.json`；这证明旧测试也存在本机峰值波动，不证明统计等价或性能提升。执行器继续原样暴露失败，没有重试掩盖或提高预算。该不稳定性仍是后续真实计时调查项。

| 离线固定场景 | 最终观测 |
| --- | --- |
| 不含 LDT 的五包加载组合 | 99 文件，1472.8 KiB 保留、20 ms、2 Frame / 4 事件 |
| 完整五包加载 | 104 文件，1848.7 KiB 保留、26 ms、2 Frame / 4 事件 |
| 2026 条组合目录 | 5552.8 KiB；48 查询分配 2528.4 KiB，保留增长 0.4 KiB |
| 最近使用 100 次循环 | 分配 23894.1 KiB，未观察到保留增长，0 新 Frame；原峰值断言通过 |

综合内存原夹具先执行全部功能点击/视图测试，现在只执行同一份数据装配；目录规模、48 次查询、非空命中断言和预算不变，但去掉无关 UI 准备影响了测量范围。不能把读数变化作为运行时优化收益。所有性能规则仍以根 PERFORMANCE.md 为准，SDK 副本用 `tools/build_sdk.py --write` 同步。

## API 证据与交付边界

wowdoc source list / source check 后固定查询：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`12.1.0`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:322` 的 IsAddOnLoaded 声明在 333–334 行分别返回 `loadedOrLoading`、`loaded`，两者都是 bool。新通知用例按这两个独立返回值构造外部输入，不凭加载中推断 SV 已恢复。

运行文件差异为空，因此本轮不重复同步游戏目录，也不宣称客户端战斗、taint、原生动画、模型/纹理内存已验证。客户端待验事项见 `tests/LIFECYCLE_ACCEPTANCE.md`。历史验证记录保留当时路径与证据；新规范、SDK 接入说明和本轮验收地图已同步。
