# Lychee Palette UI

> 历史规格：保留已归档 change 的设计快照，包含当前已移除或调整的接口，不作为 SDK 1.0.0 或当前运行代码的实现要求。现行入口见 [架构](../../../ARCHITECTURE.md)、[设计规范](../../../../DESIGN.md) 和 [SDK](../../../../lychee-sdk/README.md)。

## 1. 产品角色

Palette 是 Lychee Host 唯一的根搜索窗口。它承载空输入 HomeView、非空 SearchView 和 Extension Panel ViewHost，但不拥有搜索 generation、动作路由或业务数据。UI 只绘制 Host 已接纳的状态，并把输入、选择、动作和拖拽事件交给现有控制模块。

## 2. 视觉与信息架构

Palette 使用紧凑的三段式工作台：

1. Header：品牌标识、搜索图标、无模板 EditBox 和必要的关闭控制。
2. Content：HomeView、SearchView、无结果状态或 ViewHost 中任一状态，同一时刻只有一个可见。
3. Footer：只显示当前结果/来源等状态信息，不显示功能教程或键盘快捷键说明。

基准窗口约 720x500 UI 单位，并在 UIParent 可用区域不足时进行有界整体缩放。窗口保持屏幕居中，不随结果数量改变尺寸。背景为石墨中性色分层，主文字使用暖白，荔枝红只用于品牌、当前选择和主动作；类别使用低饱和辅助色。边框、分隔线和焦点轮廓使用稳定 1px 视觉重量。

## 3. Header 与输入

- EditBox 保留 WoW 原生文字输入、IME、左右移动、Enter、Esc 和焦点行为，但不使用 `InputBoxTemplate` 外观。
- 搜索容器拥有明确焦点态；无焦点、悬停、聚焦和禁用状态可区分。
- Placeholder 使用 Locale 文案，输入文字与前后图标/按钮保持固定 inset，不互相覆盖。
- Header 高度固定；输入变化不改变窗口几何或创建新对象。

## 4. HomeView

HomeView 按以下顺序组织真实数据：

1. 最近使用；
2. 已固定；
3. 分类入口；
4. 第三方 Extension/SearchSource 入口。

每个分组有紧凑标题和稳定网格。实体 Tile 显示图标、标题和类别/来源；导航 Tile 显示类别或 Extension 名。无数据时显示占位行但不伪造实体。Tile 预创建并复用，Hover 与键盘焦点不会改变几何。点击实体把 canonical title 写入输入并进入 SearchView；点击类别/来源走 Host 的过滤或查询入口。

## 5. SearchView

SearchView 使用单列结果卡。每行的优先级为：

1. 类别 badge 与图标；
2. localized title；
3. description/subtext；
4. source 和轻量 evidence；
5. 最多四个声明式动作槽和可选 spell drag 区域。

行高和动作区宽度固定。长文本使用单行截断或受控两行，不与 badge、图标和动作重叠。没有图标时文字左边界仍稳定。选中态由左侧荔枝红强调条、轻背景和焦点轮廓共同表达；Hover 只增加轻微明度，不覆盖键盘选中态。动作按钮拥有 default、hover、pressed、disabled 状态与 tooltip。

## 6. 状态模型

- 空输入：HomeView 可见，SearchView 和 ViewHost 隐藏。
- 非空输入且有结果：SearchView 可见，按当前 session/generation 更新池化行。
- 非空输入且无结果：显示 Host-owned 空状态，所有旧行和旧动作隐藏并清空绑定。
- Extension/source 失效：对应行立即失效，选中位置收敛到仍可用行。
- Panel transition：Content 切换到 ViewHost，Header 保持可用；返回后恢复当前查询结果，不创建第二个根窗口。
- 战斗：沿用严格策略关闭 Palette，清除焦点并终止待处理查询。

## 7. 性能合同

- Palette 隐藏时没有常驻 `OnUpdate`、动画或轮询。
- Frame、FontString、Texture、结果行、Home Tile 和动作按钮在创建期或受控扩容时建立，按键查询只复用。
- 静态样式只在创建时应用；动态更新使用 applied value guard。
- HomeView 只在打开、recent/pinned 改变或 source 生命周期改变时重建数据投影，不在每次按键时扫描完整索引。
- 搜索结果 diff 只更新改变的行和状态，不重建 Palette 或 ViewHost。

## 8. 兼容与所有权

- SearchSession 继续独占 session/generation、防抖、取消和结果接纳。
- ResultActionExecutor 继续独占动作校验与 Intent/Panel/drag/secure 分派。
- UI 不读取第三方函数，不暴露安全按钮，不允许第三方自定义根 Frame 或结果行布局。
- SearchRecord、Command item、第三方 fixture 和现有 Presentation 数据形状保持兼容。
- `Alt + Space`、Esc、进战关闭、脱战恢复、真实鼠标点击和拖拽安全合同不变。

## 9. 验收与验证

- 离线 UI fixture 覆盖 Home/Search/Empty/ViewHost 状态、键盘选择、Hover、长文本、多动作、拖拽显隐和对象复用。
- 现有 smoke、interaction、search session、command catalog、capability broker 和合同检查全部通过。
- Retail wowdoc validate 通过，且新增 API/Atlas/Frame 使用有精确查档证据。
- 真实客户端的像素级视觉、字体裁切和整体观感由后续 UI change 结合游戏内截图继续验收，不作为本规格归档门禁。
