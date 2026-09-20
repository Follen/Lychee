# 成就目录与背包定位修复

前版本 dbaf7fe。用户报告启用成就但搜索“引领潮流”无结果，以及右键定位背包后搜索框为空仍持续过滤。

背包原因确定：旧 locate 调用 C_Container.SetItemSearch(name)，未恢复，第三方输入框没有同步该状态。现在只在显式定位时清空全局过滤，绝不设置物品名称过滤；不安装任何背包 hook。Ellesmere 与 ElvUI 同时清除自己的搜索输入。暴雪使用 ContainerFrameUtil_GetItemButtonAndContainer；ElvUI 读取 Bags 模块 BagFrame.Bags[bag][slot]；NDui 读取命名实现 NDui_Backpack:GetButton；Ellesmere 9.1.7 的私有匿名按钮池按 _scrollChild 下的格位父框/物品按钮两层查找，按原生 bag/slot 核对 itemID，兼容堆叠后的代表格位。Ellesmere 显式切所有物品、刷新一次，再通过 _scrollFrame 滚动到目标。

只读取现有控件，不创建第三方控件，不递归扫描全 UI。Ellesmere 单次最多枚举 2,048 个顶层子框、每父框最多 16 子框、累计检查最多 1,024 按钮；其余适配器直接取格位。第三方 RefreshInventory 是同步外部代码，无法抢占或保证其成本；仅右键定位调用一次，记录为游戏内待测成本。折叠/隐藏且无法取得可见格位时明确提示展开分类，不宣称定位成功。

高亮继续复用 1 Frame/5 Texture、一个 3 秒 timer；隐藏、背包变化、战斗、停用均清理；空闲无 OnUpdate/ticker/hook。原生定位 100 次离线分配 63.3 → 47.7 KiB，回收后未观察到保留增长，粗粒度计时 0–1 ms。这组数字不代表 Ellesmere 刷新成本；该路径另有两层临时子框列表，容量如上，只存活于一次点击，没有常驻缓存。未更改任何性能门槛。

成就查档发现暴雪按 GetCategoryNumAchievements(category) 枚举，与旧版 includeAll=true 不同；系列前后级仍独立遍历。模拟“includeAll 数量包含不可枚举索引”时，旧实现抛 Invalid achievement index，整份 ids 不提交，确定复现启用后无目录；修正后完整 QueryOrchestrator 搜索找到“引领潮流”。此为已证实的失败路径，尚无用户游戏内 lastError，不能断言其截图唯一根因。新增 ACHIEVEMENT_EARNED 低频事件重建，处理获得后新出现的光辉事迹；继续默认关闭、32 checkpoint/约 1 ms 构建让出，关闭后注销事件，战斗暂停。没有增加 criteria 高频订阅。

tests/bag_actions.lua 覆盖四套实际源码结构、无名称过滤、定位滚动、清理和物品安全动作；tests/achievements_provider.lua 对分类数量差异红→绿，真实搜索入口、获得事件、系列完整性通过。完整 check_contract PASS，Lua/XML 检查通过，wowdoc validate 46 Lua / valid=true，diff 检查通过。原始日志见 provider-fixes-checks.txt。

版本证据保存在 provider-fixes-api.json：wow-ui-source retail latest 8ea15b61e45c0ed4eba01439c90757f86eb78d34；Ellesmere 9.1.7 3860a8d5b7a31d7c9b989a7654bf1554961a678e（与已安装版本一致）；ElvUI 本地 latest fdc08aaefc7c0810af685404d43b8ccfade8c497、NDui 本地 latest c198b6f0fb39dfac2a9bea85a0c7c76ad540c8d2，后二者 source check 提示远端有更新，未声明覆盖未来所有版本。相应路径与行号包括 ElvUI Bags.lua:677/679、NDui implementation.lua:280、EllesmereUIBags.lua:295/2596/2990/5515。未修改其他插件文件。

游戏内待验证：四种界面/分类折叠/滚动/堆叠的描边、战斗 taint、第三方同步刷新峰值、用户“引领潮流”的真实查询。无新增 TOC 模块，交付后 /reload，下一次定位会清空之前残留的过滤。回滚采用新 git revert 后同步。
