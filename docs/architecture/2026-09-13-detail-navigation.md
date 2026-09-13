# 详情导航与自有菜单

用户实机截图表明此前菜单圆角未生效。只读检查已安装 EllesmereUIBlizzardSkin.lua:809–853：其 `_menuSkinFrame` 将原生菜单所有非自有 Texture 替换为矩形并调用 `_applyConfiguredBorder`，OpenContextMenu 后还安排0、0.05、0.15秒三次处理。直接调用 Lychee menuMixin.Generate 的旧测试未覆盖这条链路。

菜单改为 Components 延迟创建的独立 UIParent 浮层，不进入原生 Menu manager；不用皮肤竞争、轮询或改写其他插件。一个根 Frame、最多18个复用按钮；协议16动作加别名/固定。沿用 Executor 的身份、会话、查询代次与安全动作准备校验。普通动作仍须真实按下/点击，安全动作仍只准备原有安全按钮。关闭清空回调、owner和锚点，查询、导航、owner隐藏、窗口关闭和战斗清理。沿用 Palette 的外部鼠标事件，不增加空闲事件或定时器。

Host 顶部右侧在搜索态显示 Esc，在所有自定义详情与设置态显示圆圈左箭头，点击返回保留搜索词。图标源 assets/back-search.svg，tools/build_navigation_icon.py 输出64×64 RGBA贴图；同一按钮状态管理文字与图标颜色。LDT移除自身返回和特性字段，模型264×304，行高36/图标32，内容392高，八行复用。底部阅读面板及其滚动控件删除；技能提示使用公共400宽 tooltip，超长正文按需创建滚动区并由悬停技能滚轮驱动。数据迟到只更新当前悬停，卸载清理资源。

成本：冷加载不创建菜单或长文阅读 Frame；首次菜单按实际动作扩展到协议上限后复用。LDT删除特性、返回和独立阅读区释放控件。保持 PERFORMANCE.md 原有冷加载、复用、交互和资源门槛，完整回归与版本化 API 验证后交付；离线证据不替代真实字体、模型、缩放及战斗 taint 验收。

版本证据：sourceId=wow-ui-source，product=retail，requestedRef=12.1.0，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

- Interface/AddOns/Blizzard_Menu/MenuUtil.lua:145–161：原生入口从owner读取menuMixin，然后使用Menu manager打开。此次移除该依赖。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/InputDocumentation.lua:20–27：GetCursorPosition返回posX/posY；浮层按有效缩放转换锚点。
- Frame/Region的SetScale、SetClampedToScreen、SetParent、SetScrollChild沿用版本化定义，仅操作自有普通UI，战斗时禁止打开。
