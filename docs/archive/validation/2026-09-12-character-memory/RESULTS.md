# 角色设置与内存优化验证

2026-09-12。修改前源码 `c800a3d70b128d7eebb36d0fc055ff7193833437`；本轮实现见当前提交。用户取消严格 1 MiB 指标，要求按角色设置、自带 Provider 全开、保持体验。产品继续单包，UI Runtime 1。

## 成本与所有权

CharacterStore 统一存档所有权和恢复时序；元数据池每 Provider 最多 128 个、键最多 256 字节、弱值；普通声明动作共享受原有声明上限约束。成就当前角色 schema 4 平行数组为唯一权威数据，活动索引按启用创建、禁用释放；缓存沿用 32768 条、4 MiB 文本、7 天校验边界。关闭面板仅取消活动查询/绑定，保留昂贵缓存和原生控件，不新增空闲任务/轮询/强制 GC。战斗禁用/释放延续原有延迟规则。

旧账号面板设置一次转移给升级角色，已有角色字段优先；角色 pins 保持。旧账号自动关闭标志不导入新角色，当前角色显式关闭保留。旧成就多角色缓存仅迁出当前角色，其余可再生目录不再由账号持有。第一次访问尚无角色缓存的角色仍需正常分批构建。

## 离线同规模对照

Windows Lua 5.1；每个脚本独立进程。`collectgarbage` 仅由测试控制，用于区分累计分配与保留，不加入产品。原始输出在本目录；全契约输出记录最终复跑。

| 固定场景 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 2689 条完整测试目录保留 | 7218.8 KiB | 6888.7 KiB |
| 同场景 48 次查询累计分配 | 1823.8 KiB | 1823.9 KiB |
| 同场景查询后保留增长 | 0.1 KiB | 0.1 KiB |
| 6002 条成就场景保留 | 1337.5 KiB | 824.1 KiB |
| 同场景 10 次温恢复累计分配 | 6525.4 KiB | 1375.2 KiB |
| 同场景温恢复成就枚举 | 0 | 0 |

两个保留场景的数据组成不同，不能相加宣称全产品节省量。CPU 小样本、毫秒量化及机器负载有波动，不承诺按比例加速；48 次查询均值本次 .417ms、修改前 .396ms，不作为显著变化。成就恢复只减少临时图和重复保留，不以再扫描换内存。首页关闭释放业务引用；已有开关/品牌/输入框几何和新 Frame 门禁继续通过，未调整动画轨迹。

## 检查与实际结果

- `powershell -NoProfile -File tests/check_contract.ps1`：全量契约通过；含默认开启/明确关闭、角色恢复与隔离、SDK 所有权、安全输入与伪造凭据、原子失败/重入、池容量、查询等价、生命周期/动画几何及预算。新增 `provider_ingestion.lua` 纳入必跑入口。
- `python tools/performance-test/verify.py`：独立诊断 0.3.0 的正常、取消、错误、超时、重入、原生桥接模拟、覆盖门禁、报告读写通过；61 文件、60 Lua、57 产品模块。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：80 Lua、valid=true、无 diagnostics。
- Lua/XML/TOC 静态、产品/语言 manifest、`git diff --check` 通过。诊断模拟不是真实 WoW 引擎/taint 验证。

## 版本化 WoW 依据

所有下列证据 `sourceId=wow-ui-source, product=retail, requestedRef=latest, resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`；source check 本地/远端一致。

- `Interface/AddOns/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseUI_Mainline.toc:6`：`## SavedVariablesPerCharacter: g_auctionHouseFilters`；现有 Lychee TOC 已声明角色 SV，本轮仅加入角色存储模块加载项。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AchievementInfoDocumentation.lua:96`：`LiteralName = "ACHIEVEMENT_EARNED"`，97 `SynchronousEvent = true`；原有事件增量路径保留。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:48` canaccesstable：调用者可索引表及内容的权限；:65 canaccessvalue：调用者访问值的权限；:263 issecretvalue：是否为 secret。接收边界保留访问检查，测试哨兵不能模拟引擎 taint。

本目录 JSON 保存存档/事件精确 excerpt 与 validate 结果；边界源码证据也记录在 `tests/provider_ingestion.lua`。

## 尚待真实客户端

旧完整基准 `LYCHEE-PERF-1789203670` 是修改前证据，不能用它声称本轮客户端内存已下降。新增模块后重启客户端，使用更新诊断包采集并落盘；新报告自动记录真实源码提交、dirty 与树哈希。需核对全来源开启、角色切换、冷热/关闭常驻、已访问页面高水位、硬件 Alt+Space/Esc、战斗、长期后台与动画视觉。本轮未操作游戏、未自动执行诊断、未修改用户 SV 文件。回滚用新 git revert，验证后重新同步，保留角色设置可读数据。
