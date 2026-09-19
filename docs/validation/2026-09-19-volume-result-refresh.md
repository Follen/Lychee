# 音量操作后的结果刷新

基于 465ad7d。复现命令 `lua tests/ui/volume_result_refresh.lua` 在修复前失败：实际值已为 40%，当前候选仍显示 30%。成功回调只更新最近使用和状态，没有重读候选展示。

修复后成功回调通过既有 Provider Resolve 重读原 entryID，只替换副标题与说明。动作引用、输入、排序、滚动位置和搜索代次保持不变。读取前后核对行身份，失败、换查询、关闭或进入其他页面不回写。每次成功最多一次单条解析和一次已有有界列表重绘；无新索引、缓存、事件、计时器、全量搜索或空闲工作。公开 SDK 接口不变。

中英文真实 Provider → Invocation → ResultList 离线用例通过，覆盖 30→40、失败不伪造成功、过期代次和关闭保护，并断言搜索执行次数为零。完整契约检查通过，Lua 语法及发布检查通过。游戏内显示仍待 /reload 后验证，不声称已实机通过。

wowdoc 隔离诊断副本完整扫描 111 Lua；valid=false，仍为 28 条已知事件识别诊断，工具限制见 [静态复核](2026-09-19-wowdoc-review.md) 和 [清理记录](2026-09-19-single-addon-cleanup.md)。本次没有新增 Blizzard API、事件或 Frame。读取证据 sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59；既有 CVAR_UPDATE 订阅见 Interface/AddOns/Blizzard_SharedXMLBase/CvarUtil.lua:129 的 RegisterEvent 关系，本修复不增加该订阅。未解析调用仍未验证。
