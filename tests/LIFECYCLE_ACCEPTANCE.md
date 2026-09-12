# 生命周期与风险覆盖

当前契约为五包架构、SDK 1.0.0 / Provider API 1.0.0。执行方式、夹具规则和分组见 [测试入口](README.md)；性能阈值只在 [PERFORMANCE.md](../PERFORMANCE.md) 维护。

## 可执行风险地图

| 风险 | 主要回归文件 | 验收重点 |
| --- | --- | --- |
| 子包相互依赖、Host 接管业务 | integration/package_namespaces.lua、package_combinations.lua | 真实 TOC，Host 单独、单个子包、完整/反序组合；自身存档恢复、登录前后、重复通知、无提前 UI/业务 DB |
| 产品/语言不匹配 | integration/client_toc_load.lua、client_providers.lua；sdk/client_contract.lua、provider_locales.lua；ui/i18n_ui.lua | 四产品 TOC、语言隔离、scope、缺 API、首领/技能名动态解析；离线能力替身不代表所有客户端实测 |
| 角色串数据、覆盖损坏档 | integration/character_settings.lua、character_pins.lua、pin_restore.lua；sdk/sdk_storage.lua | 原始 SV 与写入同界限、根替换、独立命名空间、原子迁移失败、未来版保留、温读预算 |
| 公开输入绕过 SDK | sdk/provider_sdk_smoke.lua、client_contract.lua、sdk_catalog.lua | 原始必填输入、旧 API/旧字段拒绝、错误 reply、256 候选、动作声明不一致、伪造 Catalog 转交 |
| 目录所有权或事务泄漏 | sdk/provider_ingestion.lua、provider_record_ownership.lua；providers/catalog_ledger.lua、catalog_lifecycle.lua | secret/metatable/cycle、外部修改隔离、私有凭据、失败无半更新、取消/重注册、重入、墓碑与释放 |
| 取消后继续工作或覆盖新状态 | sdk/sdk_resources.lua、notifications.lua；search/search_session_smoke.lua、search_lifecycle_regression.lua | timer/event/作用域额度与归零、迟到结果、取消回调重入、通知本轮快照、回调错误隔离、64 订阅回收 |
| 搜索结果被优化丢掉 | search/search_quality.lua、search_compile_regression.lua、search_ranking_regression.lua、search_memory_regression.lua | 独立参考、非空样本、排名/证据/动作、混合语言、增删、取消与缓存容量 |
| 复用行执行错动作 | ui/interaction_smoke.lua、navigation_binding.lua、result_list_ui_smoke.lua、provider_management.lua | 按下→重绑→松开、正常点击、安全覆盖层、注销/重开、旧管理实例拒绝、长分类单行 |
| 导航失败后黑框或残留焦点 | ui/navigation_binding.lua、view_lifecycle.lua、ui_library_integration.lua | create/Mount 失败回滚、footer/高度所有权、释放旧 context、保留表单实例和真实 SDK 示例 |
| 动画抖动与池增长 | ui/ui_motion.lua、presence_geometry.lua、brand_geometry.lua、brand_motion.lua、ui_runtime.lua | 开关镜像轨迹、中断/反向、原 Logo 局部几何、减少动态效果、隐藏解绑、零新增对象；不冒充视觉验收 |
| 成就缓存重复与漏事件 | providers/achievements_provider.lua | 6002 条单角色数据、事件增量、战斗积压、分类/损坏重建、温恢复零枚举、SV roundtrip |
| 上游适配预建 UI 或残留任务 | providers/ellesmere_adapter.lua、ellesmere_equivalence.lua、ellesmere_provider.lua、exwind_provider.lua | 独立查询结果/动作对照、缺上游、加载失败、取消/禁用、无提前设置页及空闲任务 |
| LDT/团本关系或详情缺失 | providers/ldt_provider.lua、raid_abilities.lua；delivery/ldt_data.py、journal_catalog.py | 全量事实对照、双语、同名技能展开、难度、同步/异步/失败加载、模型交互、技能聊天链接与对象复用 |
| 总成本被拆包掩盖 | performance/ 下全部用例及上述业务内预算 | 五包合计、冷/热/分配/保留分开，缺省来源保持，禁止改阈值或强制 GC 伪造收益 |
| 测试/交付自身漏检 | contracts/runner.py、syntax.py、architecture.ps1；delivery/ 下全部用例 | 漏登记、重复、路径、非零/超时、完整清单、错误版本、跨包/越界、事实漂移、独立 SDK 交付 |

表格是风险定位，不是另一份执行清单。完整入口由 suites.json 管理；更新能力时同步其所属回归和本表。不要把脚本数当作覆盖率。

## 交付前

1. 全量 `python tests/run.py --report analyze/tests/latest.json`，检查报告的 scope 为 full、全部命令通过；局部绿灯不能称全量通过。
2. 原预算失败保留输出并调查；不自动重试、不临时提高门槛。修改夹具或测量范围时写明影响，不能宣称生产性能提升。
3. 运行时改动按项目规则查 wowdoc、验证对应产品和 API；检查 git diff。纯测试/文档改动不重复同步游戏文件。
4. SDK、生成数据、交付文件变动执行相应构建 --check。普通验证不更新游戏数据、重建媒体或安装诊断插件。

## 必须单列的游戏验证

离线替身不能证明：真实冷启动/全来源加载的总内存、角色切换、长期驻留、原生模型与纹理成本、硬件 Alt+Space/Esc、Shift 技能聊天链接、安全动作、战斗/taint、动画和布局视觉。

实测记录客户端 build、sourceCommit/dirty/hash、插件组合、步骤、样本、采样开销与结果。未执行写“未验证”；历史 Ticket 和旧版本通过记录不自动继承为当前实现通过。独立常驻性能测试插件已退役，不再作为执行前提。
