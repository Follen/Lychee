# 鼠标装饰层穿透识别

## 实现前的原因与预算

基线：`2b10bcc`。用户截图命中 `SC_CursorFrame`；安装目录的
`Rurutia_SimpleCursor/Core/Core.lua:205–208` 创建 TOOLTIP Frame 并 EnableMouse(false)，
`:292–300` 的 OnUpdate 每帧按 GetCursorPosition / GetEffectiveScale 把中心定位到鼠标。
因此点击穿透不等于 FStack 不命中；静态可见性过滤不能区分真实目标和鼠标装饰。

采用会话内运动证据，不按插件名、框体名或创建路径排除。只观察不接收鼠标、
TOOLTIP 层、存在 OnUpdate 且中心位于鼠标的框体；连续两次至少 4 屏幕像素的移动，
矩形与鼠标同向等量移动（2 像素容差、尺寸稳定）后，排除根框体及其后代。
未知信息不构成跟随证据。控件不再满足条件或停止跟随时撤销；静止时不累计证据。

复用活动识别的 0.1 秒采样，不新增 Frame、Region、hook、事件或 timer。
Picker 独占最多 8 条记录，循环淘汰；每次采样同一记录至多更新一次。
关闭/战斗/Reset 释放对象引用；Shift 冻结时不采集运动。原有 16 层祖先、
512 原生候选、128 候选 / 0.75 ms 批预算保留，不扩展候选树。
预算：固定 1,000 次跟随采样累计分配 < 64 KiB、GC 后保留 < 16 KiB、
离线每批最大 < 4 ms；首次确认需要两个有效移动采样，正常静止对象不增加等待。
登录/空闲/战斗不采集；真实客户端帧顺序与运动确认延迟待 /reload 验证。

## 版本证据

sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，
resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。
通过 wowdoc source list/check 和 inspect 查询：

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:430–440`：
  IsMouseEnabled 返回非空 bool。
- 同文件 `:220–236`：GetScript(scriptTypeName, bindingType=Extrinsic)，检查 ScriptBindings 禁止访问；
  使用保护读取，未知/secret/error 不执行回调、不升级为可跟随。
- 同文件 `:169`：GetRect 的 nullable/secret 边界沿用 Picker 现有读取与屏幕缩放转换。

## 验证结果

`lua tests/addon_inspector_picker.lua` 在旧实现上失败：
`confirmed cursor decoration and children must not steal the underlying hit`。
修复后通过，另有 600 次原生候选参考排序对照。覆盖子层切换、空白位置、
静止不计数、停止跟随恢复、慢速移动、可交互/未知状态不排除、冻结、容量溢出、Reset。
`lua tests/addon_inspector.lua` 通过真实读取适配层与 Provider：GetScript 收到 OnUpdate，
不执行第三方脚本，移动后识别下面的插件，停止/重新开启释放旧判定。

相同 Lua 5.1 离线入口的前后样本（毫秒分辨率，不声称帧率收益）：

| 场景 | 2b10bcc | 本次 |
| --- | --- | --- |
| 原生命中100次 CPU / 分配 | 3 ms / 0.4 KiB | 3 ms / 0.4 KiB |
| 备用选择100次 CPU / 分配 | 10 ms / 8.5 KiB | 11 ms / 8.5 KiB |
| 128项原生快照100次 CPU / 最大单次 | 8 ms / 1 ms | 11 ms / 2 ms |
| 同快照累计分配 / GC后保留增长 | 201.1 KiB / 0 | 201.1 KiB / 0 |
| 首次面板保留 / Frame / Region | 38.4 KiB / 12 / 37 | 38.5 KiB / 12 / 37 |
| 开关100次累计分配 / 保留增长 | 330.7 KiB / 0 | 330.7 KiB / 0 |

新增跟随场景：预热10次、连续1,000次，17 ms总CPU、1 ms最大单次，
累计分配与GC后保留增长均0.0 KiB（复用坐标输入，未将测试夹具分配计入Picker）。
增加了受保护属性读取，备用扫描总耗时有所增加；仍在既有批预算检查下执行，
没有新增活动驱动、UI对象或空闲工作。实机的采样相位、快速移动、UI缩放和战斗退出待用户验证。

`powershell -NoProfile -File tests/check_contract.ps1` 完整通过，原始输出保存在
`%TEMP%/lychee-cursor-follower-contract.log`。`wowdoc validate --path package/Lychee
--source wow-ui-source --product retail --ref latest` 检查76个Lua文件，valid=true、diagnostics=null。
`git diff --check` 通过。

交付沿用先提交再覆盖复制运行时与逐文件SHA256比对的流程，唯一目标
`D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`；提交与同步结果见本轮交付回执。
不修改或隐藏第三方圆圈、不删除目标旧文件。回滚使用新的git revert提交，再验证并同步。
