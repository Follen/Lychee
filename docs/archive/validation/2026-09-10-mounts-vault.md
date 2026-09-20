# 坐骑与宏伟宝库 Provider

日期：2026-09-10。新增 `builtin.mounts` 与 `builtin.great-vault`。

## 行为

- 坐骑按当前客户端的坐骑名称搜索，只收录已收藏且 `shouldHideOnChar` 为 false 的记录。图标使用原生坐骑图标。坐骑在室内、移动等情况下暂时不可召唤，不影响搜索或拖到动作条。
- 点击动作声明已有的 `secure-spell`，绑定坐骑召唤 spellID；通过真实鼠标点击执行，成功施放才关闭搜索并记录最近使用，失败保留重试。拖拽声明已有的 `spell`，通过 `C_Spell.PickupSpell(spellID)` 拖到动作条；不改变坐骑面板筛选，不使用随筛选变化的 displayIndex。
- 共享 `Secure/Policy.lua` 在玩家技能书检查返回 false 时，通过 `GetMountFromSpell` / `GetMountInfoByID` 核实该法术确实属于已收藏、未对角色隐藏的坐骑。读取异常拒绝操作；没有允许 Provider 绕过校验的新字段或回调。
- 宏伟宝库命中“宏伟宝库”“低保”“宝库”“每周奖励”“大秘境低保”“great vault”“weekly rewards”；调用 `WeeklyRewards_ShowUI` 并确认页面显示。已打开时保持打开；战斗、禁止切换界面、加载异常、调用未实际显示窗口时返回失败。

## wowdoc 依据

