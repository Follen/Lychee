# 搜索候选临时分配优化

基线 `6fecb26`（运行代码为 `623987c`），SDK / Provider API 1.0.0，单 Lychee 包。目标是减少查询候选的重复中间对象，不增加跨查询缓存，不改变目录规模、匹配、排序、动作、错误处理或外部输入隔离。

## 定位与修改

500 个设置的目录上，固定搜索 `test toggle` 10 次，每次物化 20 条最终候选。临时分阶段计量确认：旧接收阶段约 2553 KiB，其中包含引用/参数的重复复制；原始动作生成约 807 KiB。各阶段计数是包含子调用的读数，不能相加为总量。

外部记录进入 Host 时仍通过 Boundary.Copy 隔离。RecordCodec 对已经拥有的引用改用私有只读校验，完整执行可访问性、纯数据、循环、深度、节点、字节和语义限制。公开 NormalizeStoredRef 仍返回独立副本。NormalizeArgs 只读检查当前 schema、复制输入参数、生成独立规范化结果，并在输出上检查默认值展开预算，不再复制只读 schema 和最终结果。没有可变 schema 缓存。

Boundary.Validate 和 Copy 共用有界遍历；只读校验也累计节点与逻辑字节。ReferenceKey 直接读取并跳过根级展示字段，编码保持原样，嵌套同名字段保留。固定词表与空 scope 复用，不保留查询文本或结果。

生命周期成本限于当前同步调用：reader 最大 20 个最终候选、每条最多 16 动作；不 yield、不调用业务、不新增 timer/事件/UI。新增少量函数和只读常量，组合离线静态保留增加约 2 KiB；未引入新的数据规模相关常驻根。

## 离线结果

同机 Lua 5.1、相同 fixture。SDK 分阶段探针仅在 analyze 中，不进入运行包。

| 场景 | 旧版 | 本轮 |
| --- | ---: | ---: |
| 设置 10 查询 × 20 候选累计分配 | 4402.1 KiB | 3680.7 KiB |
| 接收阶段（包含子调用） | 2552.6 KiB | 1851.9 KiB |
| Boundary.Copy 调用次数 | 4220 | 1220 |
| 综合来源 100 查询分配 | 7169.5 KiB | 6729.9 KiB |
| 综合来源新增目录保留 | 2127.9 KiB | 2127.9 KiB |
| 2025 记录组合、48 查询分配 | 1900.8 KiB | 1887.3 KiB |

设置专项减少约 16%，综合 100 查询约 6%；不是整个游戏内存下降比例。组合来源回收后增长约 0.1 KiB；设置专项最后一屏仍持有约 130 KiB 的活动候选，不能当成泄漏。SDK 仍需要最终结果和外部隔离副本，临时分配没有归零。未用强制 GC、减少结果或放宽校验换取收益。

## 验证

- 新 `tests/sdk/invocation_allocation.lua` 在旧实现上失败于已拥有引用重复复制，修复后通过。覆盖 400 组旧编码 oracle、根级忽略和嵌套字段保留、输入/默认列表隔离、可变 schema、不暴露私有入口、超限、不可访问、循环及 metatable。
- 基线源码与当前代码运行相同 29 组查询，完整结果记录、动作和匹配证据逐字一致。
- 完整 `tests/check_contract.ps1` 通过，包含双语言设置、音量刷新、Invocation 生命周期、第三方 documents 和取消/注销回归。Lua 语法、Bindings XML、TOC 加载检查、SDK 生成、文档链接与 diff 检查通过。
- wowdoc 查询 `canaccessvalue`：sourceId `wow-ui-source`、product `retail`、requestedRef / matchedTag `12.1.0`、resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`；`Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:65`，函数说明为调用方访问权限检查，`SecureHooksAllowed=false`。保留原访问检查，不新增游戏 API。
- 同一已记录诊断构建的 wowdoc validate 检查 111 Lua / 0 XML，仍为 28 条既有 `event_not_found`，与上一轮诊断逐项一致；不称 valid=true。

## 实机状态

本轮实机性能和功能覆盖待运行。上一轮 14.032 MiB 的 Ticket 对应旧提交，不能作为本轮收益证据；待用相同全量查询序列复测。真实动作点击、战斗及英文客户端不因离线测试通过而自动视为通过。
