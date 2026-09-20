# 0.3.17 大米生存计算：离线验证

分支 `codex/ldt-survival-calculator`，基线 `f8e3e38b6b65c4f9ec0fc9c07e00c0b9f72f6bcf`。用户指定本次不使用lychee-dev、不操作客户端。实机功能、视觉与性能均未验证，无新Ticket。

## 实现及边界

- 正式服独立计算模块与Provider内页面，不访问EXDB/EXMD，不要求安装上游插件，不打包网站源码或Python。
- 层数0–35的35项倍率；赛季34系数1.8945719251；10层起首领1.15、小怪1.2。技能说明明确伤害条款才提取，剥离说明中的自身全能增伤后应用倍率。显式伤害解析不沿用上游文本替换器10000的启发式阈值。
- 首段、每跳、跳数分开；复杂/未知说明手动校正。当前角色满血、全能、护甲、Avoidance来自客户端；物理按护甲，流血绕过护甲，范围减伤与其余减伤相乘，最后扣吸收。先判断首段致死，持续需治疗另列。
- 30项外部效果与19项常驻规则。已学技能、职业/专精和有效天赋等级过滤，宠物条件必须满足；不把上游默认开启视为本角色已生效。常驻规则是明确覆盖范围，不声称覆盖全部职业机制。位置、敌方减伤等无法确认的条件不自动计入。生命/护甲/全能被动已含在有效属性，不重复加。
- 按用户指定简化：时间膨胀按50%即时减伤，不补延后伤害；吸收根据自身模拟生命/全能估算满盾，不读取施法者、不跟踪剩余盾/到期。生命/耐力增益沿参考网站比例估算；已存在属性增益不重复叠加。不模拟治疗，完整承伤仅为参考。

## 成本、预算与离线结果

当前技能/角色快照由页面独占，关闭释放，不写SV、不建全量技能缓存。说明8192字节；天赋4树/512节点；最多1000跳。无新增常驻事件/timer/OnUpdate，计算复用输出。UI首次创建，3个编辑框/10个复用选项行/1个滚动视口；关闭保留引擎控件而不是声称销毁。预算见 PERFORMANCE.md 第21节。

- 完整契约PASS；原大米查询、技能组、模型、链接、取消/禁用及语言契约通过。
- 独立公式测试覆盖首段致死/持续需治疗、时间膨胀、魔法盾、护甲/流血、属性Buff去重、专精差异、天赋等级、secret/战斗/未知输入/容量。
- 1000次六跳计算12–13ms，临时分配0.00KiB，GC后保留0.00KiB。只代表Lua5.1离线复用计算，不含属性读取。
- 页面50次开关预热后零新控件；GC后-1.26KiB，解释为未观察到保留增长。按下→换组→松开不触发旧绑定；正常点击、编辑确认、迟到资料不覆盖手动输入通过。
- LDT模块369.5→430.8KiB，约61.3KiB新增代码与有限规则，接受为独立计算/交互所需成本。20次查询约1210KiB分配、保留0KiB，回调峰值4ms。完整加载33ms，基础2Frame/4事件不变。
- Lua/XML/TOC、wowdoc Mainline静态validate、发布清单及diff检查通过。纹理/引擎真实成本、实机点击与字体未测，不能由替身结果推断。

原始本地输出：analyze/survival/contracts.txt、wowdoc-validation.json。版本0.3.17增加TOC模块，需要重启客户端；本次不自动重启/reload。

## 算法证据

数值依据[Not Even Close配置](https://github.com/acornellier/not_even_close/tree/master/src/backend/groupAbilities)及classAbilities，2026-09-20读取。运行时仅自有实现与必要数值，不调用网站。层数和修正依据本机ExwindTools 1.0（Interface120100）及ExwindCore共享数据；EXBoss也使用同一倍率。源文件SHA-256：

- `ExwindTools/Modules/NODISPLAY/ExM+.MythicDamage.lua`: `d1670403f62ec54d9498a389b18ffd95d363d76363d30beee57bc51aaf4dfe27`
- `ExwindCore/Core/ExwindDB.lua`: `205c56276640529a09c257d2fd49f1a3e6cd067c34ebd4a0c8b7bc704b86eba9`

## WoW接口证据

sourceId `wow-ui-source`，product `retail`，requestedRef/matchedTag `12.1.0`，resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。修改前source check确认来源可用。对应PaperDollFrame.lua:1283–1284分别读取全能增伤与减伤；同文件1267调用GetAvoidance。PaperDollInfoDocumentation.lua:47的GetArmorEffectiveness参数为armor、attackerLevel；UnitAuraDocumentation.lua:375的GetPlayerAuraBySpellID注明RequiresNonSecretAura；SpellBookDocumentation.lua:684的IsSpellKnown接受spellID。这些均由修改前inspect/query取得。

### C_Traits.GetConfigInfo

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:201`

```text
201: 			Name = "GetConfigInfo",
202: 			Type = "Function",
203: 			MayReturnNothing = true,
204: 			SecretArguments = "AllowedWhenUntainted",
205:
206: 			Arguments =
207: 			{
208: 				{ Name = "configID", Type = "number", Nilable = false },
209: 			},
210:
211: 			Returns =
212: 			{
213: 				{ Name = "configInfo", Type = "TraitConfigInfo", Nilable = false },
214: 			},
215: 		},
```

### C_Traits.GetTreeNodes

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:523`

