# 暴雪设置只保留原生定位

## 范围与行为

用户取消此前下拉页美化，明确要求暴雪设置移除 Invocation、右键修改选项、直接调整及自然语义执行，默认左键统一打开并定位；右键的设置别名、固定到首页/取消固定保留。SDK 的通用 Invocation 能力保留。

基线 `e06cd7b`。音量、开关、数字、下拉、颜色、组合图形项、快捷键和分类使用原稳定 entryID，均只有一个普通 `open` 动作。重载界面和冷却管理器独立入口保留。普通名称、变量和别名继续参与文档搜索；不再注册 query 解析、resolveTarget、describe、observe、编辑 view 或可写参数动作。原生定位成功后关闭启动器；失败不报成功。

旧设置/音量 invocation、command 或已删除次要动作无法恢复执行，不清空或改写历史及固定项，不将旧修改调用静默转换成定位。仍有效的普通 open 引用继续使用。Host 的别名和固定菜单保持原逻辑。

## 成本与生命周期

移除设置写入、选项解析、自然语言语法及索引、五条音量控件和设置编辑视图实现。既有七个已退役 TOC 文件保留仅含注释的空入口，维持当前所有客户端加载清单与顺序，避免文件缺失和不必要重启；不是停用后仍常驻的业务实现。

目录沿用有界扫描、分批提交、最终候选物化与单包归属。只读取名称/变量/原生定位信息，不读取设置值和选项、不调用 setter。无新增 Frame、事件、timer 或持久字段；注销清除 adapter 目录。沿用 4096 目录上限、16 条提交批次、1ms/32 项检查点。没有修改 SDK/Host 的 Invocation、历史或菜单合同。

## 证据与回归

wowdoc source list/check 后查 sourceId `wow-ui-source`、product `retail`、requestedRef/matchedTag `12.1.0`、resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。
`Interface/AddOns/Blizzard_APIDocumentationGenerated/SettingsUtilDocumentation.lua:15–24`：`C_SettingsUtil.OpenSettingsPanel(openToCategoryID?: number, scrollToElementName?: stringView)`。`Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua:143–144` 的 `Settings.OpenToCategory` 直接转交这两个参数。本轮沿用原生定位接口。

新增 `tests/providers/settings_navigation.lua`，旧实现失败于 `settings must not parse natural-language commands`。覆盖各设置类型只有普通定位动作、名称别名、正确分类和名称参数、零写入、旧调用拒绝、普通历史、原生失败、战斗拒绝、快捷键 ID、组合标签、注销和重新注册。原编辑功能测试随功能退役，SDK invocation、异步、动作、参数、多调用和通用历史测试继续运行。

离线验收通过：完整 `tests/check_contract.ps1`、四语言设置导航、SDK Invocation/异步/参数/动作/分配回归、设置目录生命周期和内存预算、Lua 5.1 语法、Bindings.xml、TOC 矩阵、wowdoc 静态验证（111 Lua，零诊断）及 `git diff --check`。
SDK 分配测试改用独立 500 文档、五参数动作的测试 Provider，继续断言没有多余 reference/schema 复制、每动作仅一次 args 复制；不降低门槛。Provider 扩展测试改用普通 open 执行并验证分类/定位名称。
实机将覆盖：保留菜单三项、固定/取消固定、别名页打开/取消、各设置族左键定位、历史恢复、旧修改调用拒绝、自然语句不返回修改动作、关闭重开和清理后五路音量不变。实机及同步结果待补记。
