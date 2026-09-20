# 2026-09-19 wowdoc 完整 TOC 验证与事件诊断复核

## 结论

官方 wowdoc 0.0.13 的完整验证因性能问题中止，不能记作通过。隔离诊断副本完成了相同正式服 TOC 的完整检查，原始结果仍为 **`valid=false`**：27 条 `event_not_found`，涉及 15 个唯一事件。下面逐项给出同一官方快照中的直接声明或使用证据，证明这些事件并非不存在。原始诊断保留，没有改写成通过。

这份记录只解释已定位的工具误报，不替代游戏实测，也不把未解析调用当作已经验证。

## 工具与检查范围

- 官方工具：wowdoc `0.0.13`，源码提交 `bc5eae88d776418f79aac07a2cfb3ee48a417e80`；本地源码 HEAD 与安装二进制 doctor 结果一致。
- 来源：`wow-ui-source`；product：`retail`；requestedRef / matchedTag：`12.1.0`。
- resolvedCommit：`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。
- TOC：`addon/Lychee/Lychee_Mainline.toc`。隔离副本完整扫描 111 个 Lua 文件，未删减加载闭包；耗时 14.25 秒。
- coverage：checked 5763、resolved 405、unresolved 5407。未解析项保留为：48 个计算调用目标、1 个计算事件名、5358 个未索引为游戏 API 的调用候选。
- 原进程 PID 30844 核验可执行路径和完整命令后，经授权中止；没有对原进程输出补造结果。

## 隔离副本为何能完成

原 SQL 的 Frame 类型查询计划先枚举 `snapshot_files`，再对每个文件扫描 `xml_nodes`。单个 `CreateFrame("Frame")` 样本超过 20 秒；另一个 Interface-only 样本耗时 12.25 秒，API-only GetTime 为 0.109 秒。源码中 68 处 CreateFrame 调用又按各自文件位置重复查证。

副本只改 `internal/query/compat.go`：用 `CROSS JOIN` 约束同一内连接条件的执行顺序，保留过滤、排序和输出；在单次 LookupCompatibility 内按规范化 kind/name 缓存查证结果。数据库、来源、product、ref、snapshot 和 game-source 模式均在该次调用内固定；每个 usage 重新生成独立 file/line/column 证据。原 Analyze、TOC 闭包、诊断与未解析项均未删改。安装工具、wowdoc 原仓库和插件运行源码没有因该诊断修改。

验证副本：

- wowdoc 自带 `go test ./internal/query ./internal/validator` 通过。
- 官方与副本在重复 GetTime、未知调用、Interface 的同一个小样本上 JSON 完全相等（12.266 秒 / 0.953 秒）。
- 另一个包含重复 GetTime、未知调用、ADDON_LOADED 的小样本已保存两份完整结果，逐字段相等；两边都保留同一事件误报。
- 副本两个 Frame 加 Interface 的样本耗时 0.250 秒，checked/resolved 均为 5。原 Frame 查询未在边界内结束，因此不声称该样本已与官方完整结果逐行比对。

## 15 个事件的官方源码证据

下列内容来自官方 wowdoc `query --source wow-ui-source --product retail --ref 12.1.0 --topic events --text <事件名> --limit 3`。优先列 generated API 声明；搜索结果只有官方 UI 使用处时，明确标为使用证据。索引只保存 `AddonLoaded` / `C_AddOns.AddonLoaded` 等名称，而验证器用 `ADDON_LOADED` LiteralName 查询，是本轮误报的直接原因。

### `ADDON_LOADED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua:391`。

```lua
390: 			Type = "Event",
391: 			LiteralName = "ADDON_LOADED",
392: 			SynchronousEvent = true,
```

### `BAG_UPDATE_DELAYED`

- 官方 UI 使用：`Interface/AddOns/Blizzard_BoostTutorial/Blizzard_TutorialLogic.lua:1310`。

```lua
1310: function Class_EquipItem:BAG_UPDATE_DELAYED()
1311: 	if (self.IsActive) then
```

### `COMPANION_LEARNED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/PetJournalInfoDocumentation.lua:342`。

```lua
341: 			Type = "Event",
342: 			LiteralName = "COMPANION_LEARNED",
343: 			SynchronousEvent = true,
```

### `COMPANION_UNLEARNED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/PetJournalInfoDocumentation.lua:348`。

```lua
347: 			Type = "Event",
348: 			LiteralName = "COMPANION_UNLEARNED",
349: 			SynchronousEvent = true,
```

### `CURRENCY_DISPLAY_UPDATE`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua:595`。

