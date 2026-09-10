# 搜索引擎质量与生命周期优化

日期：2026-09-11。基线：`0d983f0`。范围：Host 匹配、排序、用户别名、选择记忆、查询收尾，以及成就匹配与文字高亮。保留 Provider API 2 / revision 6、既有倒排索引和增量更新，不新增持久索引、缓存、事件或计时驱动。

## 已复现并修复的问题

| 问题 | 修复后的行为 | 回归证据 |
| --- | --- | --- |
| `rl` 命中 `heirlooms`，各调用方规则不一致 | 1–2 个 ASCII 字母只匹配完整词或词首，禁用短词模糊绕过；评分、高亮和成就查询共用边界 | search_quality；旧实现失败于 `lexical case: rl / heirlooms` |
| 跨词命中统一得 0.82 分，说明与名称无法区分 | 每词取最强字段，最低分乘 0.9，再与完整短语比较 | search_quality 的名称／说明对照 |
| 第 21 个精确用户别名被前 20 个较弱匹配挤掉，失效引用占名额 | 先比较有界别名集合，再恢复有效结果 | search_ranking_regression |
| 目录增加后，上次选择在提升前已被截掉 | 静态结果截取前考虑有效偏好，合并后继续提升 | search_ranking_regression 的目录增长案例 |
| 空文本范围浏览先采样 200 条，遗漏排序应靠前的条目 | 比较全部合法范围候选，再保留前 20 条 | search_quality 的 600 条范围对照 |
| 同一别名静态得到 0.98，动态得到标题回退 0.75 | 动态适配器复用全部文本字段与非模糊评分 | search_ranking_regression 的静态／动态别名一致性 |
| 取消回调启动新查询后，被旧调用覆盖待执行状态 | 外部回调前失效旧 operation，返回后校验身份 | search_lifecycle_regression；旧调度实现失败于 newest input 断言 |
| 非法异步回复已结束任务，界面仍停在“搜索中” | 当前代次的完成、非法、异常、超时统一收尾并通知 | search_lifecycle_regression；旧 Runtime 失败于 waiting state 断言 |

静态与动态记录的去重优先级不变。动态 query 的合法业务候选若无字面命中，保留原回退；不以文字算法替代业务召回。前缀、精确快捷词、来源开关、范围及 locale/product 隔离继续由既有边界负责。

## 架构变化

匹配算法收敛到现有 Normalizer；StaticIndex 管候选与前 20 条，ProviderRuntime 负责校验、动态适配与查询任务，Personalization 提供偏好及有界别名恢复。没有新建一套搜索框架，也没有把 Provider 名称写入引擎分支。

QueryOrchestrator 的 operation 防止嵌套调用覆盖，SearchSession generation 继续表示会话有效性；ProviderRuntime epoch 继续隔离动态回复。不同身份有不同职责，不合并成含义不清的全局计数器。

## 自动验证

- `powershell -NoProfile -File tests/check_contract.ps1`：完整通过，包含 Lua/XML/TOC 静态检查、SDK/协议、语言、Provider、搜索、生命周期与性能门禁。
- 新增 `tests/search_quality.lua`：独立字面匹配预期、120 条记录全扫描对照、短词／多词／中英文数字、连续输入、启停、高亮、600 条范围浏览。
- 新增 `tests/search_ranking_regression.lua`：超过 20 条的别名排序、失效引用、选择记忆、过滤和动态字段一致性。
- 新增 `tests/search_lifecycle_regression.lua`：真实 Host 入口下的 Query/Schedule/Cancel 重入、同步／异步终态、非法回复、多来源、超时和隐藏。
- 更新 `tests/search_memory_regression.lua` 的旧短词与固定多词分数预期；未放宽性能阈值。
- 独立子 Agent 复审通过，未发现阻塞问题；复跑上述三套新测试及搜索内存回归。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：`checkedLua=71`，`valid=true`，无诊断。
- `git diff --check` 通过。

原始本机日志在忽略目录 `.codex/`：`search-engine-final.txt`、`search-engine-comparison.txt`、`search-quality-before.txt`、`search-engine-validate.json`。可复现测试及本记录进入 Git，临时日志不进入游戏目录。

## 性能对照

相同 2,689 条数据，旧版与新版交替运行三轮 `tests/performance_memory.lua --check`。旧版从当前基线归档提取，测试驱动相同。所有轮次通过既有门禁。

| 指标 | 旧版 | 新版 |
| --- | ---: | ---: |
| 目录与索引合计 KiB | 7,263.0 | 7,267.6 |
| 48 次查询累计分配 KiB | 1,814.1 | 1,823.8 |
| 查询后保留增长 KiB | 0.1 | 0.1 |
| 三轮平均查询耗时范围 ms | 0.333–0.375 | 0.375–0.417 |

这次是质量与稳定性优化，不声称更快或更省内存。合计内存增加约 4.6 KiB；48 次查询多分配约 9.7 KiB，没有观察到保留内存持续增长。计时是离线小样本，不代表游戏帧时间。

完整门禁中的 Provider 扩展压力场景：100 次查询累计分配 3,961.7 KiB，低于 4,096 KiB 原阈值；保留增长 -0.1 KiB。开发中曾因动态适配和短词判定的临时对象超过阈值，改成字节扫描和普通字符串快速路径后通过，没有提高阈值。

## WoW 来源证据

已先执行 wowdoc source list / source check，再查询精确符号。本轮未新增 Blizzard API。

| sourceId | product | requestedRef | resolvedCommit | path | line | excerpt |
| --- | --- | --- | --- | --- | --- | --- |
| wow-ui-source | retail | latest | 8ea15b61e45c0ed4eba01439c90757f86eb78d34 | Interface/AddOns/Blizzard_AccountSaveUI/Blizzard_AccountSaveUI.lua | 175 | `if string.find(point, "TOP") then` |

此证据只说明版本化 UI 源码的字面查找用法；搜索词界、Lua 算法及重入正确性以独立回归测试验证，不把 UI 调用样例当作算法定义。

## 仍然存在的限制与实机验收

模糊候选继续限制为最多 48 个，并受 1.5 ms 原有预算约束，不保证穷尽所有近似拼写。空范围浏览的候选键数组随目录大小增长；只对最终结果对象维持前 20 条，不能宣称整个查询为固定内存。别名最多 128 个；大量失效引用时可能需要逐个恢复检查。

没有改变显式空文本 `SearchSession:Filter` 的既有静态浏览契约，也未重写独立旧 CommandCatalog。快捷词转为范围查询的既有动态业务路径继续保留。

本机无法操作游戏完成实测。提交后按仓库流程同步正式服；本次未改 TOC 或新增运行时模块，使用 `/reload` 即可加载。待游戏内验证：`rl`、中文副本名、三字母英文片段、用户别名、同词上次选择，以及快速输入／退格清空／关闭重开。离线通过不等于承诺所有游戏环境下无问题。
