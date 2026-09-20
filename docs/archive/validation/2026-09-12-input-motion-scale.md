# 搜索输入文字在开关时抖动

用户截图指出搜索占位文字/光标在主面板开关时抖动。基线 7fbd687。检查确认整个输入容器直接继承主面板 84%–100% 的逐帧缩放，EditBox 与 FontString 的有效字体尺寸随动画变化；焦点事件只改变颜色，没有修改位置或字号。测试在旧实现报 `search text must keep its effective font scale during opening`。

修复让现有输入容器 SetIgnoreParentScale(true)，有效缩放显式保持为 UIParent:GetEffectiveScale() × 面板最终适配比例。占位文字、EditBox、光标和放大镜共用该容器，锚点和透明度继续跟随面板。外壳开关动画的幅度、位移和时长不变。

成本与生命周期：不新增框体、事件、timer、OnUpdate 或逐帧回调；创建时设置一次，ApplyBoundedScale 中在最终 UI 缩放改变时更新，重复值跳过 setter。战斗期间直接返回，成功设置后记录状态。不通过隐藏输入、延迟焦点或改动实际查询修复视觉问题。

针对性验证：

- 实际 Input 与 Palette 路径下，开场及关闭各 8 个采样点，EditBox/占位文字有效尺度保持不变。
- UIParent=0.75、面板适配=0.8 时，输入有效尺度为 0.6；同值刷新不重复设置。
- 战斗时不修改输入缩放。保留失焦 Esc、减少动态效果、完整开关、连续反向与安全动作测试。
- 验证入口 tests/interaction_smoke.lua 和 tests/check_contract.ps1；完整日志 `%TEMP%/lychee-input-motion-scale-check.log`。运行时 77 Lua 经 wowdoc 校验；提交前 diff 检查。

API 来源：wow-ui-source / retail / latest，commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`，source check 无更新；SetIgnoreParentScale 与 GetEffectiveScale 精确证据见 [wowdoc 记录](2026-09-12-input-motion-scale-wowdoc.json)。SetScale/锚点沿用既有接口证据。

离线测试证明输入不再继承动态字体缩放，不能证明所有实际像素抖动均消失。没有在游戏内录制/观察字体栅格化；同步后 `/reload`，检查空输入、已有查询文字、光标、中英文、不同 UI 缩放及快速开关。未修改 TOC。
