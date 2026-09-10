# 功能来源与管理页交互统一

基线 f44d764。修改只涉及设置 UI、中英文文案和 DESIGN.md；ProviderPolicy、协议、查询路由、索引与 SDK 不变。

列表沿用搜索结果网格和虚拟行池，增加明确管理入口和中性悬停，功能说明替代重复操作提示。二级页替换一级导航，使用带说明的纵向选择项、固定操作区；选中标记不随悬停消失。前缀与恢复默认均为草稿，保存提交，取消丢弃；启停即时生效且不覆盖草稿。中文示例优先中文前缀，声明顺序保持原样。

成本与生命周期：只在打开设置、点击、输入和滚动时工作，无新增事件、ticker 或空闲 OnUpdate。一个懒创建二级页，固定三项选择与按钮，复用列表可见行；关闭停止拖动、页面动画并清理焦点和绑定。沿用 PERFORMANCE.md 的 UI 预算，不改阈值。1000 来源、400 可视高度仍为 8 行；20 次二级页重开无新 Frame。基线列表 20 次刷新分配 37.4 KiB；本轮保持 37.4 KiB，池增长 0，常驻 458.0 KiB，首次 2 ms（离线单轮，非实机帧率结论）。增加有限按钮/纹理成本，用于明确导航及选择状态。

完整 `tests/check_contract.ps1` 通过（`.codex/provider-ui-final.txt`）。之后新增说明与示例显示调整，再运行 `tests/interaction_smoke.lua` 通过（`.codex/provider-ui-confirm.txt`）。新增断言覆盖：二级导航替换、未修改保存禁用、输入启用保存、启停保留草稿、取消恢复导航及丢弃草稿、恢复默认保存前不生效。原有过期点击、注销、独立查询与复用检查继续通过。Lua/XML/TOC 与 diff 检查通过。

wowdoc：sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:915–925`：SetTextInsets(left, right, top, bottom)，四个参数为 uiUnit。沿用已验证的 Frame、EditBox 和共享 UI 组件。validate：71 Lua，valid=true，无诊断（`.codex/provider-ui-wowdoc.json`）。

视觉核对依据用户截图和源码布局：统一宽度、行高、图标起点、字体、外侧红色滑块；正文高度与固定操作区分开，错误替换次要版本信息不叠字，独立查询隐藏无效选项。Impeccable layout 扫描无报告；它不能验证 WoW 原生像素。未实机验证缩放、英文长标题、鼠标焦点、动画和战斗场景，不将离线通过视作实机通过。无新增加载模块，交付后用 `/reload` 验收。
