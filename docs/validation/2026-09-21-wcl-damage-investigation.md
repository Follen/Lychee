# 首段伤害与 WCL 对照调查

日期：2026-09-21。运行代码基线 a6374ebd8019b8c36fb8c29b09d5d82dff006c01（0.3.34）。本轮只调查，无运行代码或媒体修改，无发布。用户明确不考虑技能叠加；只对照单次直接命中，周期伤害与额外增减伤变体不作为基础基准。

## 结论

1. **已复现基础伤害系统性低估。** `Survival.lua` 的 `Multiplier` 仅为显示赛季 34 使用 1.8945719251，其余赛季使用 1。当前客户端显示赛季 37。诸王之眠样本需要额外基础修正约 3.1436053；缺少该项使基础值低估约 68.2%。
2. **层数表不是本次主因。** 实机 `C_ChallengeMode.GetPowerLevelDamageHealthMod` 对 10、15、20 层返回 84%、196%、377%，与代码中的 1.84、2.96、4.77 一致。实机 Exwind 当前同样返回首领 2.116、小怪 2.208（10 层），所以复用上游算法不能保证当前赛季准确。
3. **描述解析不能可靠区分首段与 DOT。** `GetSpellDescription(270292)` 和 `270293` 返回同一段混合说明，但 DB2 与 WCL 明确区分周期伤害和直接命中。当前计算器把二者都解析为同一个首段伤害。吐金也存在相同问题：265773 是周期伤害，1306736 是标记/施法相关效果，实际直接伤害事件为 1312104。
4. **基础修正并不等于最终承伤全部校准。** 物理护甲、每个职业的被动覆盖、范围判定仍需要独立验证；不能把 WCL 别的角色的最终承伤直接当作本角色应承伤。

## 实机证据

客户端 Retail 12.1.0.69875 / Interface 120100 / zhCN，灵止光—死亡之翼，90 级、神圣圣骑士（65），显示赛季 37。生命 827280，护甲 4201，全能增伤 10.740740776062%，全能减伤 5.370370388031%，闪避范围伤害属性 6.2770843505859%；本次模拟未勾选额外效果，active 为空。客户端读取被动 385427、402964 各 2 级。

- 页面采样 Ticket `LYCHEE-20260921-080031-0092`，request `wcl-20260921-sample1`，revision 1。六个技能、每个 10/15/20 层，共 18 组实际页面结果。完整报告 16414 字节，SHA-256 `9a13982cb9bf0a3db5f84a60ff4b4750d67cb2d9c530459a602a144d9647739f`。
- 缩放采样 Ticket `LYCHEE-20260921-080544-0093`，request `wcl-20260921-scaling1`，revision 1。完整报告 2092 字节，SHA-256 `f07f337f87484ee7f70e7aba4bac20d8687dd23d0d53e399440d70c0adf6a968`。
- 两份完整 payload 位于 `%LOCALAPPDATA%/LycheeDev/automation/received/<Ticket>/content.json`。身份、完成状态与无截断均已核对；ACK received 成功、自有任务块已删除，页面已关闭。没有留下持续探针。

## WCL 样本与筛选

公开 API v2，Midnight Mythic+ Season 2（zone 55）、Kings' Rest（encounter 61762）。每档两份独立报告：

