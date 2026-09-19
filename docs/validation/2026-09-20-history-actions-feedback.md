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

## 实机验收计划与边界

使用 lychee-dev 后台 messages 通路，Retail zhCN：检查现有历史标签；执行当前音量值以验证业务结果与反馈但不改变音量；打开原生音量控制及暴雪定位入口。临时 Provider 验证普通/参数化动作、失败、取消、重试、迟到回调、关闭重开、注销和重新注册。测试临时隔离近期历史和搜索选择，完成或失败时恢复原数组、移除自有 Provider、停止自有 timer。

记录确切 Ticket、payload、环境、校验、ACK 与任务清理。20 次有界温恢复只报告实际耗时与自然 Lua 堆差，不将自然堆差当保留增长或插件独占内存。不执行 GC、不改变 profiling。独立第三方原生冷加载、其他客户端、其他语言实机、战斗和真实安全硬件点击不在本轮已验证范围，不能由离线回归替代。

离线完整 `tests/check_contract.ps1` 已通过，原始日志 `analyze/history-feedback-contract.log`；Lua/XML 静态检查及 wowdoc 111 Lua 校验通过，diagnostics=[]，git diff --check 通过。同一实机探针在离线 UI 环境预演通过 38 项检查（缺原生设置数据的一个分支明确跳过），不是实机证据。

计时证据同一来源版本：`Interface/AddOns/Blizzard_APIDocumentationGenerated/OsDocumentation.lua:27–33`，`GetTimePreciseSec` 返回非空 number。交付与最终实机结果待完成后补记。
