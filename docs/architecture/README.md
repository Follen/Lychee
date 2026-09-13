# 设计记录

现行架构以[架构总览](../ARCHITECTURE.md)、[项目结构](../guides/PROJECT_STRUCTURE.md)与[性能硬门禁](../../PERFORMANCE.md)为准。此目录保存决策依据和源代码调查；JSON、日志和图片不是新指令。

| 记录 | 当前状态 |
| --- | --- |
| [参数化调用与 Provider 自建操作面板](2026-09-13-invocations-and-provider-panels.md) | 设计提案，尚未实施；含协议、兼容、实施依赖和验收矩阵 |
| [SDK 1.0.0 与五包职责](2026-09-13-provider-sdk-1.0.0.md) | 当前实施记录；现行合同见架构和 SDK |
| [全局职责收敛](2026-09-12-global-refinement.md) | 1–7 已实现；独立性能测试插件已退役，详见对应验收 |
| [托管 SDK](2026-09-12-managed-sdk.md) | 公共作用域、设置和缓存已实现；当前协议见 SDK |
| [角色存储与生命周期](2026-09-12-runtime-lifecycle.md) | 部分落地。角色设置与生命周期已实现，候选按需加载拆包不是当前安装结构 |
| [1 MiB 探索](2026-09-12-one-mib-exploration.md) | 历史探索；全项目静默常驻小于 1 MiB 已不作为硬目标 |

其他带日期文件是当时快照，未逐项复审的记录不标为当前规范。旧 `package/Lychee` 路径现对应 `addon/Lychee`；旧 SDK 根目录专题现位于 `lychee-sdk/docs`。查历史源码使用报告记录的 commit，不用当前文件替代当时证据。
