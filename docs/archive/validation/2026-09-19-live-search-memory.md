# 2026-09-19 单包实机性能基线

Ticket：LYCHEE-20260919-182706-0006。sourceCommit：434976d258f86763560d48aacacb5d658d306a79。正式服 12.1.0.69875，zhCN，圣骑士。26 个词 × 3 轮，加首开共 81 场景，报告完整，已确认接收。当前未提交的提示修复未同步，不在本次测量内。

| 阶段 | Lychee MiB |
| --- | ---: |
| initial-natural | 27.389 |
| after-open-1 | 27.991 |
| open-1 | 39.796 |
| closed-natural-1 | 39.798 |
| closed-retained-1 | 16.521 |
| after-open-2 | 16.767 |
| open-2 | 36.631 |
| closed-natural-2 | 36.632 |
| closed-retained-2 | 16.519 |
| after-open-3 | 16.765 |
| open-3 | 36.624 |
| closed-natural-3 | 36.625 |
| closed-retained-3 | 16.531 |

75 个有结果场景首个可交互中位数 46 ms，最大 288 ms（火球）。全阶段 totalMs 包含探针稳定等待，不能当纯搜索 CPU。采样间隔 10ms，实测值受帧调度影响。

三轮诊断 GC 后为 16.521、16.519、16.531 MiB；未见明显逐轮增长，但不构成长期泄漏排除。自然搜索后约 36.6–39.8 MiB，需继续分析临时分配与常驻根。不得增加常驻强制 GC 将数字压低。

结束后 pending、queryTimer、refreshTimer、ownedTimer、homePrepare 均无残留，jobs=0，面板关闭。EllesmereUI 9.1.8、ExwindCore 6.0.0、ExwindTools 1.0、MDT 6.2.16 已加载。本表只列 Lychee 系列包归因，其他插件和引擎纹理不可视为已计入；旧子包均未加载。

原始证据：%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260919-182706-0006/report.json；内容 SHA-256：327fc374f62e3ee069e72bfde06ed54dff3f6a5d90b0ec4d32f2e468380174f0。完整载荷路径 LycheeDevDB.exports.records["LYCHEE-20260919-182706-0006"].payload.content，source kind automation_result。本地分析副本 analyze/feature-port/live-performance-content.json。
