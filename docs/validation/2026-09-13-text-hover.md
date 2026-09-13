# 文字悬停与返回图标修正

基线4034c79。截图暴露公共按钮把业务图标 `icon` 当成状态图形：技能图标在悬停时一起染红。修正为仅显式 `feedbackIcon` 参与颜色反馈；普通图文按钮只改变文字，技能原始贴图保持颜色。返回图形从28缩至20，38×30命中区保留；常态使用text暖白，hover/按下使用accentHover，离开恢复暖白。DESIGN.md同步此规则，无新增Frame、贴图、事件、计时器或持久数据。

回归先在旧实现上失败（技能图标发生染色），修正后通过。真实公共按钮的OnEnter/OnMouseDown/OnLeave/OnHide验证业务图标零SetVertexColor调用；显式导航图形保留颜色反馈。Host导航测试验证暖白→荔枝红→暖白及返回搜索状态。补齐Frame替身SetVertexColor方法，避免主题写入被替身缺失接口跳过。

`python tests/run.py --report analyze/tests/text-hover-final.json`：全量93/93通过，包含Lua/XML/TOC静态检查、SDK/业务/UI/交付与性能。最近使用100轮241ms、峰值4ms、0新Frame、无保留内存增长。原冷加载与其他性能门槛未改。Host wowdoc validate：44个Lua文件，无诊断；git diff --check通过。

API证据：sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua:191`，excerpt：`Name = "SetVertexColor"`；参数colorR/colorG/colorB为必需number，alpha可选。沿用现有Theme接口与战斗限制，只改变接收颜色的显式图形。精确inspect保存在本地analyze/tests/hover-text-api.json。

20尺寸的暖白/红色实际贴图离线预览已检查。未进行游戏实机渲染验证；提交后按五包发布清单同步180文件并校验SHA-256，保留旧文件。只有已加载Lua变更，游戏内/reload生效。
