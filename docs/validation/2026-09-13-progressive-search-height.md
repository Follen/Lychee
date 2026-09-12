# 分批搜索的高度动画

## 复现与原因

用户录像 `20260913-060940.mp4` 在约2.63秒出现搜索结果，但面板仍维持短高度、第二行被裁切，约2.9秒才展开。“成就”搜索也出现同样等待。清空输入后的首页收缩是另一条原有高度动画，本次不修改开关轨迹或曲线参数。

`Palette:ResizeForMode` 在 searchPending 时无条件返回。该规则原本用于避免空等待阶段收缩，却也冻结了已经返回的非空结果。结果展示与高度更新的时机不同步；不是仅调快或调慢动画能够解决。

修复前实机 Ticket `LYCHEE-20260913-072741-0032`，源提交 `70c817d`，Retail12.1.0.69587，完整322个样本。相同输入“乌拉”约171ms时已有8条结果，窗口仍338高；约488ms才出现518的动画目标。首批已到达结果被多等待约317ms。本轮真实首页有更多最近项，所以初始338高，不能将它冒充用户录像里的短首页高度。

## 修正与生命周期

- 空结果等待保持当前尺寸；非空中间结果即可扩展，不等全部来源完成。
- Motion:Height 的可选 growOnly 保留更大的活动目标，不因中间结果较少而反复收缩。若旧收缩将裁掉新结果，停止在当前高度；最终结果仍按普通模式收敛。
- 相同目标不重启动画；顶部、输入框、文字尺寸和220ms曲线不变，不更改搜索集合、排名或交付时机。
- 只在结果更新时决定目标，活动动画继续使用一个既有驱动/任务；没有新缓存、Frame、timer或空闲轮询。隐藏、战斗与减少动态效果沿用既有收尾。

## 验证

`lua tests/ui/ui_library_integration.lua` 在旧逻辑明确失败于 `partial results must expand before all providers finish`，修复后通过。覆盖空等待、首批扩展、相同目标不重启、中间批次不回缩、后续增长、最终收缩，以及收缩途中新内容到达。

首次完整检查88/89：旧首页循环最大耗时恰好5.000ms，触发严格小于5ms门禁，原始日志保留，未调整阈值。补齐收缩途中重定向后再次执行完整检查，该轮仍88/89，保留 full-final.json。随后发现即时模式的同高请求会重复 SetHeight，增加无活动任务且高度相同的提前返回及零 setter 回归；最终 full-idempotent.json 为89/89通过，门槛未变。实机探针每33ms有界采样，外部录像会影响帧率，不能作为无采样CPU成本。

接口证据由 wowdoc 查证：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`12.1.0`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua` 第124行 SetHeight，参数height为uiUnit，调用受保护；代码仍在战斗检查后执行。GetHeight及完整excerpt保存在本地 `analyze/drop-motion-20260913/`。未以本次非战斗重放代替战斗实机验收。

静态验证：wowdoc Host43个Lua文件有效、无诊断；完整回归89/89，git diff --check通过。最终实机对照另行记录，不将离线通过当成视觉通过。
