# 玩具内存与 Palette 解耦（0.2.9）

基线提交 `92c3acc4cb39664d4c0953f5a4cc06f5c12505e3`。运行变更：玩具目录使用现有 documents/readEntry 契约；Palette Hide 接收通用 immediate 参数，安全动作层决定玩具点击即时关闭。通用 UI 不再识别 toy-click，已有退出清理、战斗保护及按钮身份检查保留。

## 成本与生命周期

不改变 1163 个静态 ID、最多 4096 条容量、收藏枚举与事件频率。Host 仅常驻搜索文档；结果和历史恢复生成单条 Entry，没有全量 Entry 镜像或新缓存。reader 查询单个物品的名称、图标与收藏，不请求数据、不扫描目录。构建仍由 CatalogProvider 按 32 项/1ms 检查点与 16 条提交批次调度。关闭取消搜索；所有者停用取消目录工作、清 pending，原有有界目录与 ID 保留语义不变。无新事件、Frame、timer、SV 或强制 GC。

同数据与既有 CPU/生命周期门禁对照；内存按 PERFORMANCE.md 审查，不以减少覆盖或放宽预算换取通过。

## 离线验证

Lua 5.1，1163 ID、581 件初始收藏，相同 fixture、zhCN/enUS/zhTW/enGB。

| 固定测量 | 0.2.8 | 0.2.9 |
| --- | ---: | ---: |
| zhCN 基础序列保留 KiB | 1422.0 | 1157.7 |
| enUS 基础序列保留 KiB | 1601.8 | 1305.4 |
| 20 次精确查询分配 KiB | 214.3 | 267.7 |
| 20 次精确查询保留增长 KiB | 2.1 | 2.2 |
| zhCN 混合24查询分配 KiB | 1113.3 | 1725.7 |
| enUS 混合24查询分配 KiB | 1104.3 | 1716.8 |
| zhCN 混合24查询 CPU ms（单轮观测） | 16 | 23 |
| enUS 混合24查询 CPU ms（单轮观测） | 18 | 25 |

这是 Provider/索引 fixture 的堆差，不是整个插件或游戏引擎内存。混合序列预热8词，重复3遍；中文增长 -1.9→6.3 KiB、英文 -1.8→6.4 KiB；负数表示旧垃圾回收，不是负内存。三轮交替运行基础序列，中文均1422.0→1157.7 KiB、英文均1601.8→1305.4 KiB；常驻节省约264–296 KiB，代价为24次混合查询额外约612 KiB临时分配及约7ms总CPU；无查询期目录枚举、无新框体、结束无timer，接受此有限代价。最大构建回调观测2ms，原8ms门禁不变。不声称尾延迟或帧率改善。

tests/providers/toys.lua 接受第二参数旧 Provider 文件、第三参数结果快照路径（新版用 `-`）。旧文件由上述基线 git show 导出。中英文各8词，比较完整顺序、ID、文字、图标、payload、confidence、evidence、interaction与ref，前后字节一致。覆盖缺名请求、失败/同步/成功加载、移除收藏、热修新增、战斗dirty、停用/恢复、注销和外部动作修改隔离。

bag_actions 覆盖安全按钮复用、失效身份/收藏、背包/技能回归、原生目标光圈保留替身；navigation_binding 覆盖通用即时关闭和关闭动画中再次即时关闭。不能把目标光圈替身视为真实受保护点击通过。

完整契约、Lua解析、Bindings XML、生成TOC/SDK、仓库文档、190文件发布清单、四客户端wowdoc validate及diff检查通过。原始日志位于本地 analyze/toys/memory-contracts.log，前后快照 before/after-zh/en.txt；不打包进游戏。

## WoW 来源

sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`；source list/check已核对。

- Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua:404：`SECURE_ACTIONS.toy`，406读取toy属性，409调用UseToy；使用路径不变。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:824：GetItemNameByID，830 itemInfo参数，835可空string结果；589 GetItemIconByID。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua:94：UpdateAddOnMemoryUsage；25 GetAddOnMemoryUsage，36 number结果。探针刷新计数，不将全局刷新耗时归因给Lychee。

## 实机范围与基线

Retail 12.1.0.69875 / Interface120100 / zhCN，晴昼秋岚—白银之手，当前145件收藏。使用lychee-dev后台任务toy-memory，4词×3轮，读取动作而不执行业务；自然内存与诊断GC分别列账。只有Lychee一个适用业务包，Lychee Dev单列诊断成本。原生纹理/Frame引擎字节未测。

基线 Ticket `LYCHEE-20260920-140542-0042` 成功并ACK：145条均含actions，12次结果/动作有效，关闭后visible/pending/timer/job均false。Lychee刷新计数：创建面板后17568.37 KiB、首开17623.24 KiB、关闭18720.12 KiB、诊断GC后14097.41 KiB。诊断插件GC后4225.45 KiB；全客户端堆339843.48 KiB。关闭计数不代表峰值，GC不代表生产优化，50ms探针轮询/后台帧率使完成时间约66ms，不当作搜索CPU。

失败探针也保留：0040在尚未创建Palette时访问nil；0041错误假定实机查询同步完成。两次均读取完整失败报告并ACK，修正探针后0042成功，不隐去失败。

新版已同步190文件并逐文件SHA-256核对，运行提交 `ea2663e8da01ebb3de0f39582eab963e84bb5fd0`。新版 Ticket `LYCHEE-20260920-140933-0043` 成功、ACK完成并清理自建任务区块。相同145件收藏，常驻actions条数145→0；12次查询每条ID/文字/图标/动作物品ID及顺序完全一致；generic immediate关闭从旧版frame仍显示变为新版立即隐藏，关闭/重开后无visible/pending/timer/job残留。完整原始返回见[实机证据](2026-09-20-toys-memory-evidence.json)。

新版Lychee计数：创建面板后17277.29 KiB、首开17341.28 KiB、关闭19174.92 KiB、诊断GC后14169.68 KiB；诊断工具GC后4240.46 KiB，全客户端堆339726.62 KiB。整个Lychee的GC后计数相较基线增加72.26 KiB，不能据此宣称整插件内存减少；本轮只能确认目录去除了全量动作结构及离线固定样本的节省。自然关闭读数增加454.80 KiB，也与结果物化临时分配增加的方向一致，但自然GC与其他来源状态使其不是分配精确归因。探针未固定所有其他来源目录、引擎缓存或profiling开关，因此总体计数差额保持未归因。

12次查询初始同步调用CPU中位数0.944→1.669ms、最大1.690→3.721ms；异步完成墙钟包含50ms轮询和后台帧率，不能作为纯搜索CPU或首个可交互结果延迟。接受目录结构优化与UI解耦，整体内存改善未获证实，后续不以此结果宣称全局达标。

真实鼠标使用、地面选点/取消、冷却失败、真实战斗/taint、团本/姓名板峰值、其他客户端与语言实机验收仍待完成；不以离线通过替代。
