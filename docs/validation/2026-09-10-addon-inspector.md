# 插件识别：实时悬停

用户最终批准：进入模式后鼠标指向什么就显示什么，不需要 F；悬浮窗尽量避开当前目标，Esc 退出。沿用 Lychee 原色、字体、圆角和按钮，来源明确与推测分开显示。悬浮窗自身保留前一目标供复制/详情，鼠标回到其他框体恢复跟随。世界区域显示指向提示。创建来源不能被父级关联或名称推测冒充。

实施前预算：默认关闭；启用 Provider 只注册一条静态搜索入口，不创建 UI/事件/扫描。首次操作创建并复用不超过 16 个 Frame、40 个 Region；活动时仅一个 0.1 秒定时器，目标变化时解析最多 16 层父级；没有全框体枚举或永久框体缓存。同一目标只更新必要位置/几何，退出、禁用、进入战斗、打开主搜索均清除 timer/事件/框体引用。一个不可抢占的原生调用仍需实机测量。离线首次自有对象保留 <512 KiB；100 次切换目标累计分配 <1 MiB，反复进出回收后增长 <64 KiB；同目标 100 次轮询来源读取为零，不新增 UI 对象。原生游戏场景尚未验证。

浮窗固定宽 360、摘要高 164、详情高 340，继承主面板 16/28 边距和 11/12/14 字号，避开目标的四个屏幕角落中选择可容纳位置；无可用位置时选择重叠最小处，不承诺任意全屏目标都零遮挡。位置改变直接到位，不让窗口追着鼠标漂移。淡入使用共享 Motion，内容切换不反复淡出，不做逐行动画。框体轮廓为自有鼠标穿透细红线，不改目标父级或脚本。

复制信息展示可选择文本与 Ctrl+C 提示，不能假称已写入系统剪贴板。精确创建位置未启用时显示状态，可显式选择启用并重载；不自动更改配置或重载。所有 API 需处理 secret/不可用值，进入战斗后立即停止，脱战不自动重开。来源记录 CVar 名称来自已安装 WTFisThisAddon 的 StartWITA；官方 C_CVar.GetCVar 返回非 nil 后才允许操作，未知配置不能写入。返回值和读回结果均检查。


## 实际结果

已接入公共 Provider 搜索、来源设置、同风格 SVG/TGA 图标、Builtin 初始化和主搜索重新打开时的清理。源文件独立实现，未复制第三方完整模块，无第三方依赖。用户原来的 F 锁定方案已被实时悬停取代。精确来源、名称猜测、父级推测、原生 UI、secret 焦点/来源、世界区域、浮窗自身、复制、上一级、Esc、关闭来源、战斗、旧 timer 回调和失败配置写入都有针对性回归。

Lua 5.1 离线：首次创建 8 Frame / 26 Region 替身，回收后新增约 29.1 KiB；100 次进出与交替目标共约 4–5 ms、累计分配 559.5 KiB、保留增长约 1.1 KiB，未新增 Frame/Region。同目标 100 次 Poll 的来源读取为 0。关闭后 timer、事件、键盘捕获、目标引用和报告均清理。禁用初态不创建 UI 或扫描，启用但未进入模式也不解析来源。替身不包含真实引擎内存/原生调用延迟；没有把这些结果换算成游戏帧率提升。

完整 tests/check_contract.ps1 通过；运行时 Lua 语法、XML 解析与 TOC 契约通过；wowdoc validate valid=true（48 个 Lua）；git diff --check 通过。实际输出见 addon-inspector-checks.txt、addon-inspector-wowdoc.json。图标已对照 settings/achievements 在 28/34/48 像素人工查看，预览见 addon-inspector-icons.png；原始 SVG 与导出脚本保留。

wowdoc source list/check：wow-ui-source / retail / latest，resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34，无上游更新。GetSourceLocation、GetMouseFoci、键盘透传、CVar 读写与插件元数据证据的 path/line/excerpt 分别保存在同名前缀 API JSON。GetSourceLocation 官方标记 SecretReturnsForAspect ObjectDebug，代码在使用返回值之前检查 secret。查询 enableSourceLocationLookup 名称本身无索引结果；该名称来自用户指定的已安装 WTFisThisAddon（StartWITA 第 534 行附近），仅客户端 C_CVar.GetCVar 明确返回值后才允许写入，未知/不可用时不提供按钮。只读取源码行为，不将父级关联推断为修改链。

加入两个 TOC 模块及一个新图标，按项目约定交付后需重启客户端。尚未执行真实客户端可见布局、动画、键盘优先级、不同 UI 缩放/多插件组合、战斗/团本帧时间验证。客户端全局来源记录的初始化与内存开销也待测；只在用户明确点击带“重载”的按钮后开启，其设置不会随模式退出而反复切换。回滚使用新的 git revert 并同步。
