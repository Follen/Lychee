# 保留 Fstack 原生对象身份与可见过滤

## 问题与修复边界

用户指出最初 `4de68c2` 的 Fstack 版本能识别，而 `638dd17` 出现更多“未确定”，并明确要求保留过滤。对比确认：Analyze 来源解析没有改变，但取目标从 `SetFrameStack(false,true,0)` 的原生选中对象，变成了 C_System 列表重新排序；检查 Frame 的可见内容时又把 Frame 替换成了内部 Region。

可重复回归：原生选中 `Example_Surface`，它本身有插件名称依据，内部是没有名称和创建位置的 Texture。旧代码在 `lua tests/addon_inspector.lua` 失败：`native highlighted frame identity and its addon-name evidence must survive visual filtering`。该对象替换缺陷已复现；它不证明用户每一个未确定对象都由同一原因导致。

修复恢复原生选中对象优先；通过过滤后原样交给 Analyze，Frame 不变成内部 Region，原生选中 Region 也不强行变成父级。只有选中对象隐藏、透明、空锚点等不能通过过滤时，才使用原生列表寻找可见候选。备用列表也保留候选本身身份。过滤、来源证据优先级、来源不明确时的诚实文案保留。

## 生命周期与成本

设计时限定：仅主动识别且脱战时，每 0.1 秒一次 SetFrameStack；有效原生选择不查询备用列表。仅无效选择触发一次 C_System.GetFrameStack，备用列表检查上限 128、每 Frame 32 个 Region、父级 16 层、约 0.75 ms 后让出。没有全局枚举、没有新增常驻 hook；Shift/复制/关闭/禁用/战斗沿用停止语义。

本次比 `638dd17` 多一个隐藏父级与匿名取样 GameTooltip，首次使用创建后复用。取样的 owner/parent 都是始终隐藏的私有父级，取样后清行并隐藏；延迟换肤即使重新 Show/SetAlpha，也因父级隐藏而不可见。公共 GameTooltip/FrameStackTooltip 不读写，Fstack 配置不修改。取样时暂时隐藏自己的轮廓，取样结束或异常后恢复，避免原生选中轮廓。禁止新建每次取样对象，停止后保留这两个 Frame 供复用，不把 Hide 说成销毁。

预算沿用现有初次识别 <16 个模拟 Frame/<48 个模拟 Region、初次保留 <512 KiB，100 次开关累计 <1 MiB/保留增长 <64 KiB；备用 128 候选 ×100 次 <1 MiB/增长 <64 KiB。新增原生取样窗口内部的真实文字行、模板美术对象、原生调用时间无法由离线替身证明或按 Lua 候选上限约束；客户端开销、Tooltip 共存仍待验证，不据此声称零对象或零引擎分配。

## wowdoc 证据

sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`；source check 返回 local/remote 一致。恢复旧调用前查以下符号：

- `Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.lua:133`，FrameStackTooltip_Show：`self:SetOwner(UIParent, "ANCHOR_NONE")`、`self:SetFrameStack(showHidden, showRegions)`。
- 同文件 `:228`，OnUpdate 中 `:234`：`self.highlightFrame = self:SetFrameStack(self.showHidden, self.showRegions, self.highlightIndexChanged)`；返回对象用于原生高亮。
- `Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.xml:95`：SharedTooltipTemplate 为 GameTooltip，`hidden="true"`；OnLoad/OnHide 使用共享模板生命周期。
- 可见性、父级裁切、矩形、纹理检查沿用 [原生列表过滤记录](2026-09-11-inspector-native-stack-filter.md)。

本机 EUI BlizzardSkin 的 `_ttSkin` 会创建/重新 Show 背景纹理，SharedTooltip_SetBackdropStyle 的 hook 延迟执行皮肤逻辑。这里没有断言用户曾看到的黑框一定来自该回调；隐藏父级是针对后到 Show 的结构性隔离。

## 验证结果与限制

专项通过：原生 Frame 与 Region 身份保留；有依据的 Frame 不被匿名纹理替换；有效原生选择不读备用列表；空原生锚点被跳过；隐藏、透明、裁切、secret、自身 UI/轮廓过滤保持；取样异常后清理并恢复轮廓；延迟 Show/换肤、退出后迟到 Show 均在隐藏父级下不可见；Shift 和退出后两个取样接口调用数不增长。

离线专项：有效原生选择 100 次约 1 ms / 0.0 KiB 替身累计分配 / 备用列表读取0。备用 128 候选 ×100 次约 55 ms / 最大读数2 ms / 295.9 KiB / 保留增长0.0 KiB。初次模拟 Frame=9（原7），Region=35，保留36.8 KiB（原35.5）；100次开关累计219.8 KiB、增长0.0 KiB。原生 API/模板由替身模拟，这些数字不能当作实际游戏内存或帧时间。

实机待确认：用户提及的各插件归属、原生取样在隐藏父级下的客户端行为、真实模板行成本、EUI Tooltip共存及战斗恢复。回滚使用新的 git revert，不能重写已交付历史。

交付检查：完整 `tests/check_contract.ps1` 通过（包含 Lua/XML/TOC 静态与交互生命周期回归）；wowdoc validate 返回 checkedLua=75、valid=true、无诊断；git diff --check 通过。完整回归再次得到有效原生选择100次1 ms/0.0 KiB、备用列表100次59 ms/297.9 KiB/保留增长0.0 KiB；其余对象和生命周期预算通过。
