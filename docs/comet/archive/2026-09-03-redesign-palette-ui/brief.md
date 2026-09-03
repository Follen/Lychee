# Outcome

把目前接近“横向黑色输入框”的 Lychee Palette 重做为完整、清晰、可重复操作的 WoW 内命令工作台。空输入和搜索输入都必须有稳定的信息结构，玩家能快速识别类别、实体、来源和可执行动作，同时保持现有搜索、SDK、战斗与性能合同不变。

# Scope

- 重做 `Palette`、`Input`、`ResultList` 和 HomeView 的视觉结构与交互状态。
- 空输入展示分组 HomeView：最近使用、已固定、类别入口、第三方来源。
- 非空输入展示完整 SearchView：类别标签、图标、标题、描述/副标题、来源、命中提示和有限动作槽。
- 建立轻量 UI token/theme 模块，集中管理颜色、尺寸、间距、字体对象和状态色。
- 补齐正常、悬停、键盘选中、按下、禁用、空状态、无结果和 Panel 切换状态。
- 保持 Logo/品牌位、Locale 文案、键盘和鼠标操作一致。
- 更新正式 UI 架构文档、测试和第三方可见的 Presentation 说明。

# Non-goals

- 不修改搜索评分、索引协议、Provider/Command/SearchSource 分层或 SDK 注册方式。
- 不新增第三方自定义结果行布局、任意 Frame 注入或第二个根窗口。
- 不改变 `Alt + Space`、战斗中禁用、真实硬件点击和法术拖拽的安全策略。
- 不把 Palette 改成全屏、网页风格启动器或需要常驻动画的装饰界面。
- 不新增独立设置页、插件市场、安装器或新的内置业务 Provider。
- 不在本 change 完成真实客户端的像素级视觉定稿；字体、裁切、层级和整体观感在后续 UI change 中结合游戏内截图继续调整。

# Acceptance examples

- A1：脱战按 `Alt + Space` 后出现居中的完整 Palette 容器，而不是只有一条黑色输入框；窗口在常见 16:9 和超宽屏上不超出 UIParent。
- A2：空输入时按“最近使用 / 已固定 / 分类 / 扩展来源”分组显示内容；无数据分组使用克制空状态，不用假数据填充。
- A3：输入“红玉”后，搜索结果在同一面板内显示技能类别、图标、技能名、传送描述、来源/命中信息和可用动作，不退化成无层级下拉列表。
- A4：键盘上下选择、鼠标悬停、当前选中、点击、Enter、行内动作和拖拽区域都有可区分且稳定的视觉状态；鼠标离开不会清除键盘选中态。
- A5：结果标题、中文长描述、英文长词和最多四个动作在固定行尺寸内不重叠、不越界；次要信息可截断但主标题和主动作保持可用。
- A6：空查询、无结果、查询刷新、Extension 失效、战斗关闭和 ViewHost Panel 切换不会留下旧行、旧选中高亮或可点击的过期动作。
- A7：UI 颜色不再是单一蓝黑色；以石墨中性色为主体、暖白文字和克制荔枝红作为主强调，并为技能、任务、副本、成就、插件类别提供可区分但低饱和的辅助色。
- A8：Palette 隐藏时没有常驻 `OnUpdate`；行、Tile、动作按钮和装饰纹理预创建复用，输入变化不创建 Frame、不重建静态样式。
- A9：现有搜索、Intent、Panel、secure-spell、drag、recent/pinned 和第三方 fixture 测试继续通过。
- A10：所有新增/修改的 Frame、Texture、FontString、Atlas、事件与 API 先经 Retail wowdoc 查证，并通过 `wowdoc validate`、Lua 语法、专项 UI smoke、合同检查和 `git diff --check`。

# Constraints and invariants

- 采用 Operate 模式：扫描效率、层级、稳定尺寸和原生交互优先于装饰。
- 主窗口为固定基准尺寸并根据 UIParent 可用区域做有界缩放；字体不随 viewport 连续缩放。
- 不使用常驻动画、模糊、渐变球、过大圆角、卡片套卡片或无法由 WoW Frame 稳定实现的网页效果。
- 所有 setter 使用创建期初始化或 change guard；动态刷新只改文本、图标、显隐和必要状态色。
- `PaletteController`、`SearchSession`、`ResultActionExecutor`、`ViewHost` 和 `SecureActionBroker` 的现有所有权不变。
- 运行时代码必须在 Git commit 成功后才复制到正式服 `...\AddOns\Lychee`，并对比完整运行时文件清单与 SHA-256。

# Decisions

- 视觉方向采用用户已确认的 ZTools/uTools 工作台结构，但转译为 WoW 原生、紧凑、低干扰的操作面板，而不是复刻桌面应用。
- Palette 采用三段结构：品牌/搜索头部、Home/Search 主内容区、轻量状态底栏；ViewHost 在同一内容区替换主视图。
- HomeView 使用分组而非当前扁平 Tile 流；Recent/Pinned 显示真实实体，类别和第三方来源是导航入口。
- SearchView 使用单列高信息密度结果卡，不使用两列结果网格；这样长中文描述、来源、动作和拖拽区域拥有稳定空间。
- 颜色使用石墨、暖白、荔枝红和少量类别色；去掉现有大面积蓝色选中底，改为左侧强调条、轻背景和清晰焦点描边。
- 输入框去掉 `InputBoxTemplate` 的旧式边框，改为 Host 自绘搜索容器；保留标准 EditBox 行为、IME、焦点和 Esc。
- 动作按钮优先使用 WoW 已验证 Atlas/Texture 与 tooltip；没有可靠图标时使用短文本，不用难懂符号。
- 本 change 不要求生成位图视觉资产；品牌 Logo 若仓库缺失则先使用文字标识，不凭截图重新描摹不可追溯资产。
- 本 change 先归档已完成的结构、交互和性能基线；真实游戏截图与主观视觉打磨转入后续独立 UI change。

# Open questions

- 无。

# Verification expectations

- 使用 wowdoc 记录 Retail source、ref、resolved commit、API/XML 路径与 excerpt。
- 增加可在 Lua fixture 中检查的几何、显隐、状态切换、对象复用和长文本边界测试。
- 复跑现有全部 smoke 与 `tests/check_contract.ps1`。
- 通过 Dev AddOn 在游戏中验证 `Alt + Space`、空输入、搜索“红玉”、键盘选择、点击、拖拽、Esc、进战关闭和脱战恢复。
- 游戏内截图和独立视觉 reviewer 验收留给后续 UI change，不作为本 change 的归档门禁。
