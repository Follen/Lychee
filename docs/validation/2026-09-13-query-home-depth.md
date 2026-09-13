# 查询发布与首页职责深化

业务基线：`34e09bbbdc2ad915829d428696cf4472e7aab27a`。用户确认落实架构报告的两个候选；不改变公开 SDK 1.0.0、查询覆盖、显示文字、排序或动作合同。

## 实现与成本

- ProviderRuntime 随结果交付 waiting；Query 的同步/异步路径保留该状态，SearchSession 校验身份后通过单次 ApplySearchState 交给 Palette。身份失效与有结果发布共用入口，滚动只重绘已经接受的列表。未新增发布对象、候选副本、持久缓存或后台任务；Query 已有 last 记录增加一个布尔字段。
- 同一 operation 内的嵌套发布有独立序号，外部别名解析返回后再次校验，不能回退结果/等待状态。取消若重入新查询，旧 Filter/Invalidate 不再取消或清空新输入。会话、查询代次、operation、来源版本与注册实例不合并。
- 新增 HomeView，迁入原有首页布局和生命周期，并集中管理恢复、dirty、容量、绑定和释放。Palette 不访问首页 tiles/sections/content。导航仍归 Palette，动作与存储规则仍归现有所有者。
- 加载文件在原 Palette 前增加 HomeView；它不在加载期创建 Frame。移除 Palette 中已失去用途的首页辅助代码，颜色直接使用先于 Palette 加载的 Theme。没有新增素材或字体测量。
- 触发频率与规模沿用原有输入去抖、来源变化、窗口开关、固定项与最近使用；最终结果最多 20，固定项最多 64，最近引用最多 8、首页显示最多 5。对象池、关闭/战斗清理、重试次数和所有性能门槛继续以 PERFORMANCE.md 为准。
- 普通首页隐藏只停止其提示；窗口关闭完成时释放 sections/结果/交互引用，保留原生池。HomeView 不增加 timer/OnUpdate；战斗准备仅标 dirty，不扩池。

## 原生接口证据

见 [结构化 wowdoc 证据](2026-09-13-query-home-depth-wowdoc.json)。sourceId=`wow-ui-source`，product=`retail`，requestedRef/resolvedCommit 均为 `8ea15b61e45c0ed4eba01439c90757f86eb78d34`，固定到项目已有源码快照。source check 显示上游另有更新，本次没有将该快照称作最新。

- UITimerDocumentation.lua:39–53：NewTimer 接收 seconds/callback，返回可管理的 TickerCallback；沿用既有去抖和 deadline。
- SimpleScrollFrameAPIDocumentation.lua:91–101：SetScrollChild 的 scrollChild 为 SimpleFrame，调用受保护；首页继续首次使用创建，战斗不调整父子关系。
- RestrictedActionsDocumentation.lua:45–53：InCombatLockdown 返回 bool；保留原有战斗短路和脱战清理。

## 验证证据与限制

- 新增 ui.search_publication：真实 Provider→Query→Session→Palette，覆盖同步/异步混合、等待空态、部分增长、最终收缩、旧回复、筛选、来源刷新、关闭、别名解析中的初次/异步重入。
- 新增 ui.home_lifecycle：通过首页准备/失效/释放，验证 12 个固定项、暂不可用占位、一次恢复、旧按下拒绝、正常点击、池复用、战斗与重开。
- search_lifecycle_regression 增加 Filter/Invalidate 的取消重入；修复前两项重入回归均失败，修复后通过。search_session_smoke 的 pending 测试改用真实延迟 Provider，不再替换 HasPendingQuery。
- 原 ui.interaction_smoke、navigation_binding、ui_library_integration 等继续执行；没有删除几何、性能或交互断言。关闭测试不再断言已被移除的 Palette.homeDirty，新增生命周期回归从关闭→重开验证恢复。
- 基线不含 LDT：99 文件、23 ms、3514.8 KiB 累计分配、1471.3 KiB 回收后保留；完整：104 文件、27 ms、4259.1 KiB 分配、1847.0 KiB 保留。基线首页循环曾达到 5.000 ms，触及严格 <5 ms 门槛，失败原文保留；不提高阈值。
- 初步重构因重复辅助代码未通过不含 LDT 的加载预算；删除残留后，含重入修复为 100 文件、22 ms、3523.2 KiB 分配、1473.3 KiB 保留、2 Frame/4 事件。数字是固定离线场景的单次观测，不能宣称整体性能改善。
- 完整入口执行 91 项：90 项通过，唯一失败是新增结构检查误将 MarkHomeDirty 方法名当作旧字段；修正为精确字段匹配后单独复核 contracts.architecture 通过。未修改运行代码或降低门槛来消除此误报，最终 91 项均已取得通过证据，不将两次执行伪称一次全量绿色运行。
- 完整轮次包含 Lua/XML/Python 静态检查、四客户端×双语言真实 TOC、原始公开 SDK、行为/存储/发布合同及全部性能场景。最终不含 LDT：20 ms、1473.3 KiB；完整五包：25 ms、1849.1 KiB，均为 2 Frame/4 事件。相比基线回收后约增加 2 KiB，不宣称内存优化。完整轮次首页 100 次循环峰值 4 ms、无新增 Frame；较早 5.000 ms 的失败保留在原始记录中。
- wowdoc validate 固定到上述 commit，checkedLua=44、valid=true、diagnostics=null。git diff --check 通过。
- 新增 HomeView TOC 文件需重新加载文件清单；按项目要求完全重启客户端。实际字体、鼠标顺序、战斗/taint、真实帧时间与五包整体内存尚未进行新的实机验收。

原始记录见 [全部执行与失败证据](2026-09-13-query-home-depth-checks.json)。先完成检查与提交，再按发布清单同步五包，保留目标额外旧文件；实际提交与同步清单记录于本轮交付结果。回滚用新的 git revert。