```text
523: 			Name = "GetTreeNodes",
524: 			Type = "Function",
525: 			MayReturnNothing = true,
526: 			SecretArguments = "AllowedWhenUntainted",
527: 			Documentation = { "Returns a list of nodeIDs, sorted ascending, for a given treeID. Contains nodes for all class specializations." },
528:
529: 			Arguments =
530: 			{
531: 				{ Name = "treeID", Type = "number", Nilable = false },
532: 			},
533:
534: 			Returns =
535: 			{
536: 				{ Name = "nodeIDs", Type = "table", InnerType = "number", Nilable = false },
537: 			},
538: 		},
```

### C_Traits.GetEntryInfo

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:264`

```text
264: 			Name = "GetEntryInfo",
265: 			Type = "Function",
266: 			MayReturnNothing = true,
267: 			SecretArguments = "AllowedWhenUntainted",
268:
269: 			Arguments =
270: 			{
271: 				{ Name = "configID", Type = "number", Nilable = false },
272: 				{ Name = "entryID", Type = "number", Nilable = false },
273: 			},
274:
275: 			Returns =
276: 			{
277: 				{ Name = "entryInfo", Type = "TraitEntryInfo", Nilable = false },
278: 			},
279: 		},
```

### C_Traits.GetDefinitionInfo

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua:248`

```text
248: 			Name = "GetDefinitionInfo",
249: 			Type = "Function",
250: 			MayReturnNothing = true,
251: 			SecretArguments = "AllowedWhenUntainted",
252:
253: 			Arguments =
254: 			{
255: 				{ Name = "definitionID", Type = "number", Nilable = false },
256: 			},
257:
258: 			Returns =
259: 			{
260: 				{ Name = "definitionInfo", Type = "TraitDefinitionInfo", Nilable = false },
261: 			},
262: 		},
```

### Unit.UnitHealthMax

`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1398`

```text
1398: 			Name = "UnitHealthMax",
1399: 			Type = "Function",
1400: 			SecretWhenUnitHealthMaxRestricted = true,
1401: 			SecretArguments = "AllowedWhenUntainted",
1402:
1403: 			Arguments =
1404: 			{
1405: 				{ Name = "unit", Type = "UnitTokenPvPRestrictedForAddOns", Nilable = false },
1406: 			},
1407:
1408: 			Returns =
1409: 			{
1410: 				{ Name = "result", Type = "number", Nilable = false },
1411: 			},
1412: 		},
```

### Unit.UnitStat

`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:3088`

```text
3088: 			Name = "UnitStat",
3089: 			Type = "Function",
3090: 			SecretWhenUnitStatsRestricted = true,
3091: 			SecretArguments = "AllowedWhenUntainted",
3092:
3093: 			Arguments =
3094: 			{
3095: 				{ Name = "unit", Type = "UnitToken", Nilable = false },
3096: 				{ Name = "index", Type = "luaIndex", Nilable = false },
3097: 			},
3098:
3099: 			Returns =
3100: 			{
3101: 				{ Name = "currentStat", Type = "number", Nilable = false },
3102: 				{ Name = "effectiveStat", Type = "number", Nilable = false },
3103: 				{ Name = "statPositiveBuff", Type = "number", Nilable = false },
3104: 				{ Name = "statNegativeBuff", Type = "number", Nilable = false },
3105: 			},
3106: 		},
```

### Unit.UnitClass

`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:900`

```text
900: 			Name = "UnitClass",
901: 			Type = "Function",
902: 			MayReturnNothing = true,
903: 			SecretWhenUnitIdentityRestricted = true,
904: 			SecretArguments = "AllowedWhenUntainted",
905:
906: 			Arguments =
907: 			{
908: 				{ Name = "unit", Type = "UnitToken", Nilable = false },
909: 			},
910:
911: 			Returns =
912: 			{
913: 				{ Name = "className", Type = "cstring", Nilable = false, ConditionalSecret = true },
914: 				{ Name = "classFilename", Type = "cstring", Nilable = false },
915: 				{ Name = "classID", Type = "number", Nilable = false },
916: 			},
917: 		},
```

