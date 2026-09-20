# Host、SDK 与现行文档收尾审计

基线 `54b3da8`，单插件工作树 `codex/single-addon-feature-port`。SDK / Provider API 保持 1.0.0。本轮是代码阅读、交付工具加固与文档修订，不重写运行时。

## 范围与发现

核对 Host 的 Provider 注册/更新/查询/取消与输入隔离、公开 SDK 门面、Invocation 准备/执行、Catalog、资源及设置接口，结合现有完整契约回归检查。检查所有运行 Lua 文件的客户端 TOC 可达性，以及 Core/Search/PublicAPI 局部函数的词法引用候选；未发现可直接删除的孤儿 Lua 文件或仅有定义的局部函数。公开可选 API 不能因仓库内调用少而删除；词法检查不证明没有所有形式的死代码。

| 问题 | 修订 |
| --- | --- |
| SDK helper 与清单一致，但两者共同遗漏新增错误码 | 补齐七个公开实现模块中 42 个字面错误声明；构建检查实现与清单的差集，缺源码也拒绝。Provider 业务码、原生加载原因仍是开放集合，不承诺穷举。 |
| ApiStubs 的 SDK.VERSION 不在生成核对范围 | 纳入同一版本源，补漂移拒绝与修复回归；仍为 1.0.0。 |
| Invocation 示例把旧内置 ID 与教学动作混在一起 | 明确真实来源为 builtin.blizzard-settings，教学引用使用 example.volume，不让第三方依赖内置业务动作结构。 |
| scope 文档误写必须 products | 对齐单数 product 与数组 products 的互斥合同及默认 retail。 |
| reply evidence 的说明超出实现 | 明确 Host 重算匹配证据，外部 confidence 仅影响分值，不授予执行或范围权限。 |
| 当前开发文档混入迁移进行时 | SDK README、架构、目录说明改为现行职责；历史方案保留原文，不伪造历史验收。 |
| 内存审查与历史 assert 比较线容易混淆 | 区分协议容量、CPU/生命周期硬限制和堆内存审查；保留原测量与回归，不抬高阈值。纠正组合目录数量与 documents 成本表述。 |

本地 AGENTS.md 的“迁入中”、旧十包安装和“Host 不保存公开目录”表述同步修正；该文件按仓库政策留在本地，不强行纳入 Git。

## 验证与边界

- 完整 `tests/check_contract.ps1` 通过：包括 Host 生命周期、第三方隔离、Invocation、存储、冷加载、目录及 Provider/UI 回归；原始日志 `analyze/feature-port/host-sdk-audit-contract.txt`。
- SDK 交付反例测试覆盖实现错误遗漏、缺源码、生成 helper 不能掩盖清单遗漏，以及 SDK 类型版本单边漂移。此扫描只检查指定模块中的字面 code/fail/failure，不是 Lua 语义解析器或所有动态错误的穷举证明。
- 文档链接、SDK 独立交付闭包、版本/生成副本、发布清单和差异检查按本轮输出验证。
- `addon/Lychee` 运行文件与本轮基线及当前游戏安装逐字核对；本轮不重新复制游戏目录，也不要求重载。SDK helper 只增加常量声明，不进入 Host TOC。
- 未将旧 wowdoc 的 28 条事件诊断称为消失或 valid=true；本轮没有修改游戏 API 或运行 Lua。前轮功能 52 pass / 0 fail / 3 skip、81 次搜索结果一致只作为同运行代码的既有证据。首页历史恢复、完整 6→1 样本、真实动作点击、战斗和英文客户端的未覆盖项仍保留。

结论：本轮修复了明确的契约、示例和交付检查缺口。没有证据要求重写 Host，也没有因“清理”删除公开接口；不宣称整个仓库已经无缺陷或所有客户端均通过。
