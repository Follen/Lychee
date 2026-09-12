# 正式服团本技能关系与国际化验证

## 数据与来源

采集 Ticket `LYCHEE-20260913-021745-0019`，source kind `automation_result`；客户端 retail 12.1.0 build69587 / Interface120100 / zhCN。完整结果位于 Lychee Dev 的 `LycheeDevDB.exports.records[TICKET].payload.content`，报告 schema `lychee.automation.result.v1`，complete=true，outputTruncated=false。原报告161233字节，SHA256 `9b79ffcd259cc9c8dd05883905b015c3772d8cf7bb56fd7e0d9efc352090ead0`，已经落盘、读回验证并ACK。

版本控制保留 [原始关系TSV](../architecture/raid-journal/retail-zhCN.tsv) 和 [非私人采集清单](../architecture/raid-journal/manifest.json)。不保留角色/账号等私密环境字段；运行包不包含这些文件。生成命令 `python tools/build_journal_catalog.py`，校验命令加 `--check`，不访问网络、不运行游戏、不读wowdata。

采集依次枚举原生指南 tier 与 raid=true 入口，对实际支持的3/4/5/6/9/14/15/16难度分别枚举首领并遍历未被 filteredByDifficulty 排除的 section；收集 spellID、sectionID和难度。32节点/1ms检查让出；总180秒、最大200000节点、32768关系。任务结束/取消/战斗/打开指南都停止。初始实例未知（initialInstanceKnown=false），仅恢复已知tier/难度等选择，不宣称完整恢复未知原生选择。

实测70入口、490首领、35251节、8003条原始关系，1186批，4.833秒完成，最大批6.7531ms。跨重复section按同一首领/技能/难度选最小sectionID，产生5813个首领/技能组、14392个难度关系。普通包括旧版3/4/9和现代14；英雄包括5/6/15；史诗16，均来自当前客户端实际支持检查。无指南技能的老首领不补造关系；不推断DB2位掩码。

生成数据是已捕获版本的快照，未来补丁需重新采集、更新manifest及运行独立对照测试。不是持续自动更新服务。荔枝大米助手仍只覆盖自己的16副本；排除团本来源中的地下城不代表补全全部历史地下城。

## 接口与生命周期

[API证据](2026-09-13-raid-journal-api.json)记录 wow-ui-source / retail / latest，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34` 的path/line/excerpt；源检查当时本地与远端一致。原生 `EncounterJournal_OpenJournal` 的difficulty、instance、encounter、section参数负责精确打开，动作后验证难度与目标，战斗走既有错误提示。

静态首领目录仍由 CatalogProvider 管理，技能仅当前查询扫描。公开条目具名；持久化ID包含首领、技能和选定难度，恢复/动作重新核对关系。同首领/技能跨难度一条，不同技能ID或首领不按名称合并。中文荔枝大米助手/团本首领名称与稳定ID分离，规范见根 i18n.md，AGENTS.md 已引用（按仓库策略仅本地）。

精确首领/副本/ID先返回；其余每128技能组/1ms检查让出，有界Top20。查询作用域拥有扫描、待加载集合、事件和deadline；最多等待1.5秒后最后重扫。同步加载、失败、取消、禁用、战斗都收尾。无新增空闲OnUpdate、SV或全量技能名索引。所有语言注册要求 SDK API2 revision7，以确保query托管资源存在。

## 离线测量与额度

基线 `670395a9a0468d9ae4bf75910a00c6aff5b309aa`，Windows Lua5.1，相同相对源码路径、同测试入口各一次；CPU观测不当作稳定提速结论。

| 口径 | 旧版 | 新版 |
| --- | --- | --- |
| 不含LDT、TOC回收后KiB | 1342.5 | 1441.9 |
| 完整Mainline、TOC回收后KiB | 1716.8 | 1818.1 |
| 完整Mainline加载CPU ms | 23 | 24 |
| 完整Mainline加载累计分配KiB | 4056.5 | 4088.2 |

新增5813技能组与准确难度使常驻增加约100KiB；这是新能力的代价，不能称为优化节省。正式服不含LDT组合明确增加128KiB新功能额度（1346→1474），完整1858KiB/<61ms总门槛不变，其他客户端和旧搜索/启动额度不变。

新增20次全目录查询（zhCN/enUS）观测累计分配约6451–6478KiB、回收后增长32.7KiB、最大回调2ms；门槛分别8192KiB、128KiB、8ms。名称API为离线替身，不能代替冷客户端名称加载成本。LDT原44组双语言业务快照仅投影规范化授权改名，另独立断言实际新名；其查询/布局业务不变。

## 验证入口

- `python tests/journal_catalog.py` 独立原始关系对照，全部14392条，不导入生成器作为oracle。
- `lua tests/raid_abilities.lua` 和 `enUS`：难度、同名不同ID、名称歧义、准确跳转、异步/同步/失败、取消后的迟到事件、禁用/恢复、非法恢复、战斗。
- `lua tests/ldt_provider.lua`：44组旧结果及独立新显示名、生命周期与既有内存门禁。
- `lua tests/bosses_locale.lua`、`tests/builtin_providers_smoke.lua`：首领本地化、团本范围与原生入口。
- `powershell -NoProfile -File tests/check_contract.ps1`、`wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref latest`、`git diff --check`：完整交付验证。

原生数据采集已实机完成；新增搜索同步后的实机结果另记，不把离线测试等同于客户端行为。没有进行团本战斗/姓名板压力测量，本改动不新增这些场景的常驻扫描。

完整契约入口、88个Lua的luac、XML解析、wowdoc validate（88 Lua，diagnostics=null）及git diff --check均通过。启动规模由2689变为2025（排除地下城后490团本首领）；48次组合查询将死亡矿井换为熔火之心，保留原7168/4096/512 KiB门槛。规模和样本改变，不将该序列下降报告为优化收益。
