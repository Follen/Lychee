# 0.4.3 搜索容量、传送别名与赞赏移除

## 目标与改动

默认 Host 搜索由 20 增至 30，静态索引及 Boss/LDT/Slash 动态来源遵从该上限；显式 20 条请求仍保留。八个赛季传送按固定技能 ID 添加副本短名、全名、前后“传送”组合及英文名称；仍只索引角色已学会技能，不改安全动作。中文微信赞赏、英文 PayPal、专用图标及码图移除，保留 GitHub、中文作者微信与英文 X；底栏两按钮宽 64。SDK/API 版本不变。实机最终合并曾将裸虚痕、纳洛、密谋、神庙、诸王的传送挤出30条：LDT至少30条别名与传送同为.98，但玩家技能分类order=10，资料order=0。统一玩家技能分类为order=-1，使全部玩家技能在同等匹配/用户偏好时先于资料；更强匹配、固定与记忆仍优先，不写核心特殊ID或扩展协议。

## 直接证据

正式服 12.1.0.69933，角色灵止光／死亡之翼，客户端 PID 88944。改前已确认八个传送已学会：1286801 夺目谷、1286804 虚空之痕竞技场、1286807 纳洛拉克的洞穴、1286809 密谋小径（客户端说明为谋杀小径）、1286812 毒牙祭坛、393256 红玉新生法池、1286828 塞塔里斯神庙、1286831 诸王之眠。改前可见全局“毒牙”20条挤出传送，“传送毒牙”为空，“传送 毒牙”可命中；本轮过滤技能来源的基线：毒牙1、两种连写0、传送20。基线 request `aliases-before-043-fixed`；原 `aliases-before-043` 因错误读取包装字段失败，不计通过。

## API 与来源

sourceId `wow-ui-source`；product `retail`；requestedRef `refs/tags/12.1.0`；resolvedCommit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`；snapshot `PIN-86f3a38c315f34ce64b6408f03bb771e42db9379738e312e9417a48ad032a49f`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:683–698`：`IsSpellKnown` 接受 spellID 与默认为 Player 的 spellBank，返回 isKnown；支持技能书未显示的已知技能。capture `CAP-46268a1727233e8487c355ef15c3de6736df912b0e6a16f1d649bacbdf34f3ee`。
- 社交布局现有 Frame.SetPoint：`Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua:468–499`，497 调用 `Frame.SetPoint`。capture `CAP-ce55845873420d58faadff137dfac2856b082aa64d3d738a7bc40c5648e62267`。本次无新增游戏 API。
- 新版 lycheedev 无旧 `source check` 命令；采用 source list、固定 source sync、精确 inspect。递归 source validate 的 staticValid=true，complete=false，169 resolved / 10903 unresolved，包含项目动态方法；不将其视作类型、战斗、taint或运行时证明。

## 离线验证

新增异步合并回归先在旧顺序复现失败，再覆盖31个.98动态资料与同分传送竞争、固定/记忆资料优先、1.0标题优于.98技能别名、普通技能同分提前与安全身份不变。集成测试覆盖八个传送的短名、全名、连写与空格组合、英文别名、zhCN/zhTW/enUS/enGB回退、安全动作身份、未学会技能不可合成。排名及参数偏好覆盖默认30、超大请求截断30及动态请求limit30；文档来源物化只读取入选30项。LDT旧44个结果快照显式使用20并保持原参照，额外足量技能查询返回30；Slash默认30和显式20/30均与1000项完整枚举排序参照核对。社交四语言覆盖两个入口、焦点、Esc、关闭清理、复用、战斗和关闭重开。

Lua全量解析、Bindings XML、TOC/SDK生成一致性、发布清单及文档链接检查通过。初版提交0a2ca13在普通调度下完整契约通过。最终排序修正在仅Lua测试子进程使用High调度的隔离入口下完整契约通过（仍调用`pwsh -NoProfile -File tests/check_contract.ps1`，exit 0）；原CPU/容量/生命周期门槛未修改。此环境条件与普通调度结果分开报告。

## 性能与成本

