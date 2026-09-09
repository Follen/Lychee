# 最近使用选中样式调整

日期：2026-09-10。基线提交：024b303。用户在实机截图中明确选择的问题是“图标与选中背景：像动作条按钮”。

移除图标周围 48 × 48 的方形选中底，复用原纹理作为名称下方 18 × 2 的红色短线。图标与文字相隔 8，名称顶部对齐；仅在名称变化时读取一次 GetStringHeight，将标题区域高度限制为 14–28，兼容一行/两行。图标、原有点击与拖动区域、鼠标/键盘共用选中状态保持原行为。PRODUCT.md 与 DESIGN.md 已同步。

验证：
- tests/check_contract.ps1：10 项全部通过，包含最近使用选中、施法、拖动和已有交互。
- 45 个 Lua 文件解析、Bindings.xml XML 解析通过。
- wowdoc validate：valid=true，checkedLua=30，diagnostics=null。
- 相同名称不重复测量或调整高度；没有新增 Frame、纹理、事件、timer 或 OnUpdate。
- git diff --check 通过。

查档 sourceId=wow-ui-source、product=retail、requestedRef=latest、resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。[本次来源](../architecture/2026-09-10-recent-selection-wowdoc.json) 保存 SetJustifyV（SimpleFontStringAPIDocumentation.lua:570）、SetSize（SimpleScriptRegionResizingAPIDocumentation.lua:163）、SetPoint（同文件:135）的 path/line/excerpt；GetStringHeight 证据沿用[同版本字体查档](../architecture/2026-09-10-ui-refinement-wowdoc.json)中的 SimpleFontStringAPIDocumentation.lua:325。[静态验证结果](../architecture/2026-09-10-recent-selection-validate.json)。

本轮仅有修改前实机截图。更新后的观感、真实字体高度、缩放与客户端性能仍待 /reload 后验证；离线测试不代替实机证据。提交成功后只同步 package/Lychee 的运行时文件并核对 SHA-256；无 TOC 变化，可 /reload 加载。回滚使用新 git revert 提交并按相同流程验证与同步。
