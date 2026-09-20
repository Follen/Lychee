# Search 全覆盖审查

基线 `4e12531`；5 个 Search 模块全部审查，修改 Normalizer、StaticIndex 和 QueryOrchestrator。未改查询排序、模糊预算、候选召回规则、API/保存数据协议或引入运行时 timer/GC。

## 预算、复现与修复

`lua tests/performance_search.lua` 在修改前打印：2,048 次不同短文本规范化累计分配 2,839.7 KiB，128 条长文本缓存保留 2,421.2 KiB，5,000 次失效留 5,000 keys，关闭后保留 1,000 candidates；随后在长缓存预算处失败。

- Normalizer 用明确的 ASCII 字节范围模式替代逐字节表构造，仍保留 UTF-8 字节、大小写和空白语义。独立旧算法参照覆盖全部 256 字节和 1,000 个混合输入；既有 8,836 编辑距离参照和全扫描排序测试也保留。
- FIFO 仍最多 1,024 条，超过 256 字节的文本正常规范化但不进入缓存。键和值最多各 256 字节，文本 payload 上界 512 KiB，另有有限表/字符串头开销；没有裁剪搜索内容。
- 失效本来就提升整源 generation，没有消费者读取逐键历史，因此只保留一个 `*` 标记。未把全源刷新伪装成按键增量更新。
- Query Cancel 清理 StaticIndex 前缀候选缓存；关闭后不再保留上一查询的候选数组。正常连续输入仍由既有 Schedule 管理，不改变模糊召回和结果归属。

新增门槛：固定 2,048 次规范化分配小于 1 MiB、长文本后保留增量小于 512 KiB、失效键不超过 1、关闭后候选数为 0。没有使用粗粒度 Lua 时钟设不稳定的耗时断言。

## 五轮交替数据

同一脚本读取归档旧源码和新源码，独立进程、相同输入、五轮交替。[原始输出](../design/2026-09-10-project-perf-search-results.json)

| 指标 | 旧 | 新 |
| --- | ---: | ---: |
| 2,048 次累计分配 | 2,839.7 KiB | 626.1 KiB |
| 总耗时中位数 / 最大 | 44 / 49 ms | 36 / 38 ms |
| 128 条长文本保留增量 | 2,421.2 KiB | 无正增长 |
| 失效键数 | 5,000 | 1 |
| Cancel 后候选数 | 1,000 | 0 |

新长文本原始增量为 -21.5 KiB，包含前序短期对象/堆整理回收，不表示负内存占用，也不把它报告成额外 21.5 KiB 收益。规范化不保留大输入来自缓存插入条件和回收测试的共同证据。

## 逐文件覆盖

- Normalizer：本轮优化；编辑距离仍采用现有两行有界缓冲，在纯同步无外部回调评分内使用，不扩大共享 scratch 范围。
- StaticIndex：本轮收紧失效历史和查询缓存释放；原有字符倒排、top-K、增量差异更新、禁用移除字段/索引、Persist 不写运行时副本均保留。全量 snapshot/rebuild 是低频全目录工作，未隐藏其成本。
- QueryOrchestrator：本轮 Cancel 释放候选；最终结果有 20 项上限，融合结果需要独立所有权，未为了省表覆盖调用方持有的旧返回值。取消 token 与 session 检查保留。
- SearchSession：同帧 source refresh 合并为一次 timer；输入立即使旧结果失效，晚到 timer/回调校验 session/generation；关闭取消任务。当前宿主只有固定索引监听者，没有每次开关新增监听。
- RuntimeIdentity：初始化读取版本/语言，签名变化重建索引；查询使用已有身份，不逐帧读取游戏 API。没有新增长期查询缓存。

wowdoc 先检查 retail 源版本；搜索任务关联的 C_Timer.NewTimer 定义位于 `Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:39`，版本 `8ea15b61e45c0ed4eba01439c90757f86eb78d34`，原始证据包含 sourceId/product/requestedRef/commit/path/line/excerpt。[证据](../design/2026-09-10-project-perf-search-wowdoc.json) 本次三处实现变化均为 Lua 数据处理/引用管理，没有新增或变更 Blizzard API 调用；正常生命周期仍需最终完整 wowdoc 验证和游戏场景验证。