固定1000条普通记录加已声明别名技能的静态索引目录（旧1003／新1010）、48轮相同查询，旧20+旧别名对新30+新别名：回收后目录保留1544.2→1562.3 KiB；查询累计分配1554.7→1712.8 KiB；累计离线计时52→58 ms（本机os.clock包含等待），单次最大3→4 ms。约18.1 KiB是该静态索引样本的保留增量；测量前已加载别名源表，不含别名源表加载、Host结果物化及UI，也不是插件总常驻增量。计时为Windows Lua5.1离线样本，不宣称提速或客户端帧时间通过。现有index_benchmark显式20条，仅用于原口径回归；normalization/performance_search指标及取消检查通过，硬CPU门槛未调整。完整契约一轮在并行源码分析期间报模拟30FPS 1200 ms（要求<1000）；随后隔离对照主分支与新分支均800 ms，不据此确诊根因或放宽断言，另一次普通调度在Slash Forever/enUS回调门槛失败，隔离新30条样本3/3/4ms、旧20条2/2ms；再次普通调度加载失败，单独最终树51/57ms、主分支也失败。3组ABBA（旧0a2ca13固定快照A／最终树B，不同读取路径）A为32/38/36/45/35/40ms、B为39/50/48/43/39/45ms，A0/6失败、B2/6失败；宿主整进程CPU按15.625ms粒度记录，不能精确替代加载区间。Windows本机Lua5.1的os.clock包含等待，不是纯CPU；类别常量不在Slash装配路径，加载也不执行BuildSearchRecords，尚不能确诊稳定代码退化。最终全量在仅Lua子进程High调度下通过，普通调度稳定性及真实客户端性能仍待验收。原始失败、ABBA和受控通过日志均保留。

## 实机覆盖矩阵

| 流程 | 断言 | 状态 |
| --- | --- | --- |
| 八个副本短名与全名 | 已学会传送进入真实搜索列表 | zhCN retail 16项全部通过 |
| 毒牙两种连写与空格 | 命中1286812；安全动作身份另由契约检查 | 实机3项均为1条传送结果；未实际施放 |
| 通用传送 | 列表30条且包含八个目的地，第30条可达 | 通过；8行复用，尾部offset=22，回顶部offset=0 |
| 输入替换、关闭重开 | 替换旧输入后查询正确，可关闭并重新查询 | 通过；重开“传送毒牙”仍命中 |
| 联系浮窗 | 两入口、无赞赏、关闭清理 | 通过；GitHub与作者微信，宽64，关闭后active清空、backdrop隐藏 |
| 跨语言和客户端 | 四语言离线及五产品TOC；实机仅zhCN retail | 其他实机待验收 |
| 真鼠标施放、战斗/taint、失败重试 | 不误报离线为实机 | 待验收 |
| 搜索慢/快来源、IME、6→1回缩、首页冷恢复与搜索开关 | 本次仅固定数据/容量改动，未完整实机覆盖 | 待验收 |
| 客户端性能 | 战斗、团本、姓名板等完整性能矩阵 | 待验收 |

## 实机结果与交付

运行提交 `4291dc2020bd3ca4e46d0b4d9b7b514a48810478` 已覆盖同步至正式服同名Lychee目录，200个发布运行文件的SHA-256全部一致，随后reload成功。最终Ticket `LMO-8ebd14cbec07c5e3c11f82c0b6450ed3`，request `aliases-ranking-acceptance-043`：20项可见搜索全部命中对应传送，没有缺失目的地；report.ok=true、resourcesReleased=true、cleanup=complete。首次等待回执超时，使用原CON的live resume取回同一操作的报告，未重复执行探针。查询使用真实Palette输入变更路径，未执行传送施放。

本地证据位于主项目 `.lycheedev/acceptance-043/`：`delivery-final.json`、`reload-final.json`、`live-final.json`、`resume-final.json`；截图 `WoWScrnShot_100226_171311.jpg`（毒牙30条且传送可见）、`171314.jpg`（传送毒牙单项）、`171403.jpg`（八个赛季传送在首屏）、`171404.jpg`（关闭重开）。探针轮询记录的查询完成时间包含等待和采样，不代表CPU或Blizzard API耗时；Lua VM与暴雪接口瓶颈尚未实机剖析。

TOC本次仅版本元数据变化，加载文件与顺序不变。内容已通过reload验收；按项目规则完整客户端重启及元数据版本刷新仍待验收。游戏目录默认保留三个旧赞赏素材文件，代码已无可达入口，不自动删除目标旧文件。
