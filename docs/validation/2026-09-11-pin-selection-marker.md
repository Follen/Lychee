# 固定项选中标记

截图中「传送门：银月城」下方红线固定为 24 宽，锚定在标题的 28 高文本区域下方，长度与图标不一致，且会被误读为文字下划线。改为在图标下方间隔 2 放置 28×2 标记，与图标居中等宽；不依赖标题实际行数。

## 成本与生命周期

仅修改 AcquireTile / ConfigureLayout 的静态几何参数，复用 tile.bg。创建、选中、hover、动画、隐藏、条目重绑与最近使用切换行为不变。新增 Frame/Region、事件、timer、缓存均为 0；空闲与战斗没有新增工作，不测量无关搜索目录。

## 接口依据

wowdoc：sourceId `wow-ui-source`，product `retail`，requestedRef `latest`，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135`，`SetPoint` 参数声明摘录：`point: FramePoint, relativeTo: ScriptRegion, relativePoint: FramePoint, offsetX: uiUnit, offsetY: uiUnit`。锚定插件自身纹理，不修改受保护 Blizzard 框体。

## 验证

保持固定项 title 起点 -43；图标顶部 -8、底部 -36，标记占 -38 至 -40，标题区域从 -43 开始，因此单行和两行均无重叠。中英文共用这组锚点，不新增文字测量。静态与现有交互检查结果见交付报告。游戏实际缩放、视觉与鼠标/键盘切换仍待 `/reload` 后实机验证。

已执行：tests/check_contract.ps1 全套通过；wowdoc validate 检查 75 个 Lua 文件通过，无诊断；git diff --check 通过。
