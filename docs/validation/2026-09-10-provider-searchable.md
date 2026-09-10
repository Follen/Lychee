# Provider 通用搜索声明

基线 `726d099`。API 2 / revision 3 添加可选注册字段 `searchable`：默认 true；false 不编译文本字段、不加入倒排索引，来源过滤和用户别名也不绕过。仍持有原 canonical 记录以供 Update、Resolve、动作、固定和历史使用；不是 disabled。声明类型和最低 revision 校验，注册后不可通过 Update 改写。

队伍钥匙使用同一公开协议，不在 Query/Index 写 Provider ID 特例。query 仅响应规范化完整 key／分数／钥匙；其他查询及时返回空表。CatalogProvider 只转发通用配置，不增加查询调度器。保留最多五人的原始查询快照，在目录提交完成后发布；取消/禁用释放快照，原定时批处理与通信节流不变。快照只为 SDK 动态查询提供未命名空间加工的记录，不访问 Host 私有 recordMap。

预算：无新 Frame、事件、timer 或空闲循环；索引关闭来源不持有文本字段和 postings。固定目录和 Provider 回归预算不放宽。专项验证类型/revision/默认兼容、动态响应、直接过滤、别名、增删、引用解析、停用恢复及无索引字段；队伍测试覆盖三个入口、大小写/空格、副本与角色负例、钥匙/分数变化及消息节流。

沿用本轮 wowdoc retail 来源证据 `wow-ui-source / latest / 8ea15b61e45c0ed4eba01439c90757f86eb78d34`，无新增游戏 API；PlayerInfoDocumentation.lua:165–178 的评分接口不变。

`tests/check_contract.ps1` 全部通过，包含四客户端 × 两语言加载和旧 Provider 契约；四产品 wowdoc validate 均 valid=true、69 Lua。`search_personalization.lua` 的协议专项及 `provider_expansion.lua` 的三个触发词正反例、单本成绩更新通过。Lua/XML 静态解析与 diff 检查通过。

离线 2689 条整体目录：前轮常驻 7239.2 KiB，本轮 7239.9 KiB；48 查询分配仍 1814.1 KiB，平均 0.375 ms（前轮 0.354 ms，单轮时钟差不据此声称收益）。扩展固定场景常驻 2317.9 KiB（前轮 2320.7 KiB），100 查询分配 3946.2 KiB，未观察到保留增长。所有既有预算通过。原始记录 `.codex/searchable-contract.txt`、`.codex/searchable-*.json`。无新增 TOC，游戏内三个关键词、队友换钥匙、详情及安全动作待 `/reload` 验证；离线检查不代表已完成游戏战斗/团本场景测量。
