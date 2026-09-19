# 历史动作身份与执行反馈

## 范围与规则

基线 `5c71a63`。同名历史不能区分右键入口，普通次要动作恢复后还会变回默认动作；成功执行后底栏为空。用户确认不同参数全部保留。

- Provider 定义动作名、参数、结果文案和当前展示。Host 保存完整稳定引用、恢复相同动作、显示来源与动作，并处理等待、成功、失败、取消和结果不确定状态。
- 同目标不同动作、同动作不同参数分别保留；只有完全相同的调用更新顺序。近期仍最多 8 条，不改变容量。
- 原生音量控制与命令面板入口由 Provider 声明同一个 command 引用；旧存档经恢复后若引用完全相等，首页只显示一次并继续补足可见条数，不改写原记录。不按同名文本去重。
- 普通入口的次要动作保存可选 `actionID`。参数化搜索结果上的普通面板动作也保存成入口，不能误记为执行参数命令。没有动作信息的旧条目保留默认入口，不能追溯推断过去选择。
- Invocation 恢复匹配当前主调用或菜单中的准确调用后采用 Provider 展示；不匹配仍使用保存回退。通用设置补齐滑块数值、开关、选项等恢复；音量保留旧 command 面板入口。缺失动作不可执行，不退回默认动作。
- 历史右侧显示“类别/来源 · 实际动作”。不按标题合并，不清空历史。固定与搜索记忆保留次要动作身份。
- Provider 可返回有界本地化 `message`；Host 按真实终态显示，并绑定当前搜索和操作次序。成功前不写历史，迟到回调不覆盖较新动作；导航/重开清除旧反馈。预填设置明确提示尚需应用，结果不确定不被普通文案掩盖。

## 成本与生命周期

没有新增 Frame、事件、timer、常驻驱动或跨查询缓存。只在动作完成时保存至多 64 字节动作 ID；恢复时扫描当前条目最多 16 个已声明动作，历史可见 5 条、保存上限 8 条。每次首页恢复使用最多 8 项的临时引用集合去重，恢复结束不保留集合。来源标签在恢复绑定时生成，复用现有单行来源列。底栏只保留一条反馈及会话/代次标量，替换输入或操作后失效。

普通次要动作身份使用有界独立 key，不给同条目的其他动作或参数套用搜索偏好。旧参数面板恢复增加一次有界 reader 调用。未改变搜索扫描、结果数量、原生音量读写 API 或资源容量，不宣称性能改善。

## 证据与回归

修改前已运行并失败：`lua tests/ui/history_actions.lua` 报 `history replay switched the selected secondary action to default`；`lua tests/ui/volume_result_refresh.lua` 报 `successful action left footer blank`。

回归覆盖：普通默认/次要动作、参数化结果的普通入口、30/50 参数分别保留、重复动作去重、固定与搜索记忆、缺失动作、Provider 文案、异步失败/取消/重试/迟到回调、重开清理，以及非音量设置的开关/数值/预填。zhCN/enUS/zhTW/enGB 历史用例及中英实际音量写入回归通过。