### Unit.UnitExists

`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1164`

```text
1164: 			Name = "UnitExists",
1165: 			Type = "Function",
1166: 			SecretArguments = "AllowedWhenUntainted",
1167:
1168: 			Arguments =
1169: 			{
1170: 				{ Name = "unit", Type = "UnitToken", Nilable = true },
1171: 			},
1172:
1173: 			Returns =
1174: 			{
1175: 				{ Name = "result", Type = "bool", Nilable = false },
1176: 			},
1177: 		},
```

### Unit.UnitIsDead

`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1842`

```text
1842: 			Name = "UnitIsDead",
1843: 			Type = "Function",
1844: 			SecretArguments = "AllowedWhenUntainted",
1845:
1846: 			Arguments =
1847: 			{
1848: 				{ Name = "unit", Type = "UnitToken", Nilable = false },
1849: 			},
1850:
1851: 			Returns =
1852: 			{
1853: 				{ Name = "result", Type = "bool", Nilable = false },
1854: 			},
1855: 		},
```

### C_SpecializationInfo.GetSpecialization

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua:213`

```text
213: 			Name = "GetSpecialization",
214: 			Type = "Function",
215: 			SecretArguments = "AllowedWhenUntainted",
216:
217: 			Arguments =
218: 			{
219: 				{ Name = "isInspect", Type = "bool", Nilable = true },
220: 				{ Name = "isPet", Type = "bool", Nilable = true },
221: 				{ Name = "specGroupIndex", Type = "luaIndex", Nilable = true },
222: 			},
223:
224: 			Returns =
225: 			{
226: 				{ Name = "specializationIndex", Type = "luaIndex", Nilable = false },
227: 			},
228: 		},
```

### C_SpecializationInfo.GetSpecializationInfo

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua:230`

```text
230: 			Name = "GetSpecializationInfo",
231: 			Type = "Function",
232: 			SecretArguments = "AllowedWhenUntainted",
233:
234: 			Arguments =
235: 			{
236: 				{ Name = "specializationIndex", Type = "luaIndex", Nilable = false },
237: 				{ Name = "isInspect", Type = "bool", Nilable = false, Default = false },
238: 				{ Name = "isPet", Type = "bool", Nilable = false, Default = false },
239: 				{ Name = "inspectTarget", Type = "string", Nilable = true },
240: 				{ Name = "sex", Type = "number", Nilable = true },
241: 				{ Name = "groupIndex", Type = "luaIndex", Nilable = true },
242: 				{ Name = "classID", Type = "number", Nilable = true },
243: 			},
244:
245: 			Returns =
246: 			{
247: 				{ Name = "specId", Type = "number", Nilable = false, Default = 0 },
248: 				{ Name = "name", Type = "string", Nilable = true },
249: 				{ Name = "description", Type = "string", Nilable = true },
250: 				{ Name = "icon", Type = "fileID", Nilable = true },
251: 				{ Name = "role", Type = "string", Nilable = true },
252: 				{ Name = "primaryStat", Type = "luaIndex", Nilable = true },
253: 				{ Name = "pointsSpent", Type = "number", Nilable = false, Default = 0 },
254: 				{ Name = "background", Type = "string", Nilable = true },
255: 				{ Name = "previewPointsSpent", Type = "number", Nilable = false, Default = 0 },
256: 				{ Name = "isUnlocked", Type = "bool", Nilable = false, Default = true },
257: 			},
258: 		},
```

### C_SeasonInfo.GetCurrentDisplaySeasonID

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SeasonInfoDocumentation.lua:20`

```text
20: 			Name = "GetCurrentDisplaySeasonID",
21: 			Type = "Function",
22:
23: 			Returns =
24: 			{
25: 				{ Name = "seasonID", Type = "number", Nilable = false },
26: 			},
27: 		},
```

### C_Spell.GetSpellDescription

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:304`

```text
304: 			Name = "GetSpellDescription",
305: 			Type = "Function",
306: 			MayReturnNothing = true,
307: 			SecretArguments = "AllowedWhenTainted",
308: 			Documentation = { "Returns nil if spell is not found" },
309:
310: 			Arguments =
311: 			{
312: 				{ Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
313: 			},
314:
315: 			Returns =
316: 			{
317: 				{ Name = "description", Type = "string", Nilable = false, Documentation = { "May be empty if spell's data isn't loaded yet; Listen for SPELL_TEXT_UPDATE event, or use SpellMixin to load asynchronously" } },
318: 			},
319: 		},
```

### FrameScript.issecretvalue

`Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:263`

