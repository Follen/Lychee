# Provider 统一运行时与 SDK revision 7 验证

基线：746c3c43d9adc5d77d141ee243456015552fdc49。当前改动清理旧私有 Command/Capability/Intent 通路，新增托管资源和数据边界，EUI/EX 使用公开任务能力；普通具名记录、匹配、动作和角色默认配置保持。

## 完成范围

- 删除三个旧运行时模块、TOC 和 Registry/Query/Executor 的旧分支。只保留 Provider 结果接入、来源/视图事务发布、统一动作安全校验。
- SDK API 2/revision 7：Provider、query、view 三种作用域；Own/After/Run/OnEvent/Cache、Settings 和按需 Diagnostics。配额与输入隔离在 Host 执行，失败有明确错误，结束先摘除状态再回调。
- EUI/EX 删除重复协程续跑/计时/取消状态，保留业务枚举、分批预算、战斗状态、结果及点击逻辑。版本 1–6 的外部 Provider 仍支持。
- 公共测试装配依据真实 TOC 排序；不统一游戏替身和独立业务参照。删除的两个测试只验证已退役协议，真实动作/视图/禁用/失效交互改用 Provider 测试。
- SDK 类型、可执行示例、协议、架构、开发文档、PERFORMANCE 及性能诊断副本同步。

## 边界回归

sdk_resources 覆盖同 key 替换、迟到 timer、事件注销/返回失败、协程战斗中断、任务创建/续跑失败释放额度、非表选项、查询完成和取消、页面构造失败、重复卸载、跨角色设置、副本隔离、损坏设置容器、FIFO 淘汰、小容量删除、共享图复制预算、64 资源配额、旧实例注销和 SDK 示例。

独立审查先复现再修复了六项缺口：旧 stop 误清理重启实例；旧查询异常清除新结果；timer 失败占位；共享图先复制后计量；非法 options 抛错；小容量 cache 无法删除。复核确认六项均修复。新增 1000 次创建/取消/关闭检查暴露登记簿扩容；关闭现在移除登记，避免仅依赖弱键回收。测试要求回收后增长 <64 KiB、0 新 Frame、禁用后资源为 0，实际约 6 KiB（各轮 GC 表容量有小幅变化）。

## 同输入前后对照

Windows Lua 5.1，同一机器，归档基线源码/测试与当前源码分别运行；3 轮前后交替，无运行中游戏采样。目录 2689 条；增量场景 500 条目录、每组 100 次单条更新；EUI/EX 各用既有固定夹具。未修改原有预算。

| 指标 | 修改前 | 修改后 |
|---|---:|---:|
| 2689 条目录保留 KiB | 6215.42 | 6215.42 |
| 目录初始化分配 KiB | 10315.19 | 10313.32 |
| 目录初始化 ms，中位/最大 | 130 / 132 | 131 / 140 |
| 100 次单条更新首组分配 KiB | 255.178 | 255.178 |
| 同更新 ms，中位/最大 | 2 / 3 | 2 / 3 |
| EUI 20 次查询分配 KiB，中位 | 417.7 | 462.7 |
| EUI 1000 页热查询 ms，中位/最大 | 8 / 9 | 7 / 7 |
| EX 20 次查询分配 KiB，中位 | 1553.3 | 1599.1 |
| EX 20 次热查询 ms，中位/最大 | 402 / 407 | 402 / 424 |

托管作用域和身份保护使 EUI/EX 每次查询约多分配 2.3 KiB，查询结束后未观察到保留增长。EUI 的 -0.1 KiB GC 差值仅表示本轮未观察到增长，不代表负内存。初始化和 EX 最大耗时略高，不能据此声称帧率提高或尾延迟改善。此改动主要收敛架构和生命周期，不显著降低业务目录常驻内存。

EUI 全文等价转录仍为 `827088762:192411782`：44 个查询，核对全记录、稳定恢复及动作参数。搜索独立参考、排序、角色默认开关、成就增量、UI/安全/复用、EUI/EX 原有性能门禁均通过。

## 验证命令与结果

- `pwsh -NoProfile -File tests/check_contract.ps1`：PASS；包含新增资源/装配测试及全部现有契约、交互和性能门禁。
- 全部产品/SDK Lua 的 `luac -p`：85 文件 PASS；XML 解析 1 文件 PASS。
- `python tools/build_client_tocs.py --check`：四客户端及 retail fallback PASS。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：79 Lua，valid=true，无诊断。
- `python tools/performance-test/verify.py`：PASS。56 个私有产品模块，59 Lua / 60 交付文件；禁止加载期自动基准测试，仍记录真实提交和源码哈希。
- `git diff --check`：PASS。

本机原始输出：analyze/sdk-managed-runtime/contract-final.txt、paired-benchmarks.json、diagnostic-verify.txt、wowdoc-validate.json。验证摘要并入版本库；这些临时原始资料不进入正式服。

## 版本化证据与实机范围

查询 sourceId=wow-ui-source、product=retail、requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34（12.1.0）。[精确路径、行号与摘录](2026-09-12-managed-sdk-evidence.json) 包含 C_Timer.NewTimer、RegisterEvent、UnregisterEvent、debugprofilestop；未命中 Frame.RegisterEvent 等别名的查询不算证据。

未执行游戏内冷/热打开、查询中关闭、EUI/EX 搜索、角色切换、禁用恢复和战斗/taint 实测。TOC 和模块变化后须完全重启客户端再验收。离线结果、提交和复制不能代替这些场景。同步仅覆盖运行必需资源，不删除未加载旧文件；提交哈希和复制校验在交付消息记录。回滚使用新 git revert 并按同样流程验证/同步。
