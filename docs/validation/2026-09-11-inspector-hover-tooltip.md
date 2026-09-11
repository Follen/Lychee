# 识别模式的额外悬浮 Tooltip

基线 `cda72b6`。用户明确指出截图中的额外 Tooltip；截图显示选中对象为 `GameTooltip.…`，属于公共悬浮提示的内部对象，不能仅凭截图把它认定为匿名取样窗口。此前隐藏取样父级只隔离自己的窗口，并未阻止普通 GameTooltip 与识别卡片同时出现、被 Fstack 再次选中。共享模板 OnHide 仅清 padding，没有找到它直接改写公共 Tooltip 的证据，不宣称已证明原生 SetFrameStack 造成公共提示滞留的内部原因。

## 行为与成本

保留原生 SetFrameStack、原对象身份以及隐藏/透明/空锚点过滤。识别期间暂时收起普通 GameTooltip，并排除它及内部对象。启动时收起已有提示，之后通过一个 OnShow 后置回调收起新提示；不用常驻轮询 Hide，不接管 Tooltip 所有者/父级/内容，不修改 EUI 或暴雪脚本本身，不重建、重显旧提示。

回调首次主动启用时懒安装，只成功安装后记住对象；之后重用，安装失败可在下次启动重试。关闭、禁用和战斗下立即短路。回调不能卸载，因此永久保留一条回调和固定引用，但停用不执行功能工作；无新 Frame/纹理/定时器/事件。OnShow 正在显示的对象直接用受保护调用 Hide，不依赖可能受限的 IsShown 值来决定是否隐藏。禁止访问对象跳过。仅在主动、脱战识别模式隐藏提示；退出后正常悬停自然恢复，不重新 Show 陈旧内容。

预定沿用原性能预算：100次开关累计 <1 MiB、保留增长 <64 KiB；Frame/Region数量不增加；10,000次指针更新不增加抑制工作；反复开关仅安装一个回调。原生 Fstack 的成本及旧有限候选预算不变。

## 版本证据

已用 wowdoc 查询；sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`，source check 本地/远端一致。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:328`，HookScript：RequiresAssignableScript，检查 ScriptBindings，参数 scriptTypeName、script，返回 success。使用后置回调并处理失败，不替换 OnShow。
- `Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua:380`，GameTooltip_OnShow：编辑模式下原生通过 `self:Hide()` 避免 Tooltip 层叠，`:387` 为具体 Hide 调用。这是 OnShow 隐藏的接口用法证据，不意味着本功能属于编辑模式。
- `Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua:22`，SharedTooltip_OnHide：ClearPadding/SetPadding；`:9`，OnLoad 调用 SharedTooltip_SetBackdropStyle。未见这里改写公共 GameTooltip。

## 回归

先增加“启动识别已有额外 Tooltip”的回归，旧实现失败：`starting inspection must dismiss the extra hover tooltip`。修复后通过：启动清理、活动中再次 Show、停止后正常 Show、GameTooltip 子对象原生快照排除、战斗入口不执行抑制、反复100次开关只安装一次 HookScript。既有空锚点/透明过滤、原生身份、取样异常、私有取样窗口隔离和退出均保留通过。

专项离线：初次9个模拟Frame/35个Region/保留38.0 KiB；100次开关约3 ms、累计219.8 KiB、保留增长0.0 KiB。10,000次指针更新约7 ms/0分配。原生首选100次约2 ms/0替身分配；备用128候选×100次约58 ms/最大2 ms/300.0 KiB/保留增长0.0 KiB。都是模拟器数据，不宣称真实客户端的原生 API 或 Tooltip 创建成本为零。

游戏待验证：截图里的额外提示不再出现、退出后普通单位/技能提示恢复、EUI后置回调与受限状态。冷却管理器和 Debuff 的完整归属识别仍是待验证问题，不把本次 Tooltip 修复当作该问题已解决。回滚使用新 git revert。

交付检查：完整 tests/check_contract.ps1 通过（含 Lua/XML/TOC 静态和功能回归）；wowdoc validate checkedLua=75、valid=true、无诊断；git diff --check 通过。完整回归中的生命周期预算及单回调检查通过。
