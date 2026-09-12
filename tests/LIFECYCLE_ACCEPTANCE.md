# 角色存储与内存生命周期验收

2026-09-12。本轮保留 SDK 2/revision 6、UI Runtime 1，执行 [当前设计](../docs/architecture/2026-09-12-runtime-lifecycle.md)。1 MiB 不再是用户要求；旧 SDK 3/拆包/全量休眠候选不作为当前验收标准。性能硬规则只在 [PERFORMANCE.md](../PERFORMANCE.md) 维护。

## 统一入口

`powershell -NoProfile -File tests/check_contract.ps1`：测试失败、Lua 缺失、文件清单漂移必须非零退出；不能仅运行文档扫描宣布通过。

| 可执行检查 | 验收内容 |
| --- | --- |
| character_settings / character_pins / provider_expansion --defaults | SV root 恢复、两角色隔离、升级转移、默认全开与明确关闭、固定/排序/撤销、热读取分配 |
| provider_sdk_smoke / provider_ingestion / provider_record_ownership | 全部公开接收路径、secret/cycle/metatable、私有凭据、外部修改隔离、原子失败、过量池与回调重入 |
| achievements_provider | 默认启用、6002 条单份角色权威数据、温恢复不枚举、增量/关联成就、战斗队列、过期/损坏/分类变化、角色切换、SV roundtrip、旧当前角色缓存迁移 |
| interaction_smoke / ui_runtime / view_lifecycle / brand_geometry / presence_geometry | 关闭解绑、重开无新增 Frame、无旧动作身份、真实事件顺序、动画结构/几何、输入框和焦点不变 |
| performance_memory / performance_core / perf_core_provider | 固定目录保留、查询分配/增长、边界和增量更新成本；预算不能通过删数据或增加 GC 满足 |
| search_memory_regression / search_compile_equivalence / search_ranking_regression | 独立全扫描参照、结果顺序/文字/匹配证据、UTF-8、禁用恢复、个性化 |
| ellesmere_provider / ellesmere_equivalence / exwind_provider | 默认开启、缺上游、真实声明/选项恢复、取消/禁用无工作；不预建设置页 |
| client_toc_load / client_manifest | 真实 TOC 顺序、四产品/语言、必要能力不存在时安全退出、角色存储早期加载 |

## 游戏实测边界

旧完整报告 `LYCHEE-PERF-1789203670` 是同客户端现有业务基准。新诊断 0.3.0 从角色 SV 读取并释放私有成就缓存，保留第 3 轮缓存恢复对照；报告实际 sourceCommit/sourceDirty/sourceTreeHash，避免写死旧提交。诊断本身、全局 GC 与调度等待单列，不冒充产品开关耗时。

离线通过不等于以下场景已通过：更新后的角色切换、真实冷启动/默认全来源、完整页面池高水位、硬件 Alt+Space/Esc、战斗、动画视觉、正常游戏背景中的长期常驻。必须附新客户端报告，不能把旧报告自动当作新实现的结果。
