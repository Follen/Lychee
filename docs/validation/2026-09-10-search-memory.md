# 搜索索引内存优化

日期：2026-09-10。用户截图显示 Lychee 占用 46.74 MB。按 AGENTS.md 引用的 Ellesmere 准则，先测量 GC 后的保留内存，再调整对象布局和缓存所有权，不添加运行时强制垃圾回收。

## 复现和定位

基线提交为 `aec7645`。两条独立离线命令都直接使用真实 Provider 与索引代码，坐骑场景不创建搜索结果 UI：

```powershell
lua tests/mounts_vault_smoke.lua
lua tests/builtin_providers_smoke.lua
```

修复前分别测到 16,527.5 KiB 和 19,136.4 KiB 的 GC 后保留增量。为两组固定数据分别添加 8 MiB 回归门槛，已观察原实现报错 `retained index exceeds 8 MiB memory budget` / `retained indexes exceed 8 MiB memory budget`，修复后通过。门槛针对这些固定离线场景，不是所有角色的游戏内总内存上限。

按以下假设顺序调查：记录多层拷贝、拆词辅助对象过多、查询/持久化缓存保活。`tests/profile_search_memory.lua` 在独立 Lua 进程中逐项移除引用并测量 GC 后差值；它是显式标记的离线破坏性诊断工具，不进入 TOC，不由正式测试套件执行。

1,500 坐骑基线的直接归因：

| 引用 | 数量 | 移除后释放 |
|---|---:|---:|
| entry.memberships 的逐关系小表及容器 | 53,451 个关系 | 4,833.6 KiB |
| entry.membershipSeen 去重表 | 53,451 个键 | 3,168.0 KiB |
| 规范化和上一查询缓存 | — | 64.3 KiB |
| 持久化副本 | — | 0 KiB；Persist 已为 no-op |

主要原因是倒排索引之外又长期保存逐关系的重复辅助对象。公开边界的输入拷贝承担隔离职责，保留其语义，没有通过共享 Provider 的可变表来省内存。

## 修改

- `Search/StaticIndex.lua` 不再为每条记录保留 memberships 和 membershipSeen。索引集合自身负责去重；增删均从该条记录的编译字段枚举相同前缀、词和字片段，不扫描其他条目。
- 只有一个条目的集合直接保存字符串键；第二个条目加入时转为集合，删除后剩一个条目时缩回字符串。候选收集兼容两种表示。
- `Builtin/Mounts.lua` 本地只存 `{title,icon,spellID}` 的变更快照。完整动作、拖拽和 payload 交给 Provider 持有；无变化时复用原快照，提交成功后才更新。
- 搜索内容、中文匹配、排序、分类、增量更新、SDK 拷贝隔离与动作类型均未减少或改变；没有新增事件、timer、OnUpdate 或运行时 GC。

## 相同数据的前后结果

Lua 5.1 离线测量；内存均在完整 GC 后读取，启动成本包含相应场景的注册/索引。时间取完整回归中的一次样本，短时间值存在计时粒度和系统抖动。

| 场景 | 优化前 | 优化后 |
|---|---:|---:|
| 1,500 坐骑保留内存 | 16,527.5 KiB（16.14 MiB） | 6,691.4 KiB（6.53 MiB），降低 59.5% |
| 1,154 首领及其他静态 Provider 保留内存 | 19,136.4 KiB（18.69 MiB） | 8,058.4 KiB（7.87 MiB），降低 57.9% |
| 坐骑初始化 | 134 ms | 125 ms |
| 首领等初始化 | 147 ms | 132 ms |
| 坐骑 100 次交替查询均值 | 5.140 ms | 5.190 ms |
| 首领等 100 次交替查询均值 | 4.670 ms | 4.500 ms |

另用 `profile_search_memory.lua mounts updates` 对同一场景测量取舍；可将旧提交的 StaticIndex.lua / Mounts.lua 导出至临时目录，作为该工具第 3/4 参数传入，在独立进程替换对应模块读取，不修改工作树或正式服副本：

| 操作 | 旧版 | 新版 |
|---|---:|---:|
| 单条记录更新，100 次均值 | 0.030 ms | 0.040 ms |
| 一次注销全部 1,500 条记录 | 20 ms | 33 ms |

删除时重算关系有额外 CPU 成本，换取持续存在的内存下降。坐骑更新仍在战斗中只标记 dirty、脱战后处理；单条事件仍局部更新。全部注销属于低频清理，没有改成每帧工作。不能将离线结果直接换算为截图里的游戏内总量。

## 验证与版本

- 12 组完整契约/交互测试通过，含两项新增内存门槛。
- 增加共享别名的插入、删除一个拥有者、再次插入、改名、分类浏览、Rebuild 和全部注销测试，确认单条目/多条目表示转换不丢失候选、不留下索引引用。
- 坐骑完整索引失败、局部更新失败、移除、禁用/重新启用、旧回调、召唤成功/失败、列表及最近使用拖拽继续通过。
- 55 个运行时、SDK、测试 Lua 文件 `luac -p` 通过；Bindings XML 和 TOC 引用检查通过；`git diff --check` 通过。
- wowdoc source check 确认 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`，本地及远端 `resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。
- 改动不增加 WoW API；内存计量定义和既有坐骑详情 API 的 path/line/excerpt 见 [版本证据](../architecture/2026-09-10-search-memory-wowdoc.json)。例如 `Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua:94` 定义 UpdateAddOnMemoryUsage；坐骑详情沿用 `MountJournalDocumentation.lua:273`。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest` 检查 37 个运行时 Lua，valid=true、零诊断，见 [校验结果](../architecture/2026-09-10-search-memory-validate.json)。

## 交付和实机范围

检查并提交后覆盖复制运行时至 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，检查完整文件清单及全部 SHA-256；不复制分析工具、测试或文档，不删除目标文件。无 TOC 改动，使用 `/reload` 加载新版。

目前仅有用户提供的优化前 46.74 MB 截图；未取得相同角色优化后的实机内存、CPU、帧时间或 taint 数据。需在相同角色 `/reload` 后，以相同空闲时间和同一内存统计工具复测，并检查名称搜索、召唤及动作条拖拽。登录、空闲、单目标、多目标/团本、姓名板峰值及窗口开关的实机 CPU/内存/帧时间仍待采集；本次离线证据不替代这些场景。

回滚使用新的 `git revert` 提交，复核并重新复制；不改写已交付历史。内存门槛随修复提交保留，防止再次引入逐关系常驻小表。
