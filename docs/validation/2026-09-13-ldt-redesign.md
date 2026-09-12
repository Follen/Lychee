# LDT 详情布局重构验证 · 2026-09-13

## 改动与边界

重排身份、模型/技能浏览、技能说明三个层次，保留荔枝黑底、暖白文字、红色选中标记与原 Logo。复位使用现有 reload 图标（28 点击区域、20 图形），提示移入悬浮说明；特性使用现有 skull 图标。模型仍为 214×168，初始化镜头与拖动/缩放逻辑保持。

技能保持六组分页、最多八行复用及展开溢出滚动。列表图标为 24；说明区增加 28 图标，标题/元信息分层，正文行间距为 3，数字高亮和原始段落保留。常态内容高 392，展开八行高 430；长说明独立滚动。Shift 点击提示归入唯一 Host 底栏，不再重复显示泛用操作提示。底栏接受当前视图实例，限制 256 字节，Mount 失败不能发布临时提示。

无搜索、数据集或 SDK 公共接口变更。新增显示对象仅首次创建，复用旧媒体；无新增闲置定时器或动画驱动。退出清除当前描述、图标引用、提示和拖动状态。DESIGN.md、PERFORMANCE.md 及 SDK 性能文档同步更新。

## 验证

- `lua tests/ldt_provider.lua`：PASS；模块约 376.1 KiB，20 次查询临时分配约 1201.5 KiB，回收后增长 0，最大批次 5 ms，模型实例 1。该数据来自测试夹具，不代表客户端总内存。
- `lua tests/navigation_binding.lua`：PASS；覆盖底栏归属、关闭恢复、过期实例拒绝、长度边界，以及 Mount 失败后的底栏回滚。
- `pwsh -NoProfile -File tests/check_contract.ps1`：完整 contract PASS。
- Lua 语法检查：160 个运行时、SDK、测试文件 PASS；Bindings.xml 解析 PASS。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref latest`：88 个 Lua 文件，valid=true，无诊断。
- `python tools/build_sdk.py --write`：PASS。
- `python tools/build_release.py --check`：运行时 142 文件，SDK 26 文件 PASS。
- `git diff --check`：PASS。

## API 与审查

API 固定到 `wow-ui-source / retail / latest`，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。本轮 Texture:SetTexture 与 FontString:SetSpacing 的精确路径、行号和片段见同目录 `2026-09-13-ldt-redesign-api.json`。其余模型、滚动和聊天接口沿用本日 ldt-ui-api、ldt-layout-api 记录。

独立代码审查未发现确认的阻断问题；提出的失败 Mount 底栏回滚用例已补充并通过。独立文档核对确认 DESIGN.md 与实现尺寸、字体、布局和生命周期一致。

## 实机限制与交付

没有获得本轮新的 WoW 实机画面；原生字体、不同 UI 缩放、长标题、模型覆盖关系及面板高度动画仍需客户端验收。浏览器安全策略拒绝访问本地布局预览；已停止该预览，没有绕过，也未将预览当作实机证据。

运行时代码提交成功后同步到 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，逐文件核对发布清单和 SHA-256，保留已有额外文件。本轮无 TOC 或新增模块，客户端使用 `/reload` 验收。