```lua
594: 			Type = "Event",
595: 			LiteralName = "CURRENCY_DISPLAY_UPDATE",
596: 			SynchronousEvent = true,
```

### `CVAR_UPDATE`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/ConsoleDocumentation.lua:176`。

```lua
175: 			Type = "Event",
176: 			LiteralName = "CVAR_UPDATE",
177: 			SynchronousEvent = true,
```

### `GLOBAL_MOUSE_DOWN`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua:66`。

```lua
65: 			Type = "Event",
66: 			LiteralName = "GLOBAL_MOUSE_DOWN",
67: 			SynchronousEvent = true,
```

### `NEW_MOUNT_ADDED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua:638`。

```lua
637: 			Type = "Event",
638: 			LiteralName = "NEW_MOUNT_ADDED",
639: 			SynchronousEvent = true,
```

### `PLAYER_LEVEL_CHANGED`

- 官方 UI 使用：`Interface/AddOns/Blizzard_NewPlayerExperience/Blizzard_TutorialLogic.lua:5`。

```lua
5: function TutorialLogic:PLAYER_LEVEL_CHANGED(originalLevel, newLevel)
6: 	if newLevel > 10 then
```

### `PLAYER_LOGIN`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua:131`。

```lua
130: 			Type = "Event",
131: 			LiteralName = "PLAYER_LOGIN",
132: 			SynchronousEvent = true,
```

### `PLAYER_REGEN_DISABLED`

- 官方 UI 使用：`Interface/AddOns/Blizzard_BoostTutorial/Blizzard_TutorialLogic.lua:1497`。

```lua
1497: function Class_LootCorpseWatcher:PLAYER_REGEN_DISABLED(...)
1498: 	self:SuppressChildren();
```

### `PLAYER_REGEN_ENABLED`

- 官方 UI 使用：`Interface/AddOns/Blizzard_BoostTutorial/Blizzard_TutorialLogic.lua:1502`。

```lua
1502: function Class_LootCorpseWatcher:PLAYER_REGEN_ENABLED(...)
1503: 	self:UnsuppressChildren();
```

### `UNIT_SPELLCAST_FAILED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:4570`。

```lua
4569: 			Type = "Event",
4570: 			LiteralName = "UNIT_SPELLCAST_FAILED",
4571: 			SecretWhenUnitSpellCastRestricted = true,
```

### `UNIT_SPELLCAST_INTERRUPTED`

- 生成文档声明：`Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:4598`。

```lua
4597: 			Type = "Event",
4598: 			LiteralName = "UNIT_SPELLCAST_INTERRUPTED",
4599: 			SecretWhenUnitSpellCastRestricted = true,
```

### `UNIT_SPELLCAST_SUCCEEDED`

- 官方 UI 使用：`Interface/AddOns/Blizzard_BoostTutorial/Blizzard_BoostTutorial.lua:21`。

```lua
21: function BoostTutorial:UNIT_SPELLCAST_SUCCEEDED(unit, cast, spellID)
22: 	-- NOTE: Might not want to to do this here in case the tutorial requires multiple spell casts...
```

## 原始证据与完整性

以下文件保存在本机忽略的 `analyze/feature-port/`，原始完整报告约 82.8 MB，不作为运行资源交付。复核摘要为本文件；哈希用于定位本次证据，不表示未来源码改动已被覆盖。

| 文件 | SHA-256 |
| --- | --- |
| `wowdoc-retail-diagnostic.json` | `9bd2c9eed1008092af8eb13901d485725ee8a7fd8bea32892639a35d5cef802d` |
| `wowdoc-retail-event-evidence.json` | `04eabf3ff6c149e00d3eefe49ad7f9d951003fb76a1586718f13771bdd82113b` |
| `wowdoc-diagnostic-equivalence.json` | `2d0505c9dd5dd368bb4a1298f905ea8cb7a183f6b64998de75856d95cdac4972` |
| `wowdoc-diagnostic.patch` | `ec89bcd954a8bbc2c82217dff07e77513e024245039983c8418d2a4191885c23` |
| `wowdoc-diagnostic/wowdoc-diagnostic.exe` | `4ac3cc10331f661a1cb02f345477ae0c84a1435b00d5960e78db7312e3377c1c` |

副本构建使用 Go 1.26.5；官方安装工具 doctor 显示 Go 1.24.0。小样本及工具测试验证了本次查证结果的一致性，但不据此扩大到所有语言、所有客户端或所有动态 API。其他客户端 TOC 需各自记录；这里仅涵盖正式服 12.1.0。
