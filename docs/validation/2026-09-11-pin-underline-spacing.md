# 固定项红线间距与长度

保留用户明确选择的名称下方红线设计。撤销未提交的底色/名称变色方案，只修正 82c2321 将红线移到图标下方的错误方向。

## 几何与生命周期

短线重新锚定名称 BOTTOM，向下 3，厚度 2；名称宽度乘 0.5 后取整并限制在 16–36。单行/两行文本区域按 GetStringHeight 收敛在 14–28。布局从最近使用换回固定项时，即使名称相同也重新计算，避免 ConfigureLayout 的 28 高度覆盖先前单行测量。

原有颜色、透明背景、名称颜色、选择、hover、动画、点击与拖动保持原样。复用 tile.bg；新增对象、驱动、事件、timer 均为 0。仅名称或布局改变时测量，不在鼠标选择热路径测量；每个现有 tile 增加一个短暂 dirty 标记，完成绑定后清除。

## 接口依据

wowdoc source list/source check 后查询；sourceId `wow-ui-source`，product `retail`，requestedRef `latest`，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135`：SetPoint 接受 point、relativeTo、relativePoint、offsetX、offsetY。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:339`：GetStringWidth 返回 width，类型 uiUnit。
- 同文件 `:325`：GetStringHeight 返回 height，类型 uiUnit。

## 验证

完整 tests/check_contract.ps1 通过；wowdoc validate 检查 75 个 Lua 文件通过，无诊断；git diff --check 通过。相同名称在固定/最近布局复用的回归：旧实现从 15 高变为 28 高而失败，新实现恢复原测量高度并通过。图标与文字位置不变；最长两行时线底为 43+28+3+2=76，位于条目底边以内。

游戏内字体、缩放和最终观感仍需 /reload 后确认，离线检查不视为实机视觉验收。
