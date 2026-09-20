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

实机性能与独立功能覆盖探针已完成，见下方最终验收；功能探针有三项覆盖缺口。上一轮 14.032 MiB 的 Ticket 对应旧提交和不同职业，不能作为本轮收益证据。真实动作点击、战斗及英文客户端不因离线测试通过而自动视为通过。


## 团本扫描的第二处大分配

继续审查全量来源后，发现每次技能扫描按 490 个首领分别创建 flush 闭包及其八个捕获状态。改为每次扫描一个闭包，每进入下个首领清空技能/难度累计状态；各查询仍有独立协程和变量，不共享跨查询 scratch，不改变让出点、名称加载、等待或候选排序。

相同完整目录 20 查询：累计分配 6459.9 → 2939.6 KiB（约 -54.5%），中文 CPU 1295 → 1298ms、最大批次 2ms、回收后增长 0.7 KiB。英文分配 2943.5 KiB；两个语言的难度、同技能去重、查询取消、异步/同步/失败加载及动作跳转断言均通过。固定场景的防回归分配检查由 8192 收紧到 4096 KiB，不放宽 CPU 或容量。此项不增加常驻大表。

WoW 名称读取契约核对：同一 wow-ui-source / retail / 12.1.0 固定 commit，查询 C_Spell.GetSpellName，证据路径 `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:477`；本轮只是移动闭包作用域，没有改 API 调用语义。

## 039eaec 实机中间验收

该提交仅含 SDK/标识优化，尚不包含后续团本闭包修改。性能 Ticket `LYCHEE-20260919-233208-0010`，request `req-single-port-039eaec-perf-01` / revision `039eaec-perf-1`；完整报告 219981 字节，SHA-256 `a2c466aa2d7542a0a90e42c2d6bb58d63f043807acb85a95638b242aef07c83f`。Retail 12.1.0.69875、zhCN、MAGE；角色与上轮 PALADIN 不同，禁止直接归因整体差额。81 行全部 complete，无 incomplete / unavailable；结束 jobs=0、pending=false、窗口关闭、计时器归零。三轮关闭回收后 14.166 / 14.107 / 14.126 MiB，自然关闭 36.619 / 32.751 / 32.690 MiB。

功能 Ticket `LYCHEE-20260919-233402-0011`，request `req-single-port-039eaec-func-01` / revision `039eaec-func-1`；报告 32469 字节，SHA-256 `9cb40d83d8a805e360573751e4b249b1ce70115861bc7b2a8558d36dacc9ea7a`。52 项 pass、0 fail、3 skip；跳过项为无历史存档的两次恢复检查，以及样本未出现 4/5 条结果的回缩检查。状态 complete_with_gaps，正常与无参数/超范围自然语言、SDK 声明及清理路径通过；无最近使用存档的恢复项跳过，真实业务写入/安全点击、战斗及英文客户端不在该只读探针覆盖内。确认命令被自动输入误发到说频道，已停止后续自动输入；报告在此之前由自动重载完整保存，误发不构成客户端功能通过证据。


## 1a541e0 实机性能验收

Ticket `LYCHEE-20260919-234343-0012`，source.kind 为 `automation_result`，request `req-single-port-1a541e0-perf-01` / revision `1a541e0-perf-1`。payload 路径为 `LycheeDevDB.exports.records["LYCHEE-20260919-234343-0012"].payload.content`；220464 字节，SHA-256 `a2cc931deca97e52e58998b8fe10ebc65a239c98f3cf36912d9194e04f2d4dc8`。报告完整，status=succeeded，内部 status=complete，未截断。

与 039eaec 对照的角色 GUID、MAGE 职业、Retail 12.1.0.69875、zhCN、查询词、依赖版本和来源配置完全一致。81 行的查询、轮次、状态、数量、结果 ID/Provider/标题及顺序逐项一致；无 incomplete / unavailable。清理后 jobs=0、pending=false，窗口关闭，查询/刷新/自有计时器和 homePrepare 均清空。

| MiB | 039eaec | 1a541e0 |
| --- | ---: | ---: |
| 第一轮结束、关闭后自然读数 | 36.619 | 31.002 |
| 第二轮结束、关闭后自然读数 | 32.751 | 27.129 |
| 第三轮结束、关闭后自然读数 | 32.690 | 27.058 |
| 第一轮关闭后回收测量 | 14.166 | 14.169 |
| 第二轮关闭后回收测量 | 14.107 | 14.102 |
| 第三轮关闭后回收测量 | 14.126 | 14.105 |

每轮结束自然读数减少约 5.6 MiB，常驻基本不变。这些是指定采样点的读数，不是连续测量的峰值，也不是累计分配；回收只由诊断探针在测量点执行，产品运行逻辑没有强制 GC。总时长 29.297 秒，相比上一轮 120.708 秒受前后台/调度条件影响，不能宣称四倍提速。团本扫描减少约 54.5% 累计分配来自前述离线固定场景，不能当作游戏总内存下降比例。

本次输入与重载由用户手工完成；结果已读出，客户端 received 确认待手工执行。最终提交的独立功能覆盖结果见下节；搜索结果等价不代表真实动作点击、战斗或英文客户端全部通过。


## 1a541e0 实机功能验收

Ticket `LYCHEE-20260919-234746-0013`，source.kind 为 `automation_result`，request `req-single-port-1a541e0-func-01` / revision `1a541e0-func-1`；sourceCommit `1a541e0b06536f2f4f55a419d97c60d0f36aec3c`。Retail 12.1.0.69875 / zhCN，SDK / Provider API 仍为 1.0.0。完整 payload 路径 `LycheeDevDB.exports.records["LYCHEE-20260919-234746-0013"].payload.content`，32401 字节，SHA-256 `32cc4ab391caea76d38ea21a497a5c9f67434815a746439197414dc6c3f399d4`；报告读取校验通过。

内部状态 `complete_with_gaps`：52 pass、0 fail、3 skip。通过项包括 SDK 服务及来源声明/注册、中英文自然语言正常值与超范围输入的只读动作声明、LDT 模型/技能结构、卸载、会话与输入保留、关闭清理以及重开后的过期回调拦截。结束 jobs=0、pending=false、窗口隐藏、查询和刷新计时器均停止，inputRestored=true。

三项 skip 与中间版本一致：无已有存档引用，跳过首页初次与重开恢复；真实搜索观察到 6/3/2/1 条，缺少 5/4 条样本，因此不称完整 6→1 回缩实测通过。没有执行设置写入或安全动作，没有点击原生菜单，也未认证像素渲染；中文客户端中的英文查询不等同于英文客户端验证。用户手工执行与重载，客户端 received 确认待手工执行。