wowdoc source list/check 后使用 sourceId `wow-ui-source`、product `retail`、requestedRef/matchedTag `12.1.0`、resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_AccessibilityTemplates/UserScaledElementTemplates.lua:79–82` 的 `UserScaledButtonFitToTextMixin:SetText` 调用 `self.Text:SetText(text)`，沿用原 FontString 文本接口；不新增原生 API。

## 实机验收与边界

使用 lychee-dev 后台 messages 通路，Retail zhCN：检查现有历史标签；执行当前音量值以验证业务结果与反馈但不改变音量；打开原生音量控制及暴雪定位入口。临时 Provider 验证普通/参数化动作、失败、取消、重试、迟到回调、关闭重开、注销和重新注册。测试临时隔离近期历史和搜索选择，完成或失败时恢复原数组、移除自有 Provider、停止自有 timer。

记录确切 Ticket、payload、环境、校验、ACK 与任务清理。20 次有界温恢复只报告实际耗时与自然 Lua 堆差，不将自然堆差当保留增长或插件独占内存。不执行 GC、不改变 profiling。独立第三方原生冷加载、其他客户端、其他语言实机、战斗和真实安全硬件点击不在本轮已验证范围，不能由离线回归替代。

离线完整 `tests/check_contract.ps1` 已通过，原始日志 `analyze/history-feedback-contract.log`；Lua/XML 静态检查及 wowdoc 111 Lua 校验通过，diagnostics=[]，git diff --check 通过。同一实机探针在离线 UI 环境预演通过 38 项检查（缺原生设置数据的一个分支明确跳过），不是实机证据。

计时证据同一来源版本：`Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua:27–33`，`GetTimePreciseSec` 返回非空 number。

### 交付与完整回执

运行时提交 `2707f819205e56f642d42e3bef7476fdfab1edea`，入口身份归一补充提交 `27f499cf836a733c14a60e6f4de07adb8c32fcd0`，均位于 main。已覆盖同步至 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，清单 173 个文件逐一 SHA-256 核对通过，随后后台 `/reload`。同步证据为本地 `analyze/history-feedback-game-sync.json`；本次最终验收记录只改文档，不再次复制游戏资源。

- Ticket：`LYCHEE-20260920-023056-0021`；task：`history-feedback-probe`；requestId/executionId：`history-feedback-20260920-r3`；revision：`r3`。
- 环境：Retail `12.1.0.69875`、Interface `120100`、zhCN，晴昼秋岚—白银之手；绑定 PID `29260`、HWND `0x50c9e`。报告环境与当前选定实例一致。
- 完整 payload：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-023056-0021/content.json`；同目录保存 `evidence.json` 和 `report.json`。内容 3727 字节，SHA-256 `31334320eb46c9741f82a83d29d50d1ebffc31d8ec6ea990944541608e6a9ade`。
- 报告 `status=succeeded`、`complete=true`、`outputTruncated=false`；48 项断言全部通过，无跳过项。
- 已完成提交、游戏执行、输出 reload、精确 SV 读取、ACK received 确认及界面码清理。日志包含匹配 Ticket/nonce 的 `ticket_ack_confirmed` 和 `ticket_ack_cleared`；nonce 为 `req-20260919-183437-1cc6d2`。自有 `history-feedback-probe` 磁盘任务块已移除。

### 已验证结果

真实暴雪入口验证：执行当前主音量 30%，实际值保持不变，底栏显示“已将主音量设为 30%”；打开原生直接调整控件、右键打开并定位暴雪设置，检查面板可见性及历史动作身份。截图与报告中的原历史均显示“暴雪设置 · 直接调整”“暴雪设置 · 打开并定位”，相同入口的旧重复表示只显示一次，下一条不同入口补足 5 个可见项。

临时 Provider 在真实客户端验证：默认/次要动作、参数结果上的普通入口、30/50 参数分别保留、成功文案、等待不写历史、失败不写历史、取消/重试、迟到结果不覆盖新动作、关闭重开清理、动作缺失、注销及重新注册恢复。测试结束恢复原历史和搜索选择，移除测试 Provider；`historyRestored`、`volumeUnchanged`、`choicesRestored`、`providerRemoved`、`homeReleased` 全部为 true。

20 次温恢复总计约 0.2524 ms，自然 Lua 堆差 +63.4141 KiB。该数字是有界实测样本，包含同期运行环境影响，不是 Provider 独占分配、保留增长或性能改善结论；未强制 GC 或修改 profiling。

此前两份探针失败报告亦完整读取并完成 ACK/清理：`LYCHEE-20260920-022252-0019` 的查询辅助函数未在原生设置导航后显式重开搜索，报 `missing visible row ordinary`；`LYCHEE-20260920-022511-0020` 在真实关闭动画结束前检查 `homeReleased`。分别修正探针的模式切换与有界隐藏等待后取得上述 r3 成功结果，不把早期失败计为通过。

实际音量只执行当前值，未在实机写入不同音量；不同值分别保留由临时 Provider 实机测试及实际音量 Provider 离线回归验证。其他语言只做离线覆盖。独立第三方冷加载、其他客户端、战斗及真实安全硬件点击未验证。采样历史截图中央有游戏菜单遮挡，但历史标题、右侧动作标签及底栏可读；最终收尾已恢复世界画面。
