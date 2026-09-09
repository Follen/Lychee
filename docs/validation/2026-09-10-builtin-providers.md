# 纹章、游戏菜单与首领 Provider

日期：2026-09-10。保持 Lychee 0.2.0 / Provider API 2 revision 1。三个 Provider 通过公共 SDK 注册，未增加 Host 业务分支。TOC 新增模块，复制后需要重启客户端。

## 数据与 API 依据

wowdoc：`sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。修改前 source check 已确认版本；精确 path、line、excerpt 见 [查询证据](../architecture/2026-09-10-builtins-wowdoc.json)。只采用 Mainline / Shared / 无分支的正式服依据；查询结果包含的旧分支不作为实现依据。

- `CurrencyInfoDocumentation.lua:249,595,681`：GetCurrencyInfo 返回 quantity/name/iconFileID；CURRENCY_DISPLAY_UPDATE 的 currencyType 可以为空。带 ID 只刷新一行，无 ID 最多刷新五行。
- `Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua:2738`：OpenJournal 接受 difficultyID、instanceID、encounterID；difficultyID 留空。`1348` 起将目标写入 encounterID；无攻略章节的旧首领仍支持资料/掉落页。
- `CharacterFrame.lua:24`：ToggleCharacter 的 onlyShow=true；PlayerSpellsUtil 的 OpenTo* 方法、SetCollectionsJournalShown(true, tab) 与 PVEFrame_ShowFrame(side, selection) 打开明确分页。
- `SettingsUtilDocumentation.lua:15`：OpenSettingsPanel 的 categoryID 可空；切换式窗口先检查显示状态，原生函数缺失、抛错或窗口未打开均返回失败。

wowdata 目标：`--source remote --region cn --product wow --build 12.1.0.69587 --locale zhCN`，与本机正式服 `.build.info` 一致。先读取 CurrencyTypes / JournalEncounter / JournalInstance schema，再按返回字段导出。当前安装的 wowdata 本地 DB2 解析失败，改用相同 Build 的 CDN 数据；字段裁剪返回空对象，因此导出完整表。快照保留在 architecture 下以便复核和重生成。

纹章采用 CurrencyTypes 中真实钱包分类 282 的 3442–3446（冒险者、老兵、勇士、英雄、神话迷雾纹章），没有误用同名展示货币 3437–3441。神话迷雾纹章图标 fileID=7734060。视图显示当前角色五档迷雾纹章，包含零数量；不混入往季废弃纹章。原始币种查询见 [CurrencyTypes](../architecture/2026-09-10-crest-currencies.json)。

首领表 1,160 条，副本表 215 条；按 JournalInstanceID 关联后得到 1,154 个有名称、有效副本关系的首领和 214 个分组。仅排除 6 条无有效命名副本关系的记录；FirstSectionID=0 的旧团本首领保留。副本小图标作为条目图标，条目身份为 JournalEncounter ID。没有随搜索切换 EJ 选择状态，也不扫描角色所在副本。目录为中文固定版本；未来版本的新增名称/ID 需要重新导出。

```powershell
# 每张表先运行 db2 schema；导出同一 Build，保存标准输出为对应快照。
wowdata db2 stream JournalEncounter --format json --limit 2000 --source remote --region cn --product wow --build 12.1.0.69587 --locale zhCN
wowdata db2 stream JournalInstance --format json --limit 1000 --source remote --region cn --product wow --build 12.1.0.69587 --locale zhCN
python tests/build_journal_catalog.py
```

## 验证与成本

`tests/builtin_providers_smoke.lua` 使用真实 ProviderRuntime、StaticIndex、QueryOrchestrator、SDK 与 ViewHost，外部 WoW API 使用确定性替身。覆盖单一纹章结果与别名、首次数量、零数量、无关事件零读取、单行刷新和 setter guard、无 ID 刷新、失败重试、关闭/禁用事件清理、重开复用、菜单直接分页与重复打开、缺失/抛错/静默失败、战斗拒绝、副本名返回多个首领、延迟加载、精确首领定位及错误定位拒绝。

本地 Lua 5.1 样本（2026-09-10）：三个新增 Provider 注册/索引约 157 ms；相对加载 Host 后、注册前，GC 后常驻 Lua 内存增加约 19,010 KiB；100 次交替查询“死亡矿井 / 纹章”平均约 4.92 ms。该增量包含索引与 SDK 的记录副本；生成目录在计量前已加载。数字用于离线成本判断，不是 WoW 客户端 CPU 或帧时间测量。

运行时频率与边界：登录注册一次 1,183 条记录（1 个纹章、28 个菜单、1,154 个首领）；菜单与首领注册不创建 frame 或事件。首次纹章视图创建 6 个自有 Frame、5 个 Texture 和 12 个 FontString，此后复用；显示期间仅响应货币事件，一次最多读五种货币。未打开视图时新增活动事件为 0，无新增 OnUpdate / ticker / timer。输入时复用 Host 静态索引；结果仍遵守 Host 最多 20 条限制，可继续输入首领名称缩小范围。

已通过：11 组契约/交互测试；运行时、SDK 和测试共 51 个 Lua 文件的 luac 解析；Bindings XML 解析及 TOC 引用/加载清单检查；wowdoc validate（35 个运行时 Lua，valid=true，零诊断）；git diff --check。完整测试中的第二个离线成本样本为注册 175 ms、常驻增量 19,010 KiB、交替查询平均 5.06 ms。数据生成器已在构建期间重生成目录，条目数量和关系由真实 SDK 测试复核。静态验证结果见 [validate JSON](../architecture/2026-09-10-builtins-validate.json)。

交付同步目标固定为 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，成功提交后仅覆盖运行时，随后校验完整文件清单和 SHA-256，不删除目标文件。实际提交和同步结果随最终交付报告记录。

需要实机验证：重启后搜索上述入口，核对钱包数值和界面页签；确认手册落到所选首领，关闭纹章视图后无事件；按 AGENTS.md 采样登录、空闲、单目标战斗、团本/多目标、姓名板峰值和搜索窗开关的 CPU、内存、帧时间。当前未取得这些实机样本，不声明 taint/帧时间验证通过。

回滚按仓库规范创建 git revert 提交，再验证并覆盖复制运行时；移除新增模块时只在得到定向删除授权后清理正式服遗留文件。
