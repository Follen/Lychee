# Provider 管理：按项编辑

基线：d90f08a。范围：ProviderSettings、英文文案、设计约定和交互回归；搜索策略、Provider 协议与 SDK 不变。

## 问题与结果

旧页面同时存在取消编辑、页面取消与页面保存，输入框展开后未修改时无法用保存结束。添加入口使用整句动作文字，当前用途与修改操作分散。新版使用三个稳定设置行；未配置和已配置保持同样层次；前缀与列表关键词各显示准确输入示例。每次仅编辑一项，就地保存／取消，取消、返回不写配置，未改也可结束编辑且不创建覆盖。两个开关即时生效；字段保存从策略读取其他已生效配置，避免覆盖编辑期间的开关变化。恢复默认直接应用，失败不清空草稿。

所有入口沿用宿主宽度、主题、字体与外侧红滑块；透明按钮只改变文字状态，保存为主文字色。版本与兼容性折叠。没有页面底部的第二对保存／取消。

## 成本与生命周期

低频设置页操作，首次进入懒创建、固定两个词表编辑区及按钮，随后复用。无新增事件、timer、OnUpdate。输入上限400字节；正式词表仍由策略限制8个词、每词48字节。布局键仅含独立入口、编辑项、展开信息和错误存在状态，连续普通输入不重复几何设置。关闭清焦点、停止滚动拖动并失效身份；保存、编辑重开、来源重绑均防旧按压提交。战斗下 current() 拒绝动作。

## 验证

- 完整 `tests/check_contract.ps1`：通过，包含 Lua/XML/TOC、i18n、搜索正确性及性能预算。
- interaction_smoke：覆盖取消不写入、未改完成、返回丢弃、即时开关保留输入、字段保存保留开关、移除最后入口失败、失败开关保持生效配置、恢复默认、旧点击失效、独立入口、关闭清焦点。20次打开并编辑取消，Frame 池零增长。
- 固定1000来源列表预算：8行、356替身对象、458.0 KiB保留、20次刷新37.4 KiB分配、池增长0。此数据测一级列表，不冒充二级页引擎成本。
- 固定2689记录搜索：7261.5 KiB常驻、48次查询1814.1 KiB分配、保留增长0.1 KiB，与基线一致；无搜索引擎改动。
- wowdoc validate retail：71 Lua文件，valid=true，无诊断。
- git diff --check：通过。
- 原始日志：`.codex/provider-local-full.txt`、`.codex/provider-local-interaction.txt`、`.codex/provider-local-validate.json`。

## API 依据

sourceId=wow-ui-source；product=retail；requestedRef=latest；resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:915–925`：`Name = "SetTextInsets"`；参数 left/right/top/bottom 均为 uiUnit。通过 source list/check 和 query 核对；原始证据 `.codex/provider-local-api.json`。

## 实机待验

当前无法操作游戏客户端。本轮截图是用户提供的旧实现，不能作为新界面验证。待 `/reload` 后检查中英文、不同UI缩放下的换行与对齐、鼠标悬停、Enter/Esc、错误显示位置与滚动。离线替身不证明像素渲染、受保护事件或实机帧时间。登录／团本等场景无新增驱动，本轮未做实机性能测量。
