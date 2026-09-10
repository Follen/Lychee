# 统一关键词触发：Provider API 2 / revision 5

基线 214b474。新增 searchMode=keyword、searchKeywords 声明；更新 Host、SDK helper、manifest、LuaLS 类型、接入／协议／架构／设计文档和设置页。旧 revision 1–4 兼容，旧 searchable=false 独立查询保留。队伍钥匙迁移到声明式触发，移除重复触发判断和 queryRows 目录，稳定条目 ID 不变。

设计与成本：关键词精确路由只由 ProviderPolicy 负责；大小写和首尾空白处理保留标点差异，不调用通用模糊匹配。注册、注销、用户保存时失效快照；热查询查表，不遍历 Provider。触发命中转换为空文本 sourceID 查询，Index 只执行通用过滤。每来源最多8个、每个48字节的触发词；与前缀分开占用、校验和存储。快照由已注册来源的有限声明与最多128条用户覆盖构成，不按搜索次数增长。历史输入重新校验，重复归属不路由。沿用原预算，未提高门槛。

生命周期：非触发查询不调用该来源 query；禁用不返回记录，注销使快照失效。队伍查询仅保留原10秒刷新限频和既有事件；无新增空闲事件、计时器或 OnUpdate。设置页懒创建固定四项选择，前缀与触发词草稿分开，切换保留、取消丢弃、保存提交；界面关闭沿用焦点、拖动和动画清理。

完整 tests/check_contract.ps1 通过（.codex/keyword-full.txt）。关键词回归覆盖声明版本门禁、空词表、精确中英文／大小写／空白、标点保留、普通查询静态及动态排除、路由后的公开回调形状、别名原边界、前缀不能绕过 keyword 模式、冲突、前缀同名共存、改词、模式切换、更新、禁用恢复、注销与 reload。额外测试长度／数量／重复限制及非法 SavedVariables，.codex/keyword-confirm.txt 通过。设置交互测试覆盖两种词表草稿互不覆盖并实际执行搜索。内置扩展测试加载与生产相同的 ProviderPolicy，保留队伍分数、通信限频、角色名／副本名不误召回及标点回归。

固定2689条目录离线结果：前轮 combined 7253.5 KiB，本轮7256.9 KiB（+3.4 KiB）；48次搜索分配1814.1 KiB不变，保留增长0.1 KiB；平均0.375→0.354 ms，单轮数据不作为速度收益结论。1000来源UI仍为8行，常驻458.0 KiB，20次刷新分配37.4 KiB，池增长0。测试新增策略后内置扩展100次查询分配3953.8 KiB，预算通过。无游戏实测帧率或 taint 结论。

wowdoc source list/check：wow-ui-source / retail / requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。沿用的通信接口证据：Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua:469–482，RegisterAddonMessagePrefix(prefix:cstring) 注册非空前缀，返回 RegisterAddonMessagePrefixResult（.codex/keyword-api.json）。无新增 Blizzard API。retail／classic／titan／anniversary validate 全部 valid=true，各检查71 Lua，无诊断。Lua/XML/TOC与git diff静态检查通过。

实际客户端缩放、四项选项滚动、编辑焦点、战斗及首次目录更新显示仍待实机验收；离线不证明原生绘制。没有新增模块或TOC改动，同步后 /reload 验证。回滚用新的 git revert 并按项目流程同步。
