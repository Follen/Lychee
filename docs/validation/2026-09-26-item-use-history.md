# 物品成功使用后的历史动作修复

## 症状与确认

用户流程：搜索炉石 → 选择定位背包 → 再搜索炉石 → 左键并成功使用 → 历史仍为定位。

修复前 `lua tests/ui/item_history.lua` 在第34行稳定失败：`after successful item use, history still replays Locate in bags`。测试调用真实 Provider 注册、普通定位动作执行、SecureActionBroker 点击回调、UserPreferences 与历史恢复；仅替换外部游戏 API、硬件执行和事件。不是实际施法证据。

原因是 secure-item 的 PostClick 只关闭并释放按钮，未订阅物品使用对应的成功回执；原 FinishCast 仅处理 secure-spell。旧定位历史未被错误改写，新的成功使用根本没有记入历史。历史条目本来区分动作，继续保留定位记录，成功使用排在它前面；固定项和搜索默认动作不变。

## 改动及体验约束

复用安全动作代理原有事件框体和成功出口，按 C_Item.GetItemSpell 返回的使用法术匹配 UNIT_SPELLCAST_SENT 的 castGUID，再接收对应成功/失败。记录仅保留点击结果与动作，不依赖已释放的按钮/行。物品依旧原生硬件点击执行，PostClick 依旧马上关窗；不等待施法、不脚本调用使用、不取消原生光标。

瞬发成功不在 PostClick 前重绑首页行；成功时不再关闭用户后来打开的搜索框。只维护一个最长30秒的待确认记录；成功、失败、打断、无关新施法、替换、超时和 Destroy 收回引用及 timer。未缓存使用法术/缺事件/受限回执不伪造成功。此修复不承诺没有使用法术回执的所有物品都能记成功历史。

## 功能与性能验收

- 四语言 item_history 回归通过：定位→成功使用、瞬发关窗、失败/打断、其他单位/法术/GUID、超时、旧 timer、替换、缺失数据、关闭重开、销毁清理。
- 既有 history_actions、bag_actions（含玩具放置光标保留）、perf_provider_secure_events 通过；完整 check_contract.ps1 通过。
- 1000次受保护物品回执离线循环：7 ms、累计分配746.1 KiB、回收后增长0.0 KiB、新增Frame0、结束事件0。不是游戏CPU/内存；不声称性能提升。数据由一个操作所有，最多保留30秒；框体沿用代理池，重复操作无增长。
- 五客户端逐端静态 loadValid/staticValid=true、加载issues为空；complete=false，未检查binding identity、argument types、dynamic code、combat、taint和实际运行，Interface基线仍unresolved。
- 运行版本0.4.1；正式服已完成从既有定位历史重新搜索、真实左键使用炉石、成功传送、重开首页确认使用历史。其他客户端及失败、取消、重试、战斗/taint场景仍待实测，不能用离线覆盖替代。

## 固定源码证据

sourceId=wow-ui-source；以下记录请求的精确commit及该版本原文位置。GetItemSpell 返回 spellName/spellID 且 MayReturnNothing；SENT 的载荷为 unitTarget、target、castGUID、spellID，不能按 SUCCEEDED 的位置读它。正式服事件可能含受限值，分支前检查。SUCCEEDED 定义在正式服 UnitDocumentation.lua:4698。

| product | requestedRef / resolvedCommit | symbol | path | line |
| --- | --- | --- | --- | --- |
| retail | 78282522143e25c3540583734fd192c3d69be910 | C_Item.GetItemSpell | Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua | 947 |
| retail | 78282522143e25c3540583734fd192c3d69be910 | UNIT_SPELLCAST_SENT | Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 4656 |
| classic | ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | C_Item.GetItemSpell | Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua | 673 |
| classic | ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | UNIT_SPELLCAST_SENT | Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 3244 |
| titan | 84ef503f0d2617494db84cc9c7e7b530e976f6e7 | C_Item.GetItemSpell | Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua | 673 |
| titan | 84ef503f0d2617494db84cc9c7e7b530e976f6e7 | UNIT_SPELLCAST_SENT | Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 3244 |
| anniversary | 1463c686270b6c64e2c5c228f447c4597c0f8ba6 | C_Item.GetItemSpell | Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua | 673 |
| anniversary | 1463c686270b6c64e2c5c228f447c4597c0f8ba6 | UNIT_SPELLCAST_SENT | Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 3244 |
| forever | 70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e | C_Item.GetItemSpell | Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua | 969 |
| forever | 70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e | UNIT_SPELLCAST_SENT | Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua | 4784 |