| 层数 | 报告 A | 报告 B |
| --- | --- | --- |
| 10 | [kBhtR7KWwDTxaZfJ / 7](https://www.warcraftlogs.com/reports/kBhtR7KWwDTxaZfJ?fight=7&type=damage-taken) | [mcQrX8CD7gT6Ah4x / 2](https://www.warcraftlogs.com/reports/mcQrX8CD7gT6Ah4x?fight=2&type=damage-taken) |
| 15 | [HTxLRMPcN3v7t84F / 3](https://www.warcraftlogs.com/reports/HTxLRMPcN3v7t84F?fight=3&type=damage-taken) | [LFnmQG96vW8MA7q1 / 1](https://www.warcraftlogs.com/reports/LFnmQG96vW8MA7q1?fight=1&type=damage-taken) |
| 20 | [Pzr7F3BmhXw2ZHd6 / 33](https://www.warcraftlogs.com/reports/Pzr7F3BmhXw2ZHd6?fight=33&type=damage-taken) | [hgJTGjK9zBHyCx2W / 23](https://www.warcraftlogs.com/reports/hgJTGjK9zBHyCx2W?fight=23&type=damage-taken) |

核对 fight.keystoneLevel，不把 rankings 的 bracket 参数当作层数。对照 `unmitigatedAmount` 与计算器 `rawFirst`，排除 tick 和额外增减伤的数值簇。各技能筛选查询 `nextPageTimestamp=null`，未截断。具体事件、基准簇命中数与误差存于忽略目录 `analyze/wcl-comparison/comparison.json`。基准簇通过跨报告复现与下述 DB2 重建共同识别，不把每个事件都称为完全无修正样本。

WCL 的 unmitigatedAmount 并非所有来源修正都已剥离。例如 20 层吐金出现 455814 与 478796 两簇；首领在前者前存在萎缩药膏，数值比约 0.952。此类差异只用于识别并排除变体，不引入产品叠加模型。未逐事件完成全量光环重放；调查中的减益查询有一页未翻页，不用它证明整场光环覆盖完整。

## 基础值对照

以下全部是减伤、吸收前的首段数值。候选值由真实 `Survival.lua` 计算，仅在调查脚本覆写 multiplier 返回值乘 3.1436053，未修改运行代码。

| 技能 | 层数 | 当前 rawFirst | WCL 基准 | 单变量候选 |
| --- | ---: | ---: | ---: | ---: |
| 净化打击 270293 | 10 | 122611 | 385446 | 385442 |
| 净化打击 270293 | 15 | 197244 | 620065 | 620059 |
| 净化打击 270293 | 20 | 317857 | 999227 | 999217 |
| 重力猛击 1310755 | 10 | 17029 | 53535 | 53533 |
| 重力猛击 1310755 | 15 | 27395 | 86121 | 86119 |
| 重力猛击 1310755 | 20 | 44146 | 138784 | 138780 |
| 吐金直接命中 1312104 | 10 | 58752 | 184692 | 184694 |
| 吐金直接命中 1312104 | 15 | 94514 | 297114 | 297116 |
| 吐金直接命中 1312104 | 20 | 152309 | 478796 | 478799 |

9/9 候选误差 <0.01%；当前值全部不足日志基准的 33%。可复算命令：`python analyze/wcl-comparison/compare.py`（依赖上述本地完整 Ticket 与保存的 JSON）。脚本调用 Lua 5.1 加载生产计算模块，验证原始缺陷仍可复现及单变量候选吻合；这不是修复后的生产测试。

## 系数来源和定位

本地 CASC，product wow，region cn，locale zhCN，固定 Build 12.1.0.69875：

- `ExpectedStat` ID 475：Lvl 90，ExpansionID -2，CreatureSpellDamage 308506.66。技能说明 61495 除以本角色全能增伤后约 55531，匹配其 18%。因此当前说明基数与玩家全能剥离链在此样本成立，不是直接拿 61495 当 WCL 命中值。
- `SpellEffect`：270293 / ID719143，Effect 2、base 18；1310755 / ID1340567，Effect 2、base 2.5；1312104 / ID1342791，Effect 2、base 9。所取效果 DifficultyID 均为 0，没有证据支持本次是选错一个不同 DifficultyID 数值。
- `ContentTuningXExpected`：ContentTuningID 1279 的 ID1078 对应 ExpectedStatMod 280（MinSeason100，无上限）；ID3272 对应 448（MinSeason120，无上限）。后续同内容的 424、473、474、476 只改变生命，伤害系数为 1。
- `ExpectedStatMod` 280 的 CreatureSpellDamageMod=1.9393，448=1.621。乘积 **3.1436053**。
- 以 `308506.66 × 18% × 3.1436053 × 1.84 × 1.2` 重建 10 层净化打击，得到 385446.52，WCL 385446；同样公式分别换为 2.5%（小怪）及 9%、1.15（首领），重建其他技能与层数。
- DisplaySeason 37 明确写“至暗之夜第2赛季”；MythicPlusSeason 120 为内部记录，不能将显示 ID 与内部 ID 混用。ContentTuning1279 到具体怪物的完整服务端选择链没有直接暴露在此次静态查询中。**系数对所测诸王之眠首段已验证，不据此声称八个副本及全部技能都已验证。**

静态工具部分条件查询漏行：MapDifficulty 的关系条件未返回1762，完整 stream 能找到 ID3822/4136/4433/5809。以完整行数据为准。个别 PowerShell 逗号参数错误已修正，不作为证据。运行中的 DBCache 临时文件被锁；已保存缓存未找到相关 hotfix，不能据此断言服务器没有热修正。ExpectedStatMod348的3.143仅数值相近，无当前关联，已排除。

## 首段与周期映射

| 页面/说明 ID | 数据与日志事实 | 现有问题 |
| --- | --- | --- |
| 270293 净化打击 | Effect2 直接伤害 | 可作为首段基准 |
| 270292 净化烈焰 | Effect6/Aura3，周期1000ms，base15；WCL tick=true | 共用说明被解析成270293的首段 |
| 1306736 吐金 | Effect6/Aura4 标记类效果，无直接伤害 | 需明确关联1312104，而不是假定自身造成伤害 |
| 265773 吐金 | Effect6/Aura3，周期2000ms，base8；WCL tick=true | 共用说明被解析成直接命中 |
| 1312104 吐金 | Effect2，base9；WCL直接伤害 | 应作为对应首段证据 |

仍遵守用户“只算首段，不考虑 DOT”：应靠效果/映射确定有效首段，不能因为说明含有直接伤害就为每个关联 ID 都输出同一安全结论。

## 对页面结论的影响与后续修复边界

保持当前自身属性与减伤规则不变，仅替换基础倍率：10层净化打击101262→318328，重力猛击6321→19872，吐金48522→152535。20层甩尾265910从467878、可承受变为约1470823、会致死；该物理技能有5%伤害浮动，例子是候选模型中心值，不是本角色实战命中实测。15层也由290339变为912712、会致死。

物理护甲独立风险：实机当前4201护甲对应armorDR=0.5505176，吻合基础 ArmorConstant3430；ExpectedStatMod448还含ArmorConstantMod1.321。尚未验证副本内API与完整难度常数链，不得把以上物理候选值称为最终精确承伤。魔法/物理类型应继续由可靠法术元数据识别，范围属性不能只依赖“所有/范围/附近”等文字。

建议修复顺序：先补经验证的版本/内容基础修正及未知版本保护，再建立首段伤害ID映射；层数表保持或改为读取已验证接口；最后独立验证护甲和范围减伤。不新增DOT、技能叠加或光环时间线模型。当前只完成调查，未改插件、未同步、未发布；暂无需要重跑的运行代码回归。

## API 证据

sourceId wow-ui-source，product retail，requestedRef/matchedTag 12.1.0，resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/ChallengeModeInfoDocumentation.lua:194–207`：GetPowerLevelDamageHealthMod(powerLevel) 返回 damageMod、healthMod；实际返回单位已用客户端采样核对。已有源码版本检查通过。

WCL OAuth 凭证只从用户指定 `.env` 读取到进程内存，未输出、复制或写入证据。原始 WCL/DB2 JSON、比较脚本及临时探针均位于忽略的 `analyze/wcl-comparison`，不进入运行包。
