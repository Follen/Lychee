# 成就 Provider

新增 builtin.achievements，宏 Provider 已按用户要求取消。成就支持名称多词子串、ID、成就/achievement/achievements 类别过滤；普通点击定位成就，Shift 点击或右键分享将链接插入聊天输入框，不自动发送。已有输入框优先 InsertLink，否则 OpenChat；接口返回失败不报告成功。历史条目通过 resolve 重新读取，展示当前完成状态、点数、条件进度，单条件读取实际数量/目标数量。

目录覆盖角色成就分类及系列前后阶段，按 ID 去重。独立紧凑的 ID/标准化名称数组，最多 32,768 条，达到上限报错而非默默截断；不提高公共静态 Provider 4,096 上限。仅名称参与文本匹配，描述显示在结果详情，不建立全文描述索引。共享 CatalogProvider 增加可选 resolve 转发，不改变已有来源行为。

生命周期：默认关闭，无新增来源 Frame/扫描/timer。启用创建一个事件 Frame，沿用目录协程每 32 checkpoint 或约 1 ms 让出、0.01 秒调度；目录建立后只留两个数组，不留 criteria 树或完整记录。没有登录时预建成就界面。战斗暂停构建，脱战重建；停用取消目录和查询任务、清除数组与订阅，重复启停复用 Frame。缓存名称不会因 criteria 进度变化重建；状态在每次查询/历史解析时重新读取。

查询单任务，最多 256 条/约 1 ms 后让出，选取最多 50 条，优先精确匹配、前缀，再按 ID 稳定排序；条件读取另分批，每批最多 8 个结果/约 1 ms。单成就最多读 256 个条件，超过时显示完成/未完成，不伪报条件进度。不使用全量真实 UI、无每帧轮询；取消解除 reply、候选和结果引用。首次启用建目录需要等待；大于 Host 5 秒请求时限时当前查询可超时，目录仍继续分批建立，后续查询可使用完整目录。

预算：固定 6,002 条目录保留低于 4 MiB，20 次重复查询临时分配低于 1 MiB、保留增长低于 128 KiB，关闭后活动工作为零。实际 Lua 5.1 模拟：目录保留 560.6 KiB；20 次查询累计 149.9 KiB、回收后增长 0.0 KiB；批次峰值 1–2 ms（粗粒度计时，多次运行范围）；来源仅新增 1 Frame，停用无任务、无订阅。总 frames=2 含共享 Host，未将它全算成 Provider 成本。未测游戏内原生 API 延迟、引擎内存、团本帧时间。

tests/achievements_provider.lua 使用真实 Host/Registry，验证超 4,096 目录、系列、精确 ID、多词、50 条上限、动态搜索、历史恢复、完成状态变化、普通点击、Shift 分享、右键分享、聊天失败、取消迟到结果、战斗暂停、重复启停。完整 check_contract PASS；Lua/XML/TOC 检查、wowdoc validate checkedLua=46 valid=true、diff 检查通过。原始数据 achievements-checks.txt。

API 证据见 achievements-api.json：wow-ui-source / retail / requestedRef latest / resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34。Mainline Achievement UI 的 SelectAchievement:2659、criteria tuple:1499、聊天链接:1106 等；ChatFrameUtil 使用当前命名。现有 achievements.tga 与可编辑 Trophy.svg 保留，已核对 flat-atlas 的米白奖杯/红星样式，结果仍用原生成就图标，无新增纹理资源。

新增 TOC 模块，交付同步后需重启客户端，再在功能来源开启“成就”。游戏内搜索定位、系列选择、聊天焦点与分享尚待实机验证。回滚使用新 revert 提交后同步。
