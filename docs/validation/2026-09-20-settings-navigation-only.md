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
实机将覆盖：保留菜单三项、固定/取消固定、别名页打开/取消、各设置族左键定位、历史恢复、旧修改调用拒绝、自然语句不返回修改动作、关闭重开和清理后五路音量不变。实机及同步结果见下。

## 实机发现的原生可见性问题

第一次功能回执 `LYCHEE-20260920-032217-0027` 失败于字幕背景定位；第二次诊断回执 `LYCHEE-20260920-032449-0028` 完整保留 54 条已通过断言及失败详情（外层任务完成，内部功能断言失败）。`PROXY_MOVIE_SUBTITLE_BACKGROUND` 的 initializer `ShouldShow=false`，普通导航被沿用的修改前置检查阻断。两张回执均已完整接收及 ACK 清理，测试历史/固定/搜索记忆恢复、五路音量不变。

同版本 wowdoc `Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Subtitles.lua:132–138`：注册下拉框后，`ShownPredicate()` 返回 `subtitlesEnabledSetting:GetValue()`。该条件控制控件显示，不应阻止分类导航。修复只保留目标存在、非战斗及原生接口/打开结果检查；隐藏控件打开所属原生分类，不替用户开启字幕。增加 `ShouldShow=false` 仍可导航的回归。

## 最终实机验收与交付

运行代码提交：`3b0d3b02cde906979abb1bdf230793d1e4b12c60`（导航化），`8890aaf3e187600848171c9da3d9441fadc88113`（隐藏控件分类导航）。main 单包 Lychee 覆盖复制 173 个运行文件，清单及全部 SHA-256 一致；未删除目标旧文件。无 TOC/加载顺序变化，后台重载完成。

最终 Ticket：`LYCHEE-20260920-033251-0029`，requestId `settings-navigation-20260920-r3`，revision `r3`。Retail 12.1.0.69875 / Interface 120100 / zhCN，晴昼秋岚—白银之手。完整 payload：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-033251-0029/content.json`（4947 bytes，SHA-256 `a0089283afeff2f2be011f6b38757ec9030f9d3e21c76963a7251b3942951268`）。外层 succeeded/complete，内部 63 项断言全部通过，无 failure；环境与绑定核对一致。

- 三个右键菜单项：打开并定位、设置别名、固定到首页/取消固定；真实回调验证固定、取消固定、打开别名编辑及取消。
- 主音量、输出设备、自动拾取、阴影质量、与目标互动快捷键、字幕背景：默认单一普通 open，点击打开正确原生分类并关闭启动器；历史恢复后仍为普通 open。
- 原 query/resolveTarget/describe/observe/edit views 不再注册；旧 setting-toggle/setting-number/setting-open/stage-choice/set-volume invocation 和 command 无法准备或恢复。查询“音量调整到30%”“设置音量为30”未产生修改动作。
- 多轮关闭重开正常；自有测试历史、固定项、搜索记忆恢复；五路音量前后相同，首页活动条目释放。
- 报告完整读取、ACK confirmed/cleared 使用同一 nonce；自有 `settings-navigation-probe` 磁盘区块已移除。

初次输入侧握手未执行，存档时间未更新，完整 WGC 画面仍为原生音频页；随后只读身份码确认绑定和后台输入通路，在原 nonce 下仅做一次有记录的恢复发送，成功得到 reload_ready 并清理。其后测试输入/输出重载全部使用新版 nonce 握手，无前台切换、SendInput 或剪贴板。

修正后的完整契约再次 PASS，Lua 5.1、diff 检查及全目录 wowdoc（111 Lua、零诊断）PASS。额外的 wowdoc `--toc` 闭包验证持续运行超过五分钟未返回，结束该进程；不将该模式记作通过。加载顺序和四客户端 TOC 由契约测试验证。

边界：实机仅上述 Retail zhCN、非战斗场景；原生 API 缺失/异常、战斗拒绝及注销重注册用离线替身覆盖。字幕关闭时打开所属分类，不保证隐藏控件可见，也不替用户开启字幕。SDK 能力由独立 Provider 契约回归验证。本轮仅记录输入同步提交耗时和自然整客户端 Lua heap，后者混入其他插件、原生页面和 GC，不是 Lychee 分配/保留或查询完成延迟；没有宣称性能提升，也没有完成全客户端性能基准对比。
