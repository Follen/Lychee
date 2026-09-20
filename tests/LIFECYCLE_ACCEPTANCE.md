# 角色存储与生命周期验收入口

当前 SDK / Provider API 为 1.0.0，UI Runtime 为 1；插件版本独立维护。现行行为见 [架构](../docs/ARCHITECTURE.md)，性能与内存审查见 [PERFORMANCE.md](../PERFORMANCE.md)。

从仓库根目录执行 `powershell -NoProfile -File tests/check_contract.ps1`。分组与公共装配见 [测试说明](README.md)。失败、Lua 缺失和清单漂移必须非零退出；文档检查不能代替功能测试。

| 测试组 | 验收内容 |
| --- | --- |
| `core/character_settings.lua`、`core/character_pins.lua`、`core/provider_defaults.lua` | 角色存档隔离、显式选择、适用范围；EUI/EX 核心包缺失或原生禁用时默认关闭 |
| `sdk/provider_sdk_smoke.lua`、`core/provider_ingestion.lua`、`core/provider_record_ownership.lua` | 公开接收、隔离、原子更新、回调重入与旧实例 |
| `providers/achievements_provider.lua` | 角色权威缓存、温恢复、增量更新、战斗队列、损坏及旧数据保留 |
| `ui/interaction_smoke.lua`、`ui/navigation_binding.lua`、`ui/ui_runtime.lua`、`ui/view_lifecycle.lua` | 真实事件序列、行重绑、失败/取消、关闭重开、对象复用和焦点 |
| `providers/settings_navigation.lua`、`ui/history_actions.lua` | 设置只定位；别名/固定保留；准确动作历史与不可用旧参数引用 |
| `search/search_memory_regression.lua`、`search/search_compile_regression.lua`、`search/search_ranking_regression.lua`、`search/invocation_preferences.lua` | 独立参照、排名与引用身份、取消和恢复 |
| `providers/ellesmere_provider.lua`、`providers/ellesmere_equivalence.lua`、`providers/exwind_provider.lua` | 上游缺失、真实声明、解析/导航参数及查询取消；默认状态另由 provider_defaults 覆盖 |
| `integration/client_toc_load.lua`、`build/client_manifest.py` | 四客户端真实加载顺序、范围和能力过滤 |
| `performance/`、`build/sdk_delivery.py`、`build/repository_delivery.py` | 性能观测与生命周期门禁、版本及交付漂移故障注入 |

本表是导航，不是某次实机验收结论；完整执行清单由 check_contract.ps1 维护。独立性能诊断插件已退役，历史报告只作对照。实机用 lychee-dev 并记录当前安装提交、客户端、角色、Ticket、清理和未测项，见[验收索引](../docs/archive/validation/README.md)。离线通过不代表硬件点击、战斗、taint、字体/缩放或长期常驻已通过。
