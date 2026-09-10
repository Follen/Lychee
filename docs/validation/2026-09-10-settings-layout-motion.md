# 设置页共享尺寸与动画开关

基线：4fd2b14。设置页原有 580 宽、46 连排、430 内容高度与搜索/最近使用不一致，滚动条附着内缩视口。改为 Theme 共享 592 × 46 / 6 间距，整体宽 640、最大高 514；标签包含在 410 内容预算内，滚动条独立外缘槽。移除逐行横线。

Components.CreateToggle 复用圆角表面；32 × 18 底座、14 滑块。Motion.Slide 用原生 Translation OUT 和 180 ms Alpha。点击更新、隐藏收尾、换绑即时应用；同状态刷新不重播。动画组属于 Motion 的 96 组固定上限，与 Alpha 共用容量；不新增事件、timer 或 Lua OnUpdate。静态结构由可见行拥有，关闭保留可复用对象并清除身份，隐藏/换绑停止动画。

API 证据：sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimTranslationAPIDocumentation.lua:24–32 定义 SetOffset(offsetX, offsetY)，见 settings-motion-api.json；其余 AnimationGroup/Alpha/Frame 证据沿用 2026-09-10-motion-native-api.json 等前次记录。

离线同入口 Lua 5.1 / 1,000 来源 / 400 高视口：基线 9 行、180 替身对象、446.7 KiB 保留、20 刷新 42.4 KiB；当前 8 行、322 替身对象、427.1 KiB 保留、20 刷新 37.4 KiB，池增长 0。冷启动均约 1 ms，20 刷新基线 19 ms、当前 19–20 ms（单次粗粒度采样，不宣称 CPU 改善）。圆角结构增加固定 Region 数量，行距减少可见行数量；替身堆差不代表游戏引擎内存下降。

真实组件 2,000 次切换累计临时分配 0.00 KiB、动画组增长 0；覆盖原生进度中途反向、即时重绑、隐藏停止、减少动态效果落位和容量上限。设置页旧按下/重绑/松开及正常点击测试通过。

验证：完整 check_contract.ps1 PASS；所有运行时 Lua 的 luac -p、XML 解析、TOC 契约检查 PASS；wowdoc validate 45 Lua / valid=true；git diff --check PASS。原始日志见 2026-09-10-settings-ui-checks.txt 和 settings-ui-wowdoc.json。

未完成游戏实测：不同 UI 缩放的滚动槽与圆角渲染、连续点击视觉连续性、战斗关闭、真实 Frame 内存与帧时间。此次不增加常驻驱动，登录/空闲/团本帧时间未实测，不能把离线通过当实机通过。回滚采用新的 git revert 提交后同步。