静态 capture：

- anniversary: CAP-2a71ccf7c959779817c07707041c38d6c789a84ab6fcca86ddefcfae7ff71877
- classic: CAP-17bade9cf713b843adff0ecf2a714fafd347911d93da62baacc4c498e0c84aa6
- forever: CAP-7fe3ac70b7b8825f3cdd875d0bf4776adb48493d01e253d4522bf51dfca65bbc
- retail: CAP-cb0f2fa684e5fa023878aac18c37b940bbc043120ca231f4fe81075a81dfece8
- titan: CAP-1246b6ad1c92279ed1c24bc16cd9753538f4a69cf44b9fc0918d9557a7c392ff

## 交付与实际连接状态

运行提交 `44765e2b61a889dc977e378d0b6e1aba604639c8`，版本0.4.1。仅同步正式服 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee` 的203个运行清单文件，逐文件SHA-256一致；目标旧文件未删。未推送或发布平台。

本次连接曾确认 Retail 12.1.0.69933、灵止光/死亡之翼，SESSION-f2b8df853578619263a28b9b8a7ecc2815dadac770c30ca6d4c6448bd2b5fd92。之后 standalone reload 在 connect 阶段返回 live.identity_unreadable/context deadline exceeded，没有产生 operationId，不能声明加载成功。Lychee Dev 磁盘 addon status 为managed、2.0.3；磁盘状态不能证明该版已加载。

通过 Computer Use 的 WGC 只读查看确认游戏仍在线，聊天中有 Lychee Dev 对命令返回的 usage 提示（status/connect/disconnect）；这提示对接异常，但没有据此猜测确切运行版本、战斗状态或擅自重放命令。已请求用户方便时暂停操作再进行UI重新加载。尚未用受保护按钮实际执行炉石。

以上是此前连接失败时的状态，以下为用户暂停游戏后重试所得的实际验收结果。

## 正式服实机重试结果（2026-09-26 19:27 +08:00）

观察探针 `PRB-581335c5d04e5708b2196b92a0f3d09638bc6e726ee0586c9c2b1b020edc23a4` 已加载执行。客户端回报 `version=0.4.1`、`fixLoaded=true`、Retail build69933/interface120100、zhCN。操作 `OP-80ebb0c89be98bc5822007fac6b91495` 首次 run 遇到 `desktop.capture_resized`，随后 resume 同一操作取得 verified 报告；没有重复发起物品使用。完成后已 ACK，`complete=true`、`cleanup=complete`，并隐藏测试回执。

通过 Computer Use 原生输入打开荔枝，首页第一条确认为“炉石 · 定位背包”。输入“炉石”后左键点击搜索结果第一条，游戏实际读条并传送至“旅者的梦乡”。探针仅观察事件，没有模拟成功事件或调用使用接口。

- 物品 `builtin.bags / item:6948`，点击动作 `use`，实际使用法术8690。
- 匹配的 castGUID：`Cast-3-3903-0-246807-8690-0004B7ABF9`；`observed=true`、`correct=true`。
- 使用前最新记录 `actionID=locate`；成功后最新稳定引用为默认使用动作，恢复所得 `restoredAction=use`，原定位记录移至第二条。
- 实际重开首页：第一条“炉石 · 使用物品”并显示15分钟冷却，第二条“炉石 · 定位背包”。此次沿用用户现存定位记录，没有重新执行定位动作。
- 成功结束后 `pendingItem=false`、`timerRemaining=false`、`castSubscriptions=false`。这证明本次生命周期清理，不代表已完成实机CPU/内存压力验收。

报告已保留：`CAP-7c23c62a59cc89786a27e7041b516837da07263b3a7af68448ddfbf25e4b7965`；SHA-256 `758de158447563b1e85a43c180789ff1e9663ac5b5f7c88d8869b7529020e9cd`。回执 `CAP-7d8baa0c566c480b0fbe8d629c697e8a8bb48c77460e8485b81e9fa5284c180f`。

本次只证明正式服炉石成功使用后的历史更新及重开显示正确。点击后立即关窗的时序未单独测量；取消、失败、目标光标、其他物品、其他客户端、战斗/taint和实机性能仍未扩展验证。
