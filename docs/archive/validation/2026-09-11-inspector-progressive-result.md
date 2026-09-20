# 插件识别：扫描中的候选及时显示

基线：`4b1bbed`。用户实际诊断输出 `START true true`，5 秒后 `LY true true table:… table:… nil nil`；依次对应 running、visualPending、visualCursor、visualBest、visualResult、target。证明采样时识别运行中且已收集候选，却未发布结果。不能从该输出确定候选是哪一个图标，也不能推断整轮实际耗时。

## 范围、成本与生命周期

修改前确定：只改每批结束后的结果选择。发现当前有效候选即可显示，后续按原有排序更新；保留坐标、可见性、透明度、裁切和受限数据检查。无新增 Frame、timer、hook、缓存目录或第三方对象写入。每批仍最多 128 框体、约 0.75 ms 后让出，每框体最多 32 个 Region；新增候选重检最多一次 VisualFrame 和 VisualRegion，与既有保留结果重检使用相同边界。首次发现候选的批次即应更新 target，不再等待全量枚举。首次发现本身仍有延迟，不声称即时完整拾取。

活动、战斗停止、Shift 冻结、复制、关闭、禁用及缓存释放沿用原契约。同目标不重复读取来源；候选隐藏后移除。大场景仍沿用 4,096 框体、累计分配小于 1 MiB、关闭后保留增长小于 64 KiB 的测试预算，不抬高门槛。

## API 证据

wowdoc source list/check 后查询；sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。本次没有新增 Blizzard API。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:169`：`Name = "GetRect"`，`MayReturnNothing = true`、`SecretWhenAnchoringSecret = true`，返回 left、bottom、width、height。继续复用既有受限返回检查，发布前重新确认命中。
- 其余可见性、透明度、裁切证据沿用 [初次兜底验证](2026-09-11-inspector-visual-fallback.md)。

## 验证

先写回归再修改：`lua tests/addon_inspector.lua` 在旧实现失败：`a discovered icon must display before the full frame scan completes`。场景为 4,096 框体，首批存在有效图标、末尾存在更高层图标，完整扫描尚未结束。

修改后同命令通过，覆盖：首批显示、同候选不重复解析、候选隐藏清理、移开清理、后续更优候选替换。既有空锚点、secret、裁切、Shift、停止、战斗等回归保持通过。

专项离线数据：4,096 框体 44 批、总 CPU 23 ms、最大单批读数 2 ms、累计分配 1.8 KiB、关闭后保留增长 0.0 KiB、新增 UI 对象 0。10,000 次指针更新分配 0 KiB；100 次开关累计 221 KiB、保留增长 1.1 KiB、空闲工作为 0。与基线记录接近；计时分辨率及不可抢占单次调用仍适用，不能当作游戏实测。

实际 EUI 图标归属、完整扫描耗时与游戏帧时间仍待客户端验证。本次截图证明发布时机缺陷，离线回归证明修复该路径，不替代最终实机确认。回滚使用新的 git revert。

交付检查：完整 `tests/check_contract.ps1` 通过（含 Lua/XML/TOC 检查及针对性回归）；wowdoc validate 返回 checkedLua=75、valid=true、无诊断；git diff --check 通过。完整回归中的大场景为 46 批、25 ms 总 CPU、2 ms 最大单批读数，内存与专项结果一致。
