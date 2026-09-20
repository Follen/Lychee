# 冷却和光环控件的内部来源证据

基线 `68658cc`。此前只处理了额外 Tooltip，用户要求继续解决冷却管理器和 Debuff 未识别。原解析只看选中对象的创建记录、名称及父级创建记录；插件修改暴雪原生图标、在内部加显示层时，这条单向来源链不一定包含插件创建记录。

## 源码与回归

wowdoc source `ellesmereui` / product `main` / requestedRef `9.1.8` / resolvedCommit `271ffc30d3265d9f77746b0e15224d918f0fafcb`，source check 本地/远端一致。

- inspect `DecorateFrame`：`EllesmereUICooldownManager/EllesmereUICdmHooks.lua:2909`。注释说明重用 Blizzard icon-frame pool；`:2924` 为 `frame:CreateTexture(nil, "BACKGROUND")`。同版本本机代码 `:3096` 创建 `textOverlay`，`:3103` 创建其 FontString。这些内部对象由 EUI 创建，原图标可以仍是暴雪创建。
- 本机同版本 `EllesmereUI/EllesmereUI_AuraKit.lua:1006` 创建按钮内 icon；`:1012` 创建 cooldown，`:1024` borderHost，`:1049` stackCarrier，`:1053` 和`:1054`创建文字，`:1321`创建原生 AuraContainer。光环显示同样有原生框体与插件创建的内部对象。
- 新读取接口由 wowdoc inspect 验证：sourceId=`wow-ui-source` / product=`retail` / requestedRef=`latest` / resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`，`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:323` 的 GetChildren 返回多值 SimpleFrame，Hierarchy 可受限。现有 GetRegions/GetSourceLocation/透明度/可见性继续通过受限读取边界。

先添加集成回归模拟这两种实际源码结构，旧实现失败：`engine cooldown frame must expose the addon-created overlay without claiming addon ownership`。新实现通过：在保留原生 Frame 身份和原始创建位置的同时，关联到其内部 EUI 记录；光环按钮也能报告其内部图像来源。

这证明遗漏了一类实际存在的来源证据，不证明用户所有未识别对象都属于这一类；没有运行截图中客户端的当前对象，最终实际显示仍需确认。

## 行为及成本预算

仅目标变化并且自身/父级没有明确第三方创建来源时补查。范围为选中 Frame，或选中 Texture/FontString 的直接父级；拒绝 UIParent/WorldFrame/工具窗口。最多两层、64对象、每组32返回值、约1ms在对象边界让出；不扫整棵全局树、不查任意兄弟组件、不安装 hook/事件/timer、不创建 Frame/Region。

补查允许从空的原生控制框体关联到其已创建且显示状态有效的内部层，但不改变可见目标过滤：隐藏/全透明对象依然不能成为目标或关联来源。关联只代表内部控件创建证据，不代表整个框体归属或修改者。明确自身或父级创建来源优先，不被装饰覆盖；多插件最多保留3项，超限或时间/数量截止标记截断。

临时 visited/folder 集合上限64，结果上限3项，每项字符串使用既有512字符限制；只由当前分析调用所有。UI仅保留当前3项关联，切换/停止释放。创建位置保留原始选中对象的记录，复制报告补充关联来源文件，不冒充原始创建证据。

预算预先沿用100次开关分配<1MiB/增长<64KiB，增加来源补查约1ms边界预算，父级原有约1ms边界不变。单个原生调用不能抢占；Read GetChildren/GetRegions 多返回值的引擎成本不能由Lua循环上限完全约束。父级/内部来源总额外成本仅在换目标时发生，同目标不重复分析；关闭/战斗停止沿用原实现。

## 验证

专项通过：冷却文字层、光环装饰层；原生身份与原始位置保留；复制报告包含关联文件；同目标不补查；隐藏/全透明装饰不纳入；多个关联插件分别保留；明确原始创建来源优先；不扫描UIParent；64对象上限及截断标记。原Fstack、额外Tooltip抑制、空锚点、secret、复制、Shift、战斗、关闭与禁用回归通过。

初次模拟对象仍为9 Frame/35 Region、保留38.0KiB；100次开关累计240.1KiB（此前219.8KiB，因无明确来源的名称推断对象也进行有界补查）、保留增长0.0KiB，原预算通过。10,000次指针更新0分配、0来源读取。有效原生目标100次约2ms/0替身分配，备用列表100次约58ms/295.9KiB。均为离线数据，不作为实际客户端帧时间或原生分配证明。

实机待验：截图中的具体冷却图标和Debuff关联来源、原生创建记录可访问性、来源记录开关及动态生成层。没有可访问创建记录时仍应诚实显示未确定，不补插件名称表。回滚使用新git revert。

交付检查：完整 tests/check_contract.ps1 通过（含 Lua/XML/TOC、语言、交互及生命周期回归）；wowdoc validate checkedLua=75、valid=true、无诊断；git diff --check 通过。