```text
263: 			Name = "issecretvalue",
264: 			Type = "Function",
265: 			SecureHooksAllowed = false,
266: 			SecretArguments = "AllowedWhenUntainted",
267: 			Documentation = { "Returns true if a supplied value is a secret value." },
268:
269: 			Arguments =
270: 			{
271: 				{ Name = "value", Type = "LuaValueReference", Nilable = false },
272: 			},
273:
274: 			Returns =
275: 			{
276: 				{ Name = "isSecret", Type = "bool", Nilable = false },
277: 			},
278: 		},
```

## 待实机验收

正式服zhCN/enUS正常与小视口：进入、滚动、长名称、模型切回/关闭；真实角色各专精/英雄天赋过滤与刷新；首领/小怪、首段/DoT、10层边界、物理/魔法/流血/AoE；Buff已存在与模拟叠加、吸收耗尽、资料失败/迟到/手动校正；战斗隐藏和脱战不重开；冷/热打开、50次开关、关闭后的Lua堆、纹理/Frame、空闲/战斗活动工作。功能与性能分别给结论。用户方便后再运行lychee-dev，本轮不发送游戏输入。

## 2026-09-20 真实客户端补充验收

用户随后明确调用 lychee-dev，允许操作空闲客户端。运行提交 `860a976`，版本0.3.17；正式服12.1.0.69875 / Interface120100 / zhCN，灵止光—死亡之翼，神圣圣骑士。预检确认两个新模块已经实际加载。此节补充前述离线结果，不表示未测矩阵全部通过。

完整报告保存在 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/<Ticket>/content.json`；同目录 evidence.json 保存校验信息。所有报告完整读取，环境及task/request/revision核对。0071–0074的ACK confirmed/cleared；0075错误报告的ACK已提交但未收到匹配确认（nonce req-20260920-154448-7ebb0a），随后只读capture仍未解出回执，最终ACK及界面收尾未确认，没有重跑任务或重复输出reload。自有 `ldt-survival-live` 磁盘任务块移除，其余任务保留。

| Ticket | 结果 |
| --- | --- |
| LYCHEE-20260920-233611-0071 | 预检通过：实际属性有效，生命829360、全能减伤5.37037%、范围减伤6.27708%、专精65、赛季37；当前天赋过滤有效。 |
| LYCHEE-20260920-233915-0072 | 同步矩阵17断言14通过，3编辑断言失败；保留原报告。真实Host挂载、外援/盾、分页、过期按压、释放和重开通过。立即SetText后检查早于原生事件，不作为编辑功能结论。 |
| LYCHEE-20260920-234107-0073 | 跨帧探针失败：主面板Show后立即OpenView，延后的输入初始化切走页面，v未建立；属于探针导航时序失败，未改生产代码。 |
| LYCHEE-20260920-234250-0074 | 按主面板就绪→资料页→计算页→编辑→下一帧确认的正常顺序，4断言全部通过：编辑框可见、数值更新、确认出结果、迟到数据不覆盖手动值。实际244750说明提取119574点暗影首段伤害，无DoT。 |
| LYCHEE-20260920-234337-0075 | 最近10条错误完整读取；provider_storage_reverse，当前session656，样本最新错误早于预检；未观察到本轮新增错误。存在历史Lychee SetTab保护调用记录，不据此声称全插件没有历史问题。 |

实际交互为脚本驱动原生控件/回调，不是硬件鼠标验收。说明读取成功是实际技能数据证据；600000首段/120000每跳/6跳为人工回放参数，不是实际伤害战斗日志。

性能（同一矩阵，无全局hook、无暂停GC）：

- 属性快照3.942ms；首次观察到的资料挂载3.165ms；计算页首开6.138ms。
- 1000次六跳复用计算22.733ms，平均0.0227ms；自然GC下该区间堆差0KiB，不等同于暂停GC测得的累计分配或纹理成本。
- 10次热开关3.208–4.539ms，已知行/编辑框/视口对象身份保持复用；未全局枚举Frame，不能据此宣称全部引擎对象数完全不变。
- 诊断完整GC前后各一次，分别128.511/132.595ms；这是全客户端测试干预，生产路径不调用。重复后全局Lua堆差-281.385KiB，解释为本轮未观察到保留增长，不能归因成Lychee节省281KiB。未修改GC策略。
- 关闭清空计算快照、结果与选项；卸载清context/resources/event/refreshToken，重新挂载正常。UI固定控件保留复用。

仍待验收：硬件鼠标、视觉和小视口、实际DoT说明与战斗伤害对照、真实Buff存在/到期、其他职业/天赋、真实战斗取消/恢复、enUS、50轮浸泡、单插件内存归因及原生纹理/Frame内存。本轮未修改运行文件，未重复同步或发布。上述性能样本支持当前场景成本有界，不能代替完整性能矩阵。
