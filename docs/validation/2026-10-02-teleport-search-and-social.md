# 0.4.3 搜索容量、传送别名与赞赏移除

## 目标与改动

默认 Host 搜索由 20 增至 30，静态索引及 Boss/LDT/Slash 动态来源遵从该上限；显式 20 条请求仍保留。八个赛季传送按固定技能 ID 添加副本短名、全名、前后“传送”组合及英文名称；仍只索引角色已学会技能，不改安全动作。中文微信赞赏、英文 PayPal、专用图标及码图移除，保留 GitHub、中文作者微信与英文 X；底栏两按钮宽 64。SDK/API 版本不变。

## 直接证据

正式服 12.1.0.69933，角色灵止光／死亡之翼，客户端 PID 88944。改前已确认八个传送已学会：1286801 夺目谷、1286804 虚空之痕竞技场、1286807 纳洛拉克的洞穴、1286809 密谋小径（客户端说明为谋杀小径）、1286812 毒牙祭坛、393256 红玉新生法池、1286828 塞塔里斯神庙、1286831 诸王之眠。改前可见全局“毒牙”20条挤出传送，“传送毒牙”为空，“传送 毒牙”可命中；本轮过滤技能来源的基线：毒牙1、两种连写0、传送20。基线 request `aliases-before-043-fixed`；原 `aliases-before-043` 因错误读取包装字段失败，不计通过。

## API 与来源

sourceId `wow-ui-source`；product `retail`；requestedRef `refs/tags/12.1.0`；resolvedCommit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`；snapshot `PIN-86f3a38c315f34ce64b6408f03bb771e42db9379738e312e9417a48ad032a49f`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:683–698`：`IsSpellKnown` 接受 spellID 与默认为 Player 的 spellBank，返回 isKnown；支持技能书未显示的已知技能。capture `CAP-46268a1727233e8487c355ef15c3de6736df912b0e6a16f1d649bacbdf34f3ee`。
- 社交布局现有 Frame.SetPoint：`Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua:468–499`，497 调用 `Frame.SetPoint`。capture `CAP-ce55845873420d58faadff137dfac2856b082aa64d3d738a7bc40c5648e62267`。本次无新增游戏 API。
- 新版 lycheedev 无旧 `source check` 命令；采用 source list、固定 source sync、精确 inspect。递归 source validate 的 staticValid=true，complete=false，169 resolved / 10903 unresolved，包含项目动态方法；不将其视作类型、战斗、taint或运行时证明。

## 离线验证

集成测试覆盖八个传送的短名、全名、连写与空格组合、英文别名、zhCN/zhTW/enUS/enGB回退、安全动作身份、未学会技能不可合成。排名及参数偏好覆盖默认30、超大请求截断30及动态请求limit30；文档来源物化只读取入选30项。LDT旧44个结果快照显式使用20并保持原参照，额外足量技能查询返回30；Slash默认30和显式20/30均与1000项完整枚举排序参照核对。社交四语言覆盖两个入口、焦点、Esc、关闭清理、复用、战斗和关闭重开。

Lua全量解析、Bindings XML、TOC/SDK生成一致性、发布清单及文档链接检查通过。最终完整契约单独运行通过（`pwsh -NoProfile -File tests/check_contract.ps1`，exit 0），包含现有CPU/容量/生命周期门槛。

## 性能与成本

固定1000条普通记录加已声明别名技能的静态索引目录（旧1003／新1010）、48轮相同查询，旧20+旧别名对新30+新别名：回收后目录保留1544.2→1562.3 KiB；查询累计分配1554.7→1712.8 KiB；累计CPU52→58 ms，单次最大3→4 ms。约18.1 KiB是该静态索引样本的保留增量；测量前已加载别名源表，不含别名源表加载、Host结果物化及UI，也不是插件总常驻增量。计时为Windows Lua5.1离线样本，不宣称提速或客户端帧时间通过。现有index_benchmark显式20条，仅用于原口径回归；normalization/performance_search指标及取消检查通过，硬CPU门槛未调整。完整契约一轮在并行源码分析期间报模拟30FPS 1200 ms（要求<1000）；随后隔离对照主分支与新分支均800 ms，不据此确诊根因或放宽断言，最终完整契约单独执行。

## 实机覆盖矩阵

| 流程 | 断言 | 状态 |
| --- | --- | --- |
| 八个副本短名 | 已学会传送进入真实搜索列表 | 待安装后验证 |
| 毒牙两种连写与空格 | 保留技能 ID 和安全动作 | 待安装后验证 |
| 通用传送 | 列表30条且包含八个目的地 | 待安装后验证 |
| 快速换词、关闭重开 | 旧结果不回流，可重新查询 | 待安装后验证 |
| 联系浮窗 | 两入口、无赞赏、关闭清理 | 待安装后验证 |
| 跨语言和客户端 | 四语言离线及五产品TOC；实机仅zhCN retail | 其他实机待验收 |
| 真鼠标施放、战斗/taint、失败重试 | 不误报离线为实机 | 待验收 |
| 搜索慢/快来源、IME、6→1回缩、首页冷恢复与搜索开关 | 本次仅固定数据/容量改动，未完整实机覆盖 | 待验收 |
| 客户端性能 | 战斗、团本、姓名板等完整性能矩阵 | 待验收 |

TOC本次仅版本元数据变化，加载文件与顺序不变。内容可通过reload验收；按项目规则完整客户端重启及元数据版本刷新仍待验收。游戏目录默认保留三个旧赞赏素材文件，代码已无可达入口，不自动删除目标旧文件。