修改前 `wowdoc source check`：`sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`，本地与远端均为 `resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。完整 path、line、excerpt 与版本元数据见 [查询证据](../design/2026-09-10-mounts-vault-wowdoc.json)。关键定义：

| 源路径（Interface/AddOns/ 下） | 行 | 返回 excerpt 的关键内容 |
|---|---:|---|
| Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua | 264 | GetMountIDs 返回 mountIDs 数组 |
| 同上 | 273 | GetMountInfoByID 返回 name、spellID、icon，第 10 项 shouldHideOnChar、第 11 项 isCollected |
| 同上 | 249 | GetMountFromSpell 接收 SpellIdentifier，返回可为 nil 的 mountID |
| 同上 | 636 | NEW_MOUNT_ADDED 带 mountID 参数 |
| Blizzard_APIDocumentationGenerated/PetJournalInfoDocumentation.lua | 342、346 | COMPANION_LEARNED / COMPANION_UNLEARNED 不带 ID |
| Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 3693 | PLAYER_LEVEL_CHANGED 提供等级变化通知 |
| Blizzard_APIDocumentationGenerated/SpellDocumentation.lua | 928 | PickupSpell 接收 SpellIdentifier |
| Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua | 11 | After 接收秒数和回调，用于同帧合并 |
| Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua | 11 | IsPlayerSpell 委托给玩家技能书的 IsSpellKnown |
| Blizzard_FrameXML/SecureTemplates.xml | 4 | SecureActionButtonTemplate 为 click-cast 按钮模板 |
| Blizzard_WeeklyRewards/Blizzard_WeeklyRewards_Bootstrap.lua | 7 | WeeklyRewards_ShowUI 加载 UI 后以 force=true 显示 WeeklyRewardsFrame |

原生坐骑面板 `Blizzard_Collections/Mainline/Blizzard_MountCollection.lua:914` 用 displayIndex 拾取，索引与该面板筛选相关，所以此处选用已确认支持 spellID 的通用法术拖拽接口。

## 更新与成本

坐骑仅在 Provider 启用时保留一个可复用的事件 frame，注册 NEW_MOUNT_ADDED、COMPANION_LEARNED、COMPANION_UNLEARNED、PLAYER_LEVEL_CHANGED、PLAYER_REGEN_ENABLED。没有 OnUpdate、周期轮询或搜索时的收藏扫描。宏伟宝库不创建 frame、不注册事件。

- 首次启用读取一次坐骑 ID 列表和各 ID 的详情；按 N 个坐骑进行 O(N) 构建。隐含上限是当前客户端提供的坐骑列表；压力样本为 1,500 个已收藏条目。
- NEW_MOUNT_ADDED 单个事件只读取对应 ID；重复事件合并为一次 After(0)。无 ID 的收藏/等级事件需复核整份列表，但仅提交真正变化的条目。未改变的数据不会推进索引 revision。
- 战斗中仅更新 dirty 标记，不查询收藏 API、不重建索引；脱战后合并处理。API 或提交失败保留旧索引及 dirty 状态，下一次事件或重新启用重试，不创建无限重试 timer。
- 禁用/注销后移除全部事件和 OnEvent 回调；已排队的一次性回调通过生命周期编号失效。重新启用复用原 frame，注销释放本地条目缓存。

完整回归中的离线样本（Lua 5.1，不代表游戏内 CPU 或帧时间）：

| 场景 | 结果 |
|---|---|
| 1,500 个坐骑首次注册与建索引 | 146 ms；GC 后增量约 16,527.5 KiB |
| 100 次交替名称查询 | 平均 5.070 ms；新增收藏 API 读取 0 次 |
| 重复同 ID 新坐骑事件 | 一个延迟回调、一次单 ID 查询；无全表查询 |
| 战斗期间收藏变化 | 收藏 API 读取 0 次、排队 timer 0 个；脱战恢复 |
| 禁用后运行已排队回调 | 收藏 API 读取 0 次，注册事件归零 |
| 重新启用 | 复用事件 frame，无新 frame |

首次建索引有可测的一次性成本，不将该离线样本宣称为无成本。实际登录、站立、单目标、多目标/团本、姓名板峰值和窗口开关场景的 CPU、Lua 内存及帧时间尚未取得游戏内基线/修改后样本；需实机验收。当前提交的控制措施为无空闲逐帧工作、战斗期间延迟扫描、按数据变化增量提交、禁用后停止事件；没有添加默认开启的 profiler。

## 验证

- `pwsh -NoProfile -File tests/check_contract.ps1`：12 组测试全部通过。
- 新增 `mounts_vault_smoke.lua` 验证收藏/隐藏过滤、名称搜索、增量/无变化/移除、同帧合并、战斗延迟、API/提交失败重试、禁用、重启用、过期回调、空 API 短路和宝库成功/失败路径，以及 1,500 条压力样本。
- `interaction_smoke.lua` 使用真实 Host、安全按钮与 Provider 链路，验证技能书之外的坐骑法术正确绑定 spell 属性、列表和最近使用都能拖拽、召唤失败保留搜索、成功关闭并记入历史，以及收藏移除后的实时拒绝。
- `luac -p`：运行时、SDK 与测试共 54 个 Lua 通过；Bindings XML 和 TOC 引用检查通过。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：37 个运行时 Lua，valid=true、零诊断，见 [结果](../design/2026-09-10-mounts-vault-validate.json)。
- `git diff --check` 通过。没有修改 SDK 协议或为业务增加新的动作类型。

## 交付与游戏内验收

检查通过后先提交，再复制运行时文件及已有图标许可证到 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，比较完整文件清单与所有 SHA-256；不复制测试、文档和查档证据，不删除目标旧文件。

本次增加 TOC 模块，应重启客户端。搜索一个已收藏坐骑名称，点击召唤、从结果和最近使用拖到动作条；获得新坐骑后检查自动命中；分别输入“宏伟宝库”“低保”打开宝库。游戏内的真实召唤、动作条放置、taint、战斗及性能仍需实机验收。

回滚使用新 `git revert` 提交，检查后重新复制运行时；不改写已交付历史、不自动删除旧文件。
