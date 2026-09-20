# 底栏留白

基线 8592474。局部样式调整：底栏 28 → 32，文字和线条左右统一 28，分隔线改为中性灰 0.5 alpha，整体高度上限同步 514 → 518。列表尺寸不变。Palette 从 Theme 读取顶底栏尺寸，避免主题与实际窗口计算分离。

成本：复用原有一个 Texture 和两个 FontString，无新增 Frame、订阅、timer、动画组或每帧工作。仅首次创建时应用常量；未改变搜索、身份和关闭生命周期。性能验收采用局部样式门禁，不宣称帧率或内存收益。

wowdoc SetPoint 证据见 2026-09-10-footer-api.json；sourceId wow-ui-source / product retail / requestedRef latest / resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34。完整契约检查、Lua 语法、XML 解析和 TOC 检查通过，wowdoc validate checkedLua=45 / valid=true，git diff --check 通过。原始契约日志见 2026-09-10-footer-checks.txt。

截图用于识别旧边距与分隔线问题；新样式未在游戏内渲染验收。重载后检查整体缩放、文字垂直留白、滚动条与分隔线的间隔。游戏 CPU/帧时间未测，静态样式不新增常驻路径。
