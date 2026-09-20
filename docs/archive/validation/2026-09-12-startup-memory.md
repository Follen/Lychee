# 启动临时分配优化

## 范围与先验预算

基线提交：`4cecca9b44c2f646c510468808f78108fef881aa`。用户实测 reload 后开关十次为
28.59 → 14.23 MB，手动 GC 后继续开关稳定；该结果说明本次截图不能直接作为泄漏证据。
本验证单独测 Provider 注册 → Registry 发布 → StaticIndex 编译，不包含面板动画。

在修改运行时前新增 `tests/performance_startup.lua`，加载真实 Host/Provider/Index，固定内置首领、
纹章、游戏入口加 1,500 坐骑，共 2,689 条索引记录。未查询、不创建页面、未延迟数据或减少字段。
初次基线为 21,891.87 KiB 累计分配、6,554.61 KiB GC 后保留，重建 8,648.38 KiB。
据此在实现前设定启动分配 `< 15,000 KiB`、保留 `< 7,424 KiB`（沿用已有7.25 MiB门槛）、
重建分配 `< 4,500 KiB`、重建保留增量 `< 128 KiB`。旧实现使用相同测试明确失败于启动分配预算。

该测试先加载模块和静态目录再 GC，因此测量注册/索引成本，**不包含 Lua 文件解析及所有真实客户端 Provider 的完整 reload 成本**。
只在独立测试中暂停 GC，采样后恢复并完整回收；运行时代码没有新增 GC 调用或计时器。

## 实现与所有权

- Normalizer 直接把本地化字段编译到最终的扁平三元组，跳过临时 localized 数组、entry 表和过滤数组。
  保留原有 `Localized` 物化接口，locale 顺序、父 scope 与条目 scope 均保持相同语义。
- StaticIndex 逐字节识别同样的 UTF-8 字符边界，直接更新幂等 posting 集合，移除每字段的字符位置数组、
  字符列表、seen 表以及每记录的重复字段标识字符串。没有持久字符缓存或共享 scratch 容器。
- ProviderRuntime 的本地化字段名单改为模块级只读表。
- ProviderRuntime 仍先验证并深拷贝公共输入。Registry 使用私有弱键映射接收已隔离列表的一次性所有权，
  避免再次复制整份列表后立即丢弃上一份。凭据不来自公开描述字段、不暴露于 SDK facade，且检查 owner。
  验证、类别归属、重复 ID、版本和事务提交检查均保留；未提交成功不更新 Provider 的 canonical 记录。

所有权表仅由 Registry 写入，key 是宿主内部列表，value 是 owner ID；消费即删除，无重试队列或历史缓存。
失败后不可达的列表是弱 key，不会被该映射保活。字段编译只写调用方传入结果，不跨回调共享可变缓冲。
开始注册/更新时创建临时列表；索引和 Provider 接管成功后共同引用 canonical 记录；更新失败/注销按原生命周期释放。
无新增事件/每帧回调；本固定启动保留原来一个坐骑事件 Frame（不是 UI Frame），未新增 Frame。

## 五轮前后交替测量

Windows、本机 Lua 5.1.5；相同数据、模块、语言 zhCN、retail 身份、同一个测试入口。
通过 `git archive HEAD package/Lychee` 导出基线，`LYCHEE_PERF_BASELINE` 仅改变源文件根路径。
每个样本是独立 Lua 进程，冷启动不预热；重建单独在启动完成并 GC 后测量。
`--record` 只记录数字，默认模式执行预算。

| 样本 | 旧启动 KiB | 新启动 KiB | 旧启动 ms | 新启动 ms | 旧重建 ms | 新重建 ms |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 21891.76 | 13133.21 | 227 | 194 | 67 | 51 |
| 2 | 21891.88 | 13133.21 | 226 | 204 | 73 | 55 |
| 3 | 21891.88 | 13133.21 | 228 | 208 | 69 | 47 |
| 4 | 21891.88 | 13133.08 | 217 | 199 | 67 | 46 |
| 5 | 21891.88 | 13133.21 | 221 | 188 | 61 | 48 |

中位累计分配：启动 **21891.88 → 13133.21 KiB（-40.0%）**，重建各轮均为
**8648.38 → 2828.60 KiB（-67.3%）**。启动 GC 后保留为 6554.63 → 6554.67 KiB，基本不变；
本段可回收部分为 15337.25 → 6578.54 KiB。重建 GC 后增量每轮均约 0.13 KiB。
累计分配不等于客户端峰值；该测试未观察到重建保留增长，不能据此宣称客户端无其他泄漏。

启动耗时中位/最大为 226/228 → 199/208 ms；重建为 67/73 → 48/55 ms。
这是同步离线全量工作时间，既不是每帧成本，也不是游戏 FPS 证据。真实采集、引擎和其他插件会改变数字。

## 正确性与检查

- `lua tests/performance_startup.lua`：新实现五轮通过；基线以同测试默认模式失败于 15,000 KiB 门槛。
- `lua tests/search_compile_regression.lua`：280 组语言/父级及条目 scope 对照原 `Localized` 路径，
  编译字段内容和顺序一致；所有字节与重复字段的 posting 对照独立旧式边界算法，删除/停用/恢复一致。
- `lua tests/provider_record_ownership.lua`：注册、replace、upsert 后修改调用方嵌套数据不影响宿主；
  重复 ID、注入提交失败和恢复、伪造字段、Update 重入均通过。
- `lua tests/performance_memory.lua --check`：2689记录，combined 7218.7 KiB；48 查询累计 1823.8 KiB，
  保留增量 0.1 KiB，沿用已有预算通过。
- `provider_sdk_smoke.lua`、`provider_locale_ownership.lua`、`framework_sdk_smoke.lua`、`perf_core_provider.lua`、
  `search_memory_regression.lua`、`search_platform_smoke.lua`、`search_quality.lua`、`search_ranking_regression.lua`、
  `search_lifecycle_regression.lua`：通过；没有放宽现有测试预算。
- 运行时 Lua 静态、完整契约和最终同步由主任务整体验证；本记录不替代最终客户端验证。

## 版本证据

2026-09-12 `wowdoc source check --source wow-ui-source --product retail` 返回本地和远端均
`8ea15b61e45c0ed4eba01439c90757f86eb78d34`、`updateAvailable=false`。
`wowdoc query --source wow-ui-source --product retail --ref latest --topic code --text 'string.gmatch' --limit 2`：

- sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。
- path=`Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua`，line=13：
  `for clickToken in string.gmatch(cancelAuraButtons, "[^,%s]+") do`。

本变更只涉及现有 Lua 表/字符串算法、私有所有权和测试；没有新增 Blizzard API、事件、Frame、Binding 或 TOC。

## 游戏内待验证

固定插件组合、客户端 Build 和角色目录，reload 后等待同样时长，分别记录插件统计、GC后常驻及首次结果延迟；
再比较快速开关、输入、战斗/空闲与来源停用恢复。用户之前的 14 MB 是整插件客户端统计，不能拿本测试6.4 MiB
注册增量直接对应或承诺新客户端峰值。运行时代码不强制 GC；回滚采用正式提交的 `git revert`。
