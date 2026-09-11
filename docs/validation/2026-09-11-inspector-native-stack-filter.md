# 原生 Fstack 列表与可见内容过滤

## 决策与范围

基线 `f81c035`。用户明确要求改回 Fstack 接口，并处理没有显示的框体。本次用正式服 `C_System.GetFrameStack()` 直接读取对象列表，替换全局 EnumerateFrames 分批扫描；不恢复旧的 GameTooltip:SetFrameStack 取样窗口。

先写回归：旧实现在 `lua tests/addon_inspector.lua` 报错 `native frame-stack objects must be used without a sampling tooltip`。新实现直接消费原生列表，并对列表中的 Frame 和 Region 做可见内容检查。没有创建位置的对象仍遵循原来的不确定归属文案。

## 预定成本和生命周期

- 只在已开启识别、脱战且未锁定/复制时工作，复用一个定时器，每 0.1 秒调用原生接口一次。没有新 hook、Frame、Texture、事件或取样 Tooltip；移除 0.01 秒的全局枚举驱动。
- Lua 候选上限 128，每个 Frame 最多读取 32 个直接 Region；父级可见性/裁切检查 16 层，约 0.75 ms 后在候选边界让出。原生函数一次调用和返回列表的分配不可抢占，其规模不由 128 的 Lua 遍历上限约束，不能把离线时间写成客户端硬实时保证。
- 新列表当次使用后释放，不保留候选目录、枚举游标或旧鼠标位置结果；仅最终目标由既有 UI 持有。首次结果不等待全局枚举，一次 Poll 发布本次可用候选；达到预算可能错过后面的候选，不承诺极大原生列表完整排序。
- 关闭、禁用、战斗、隐藏立即取消；Shift 有目标时与复制期间不取样。初始化/未启用零创建、零取样。原生 API 缺失/失败保留有可见性与透明度检查的输入焦点兼容路径；原生空列表具有权威性，不回填旧焦点。
- 预定离线预算延用初次识别的对象和内存门槛：新 UI 对象 0；128 候选 × 100 次取样累计分配 < 1 MiB、停止后增长 < 64 KiB；100 次开关 < 1 MiB、增长 < 64 KiB。记录总时间与最大单次，不把模拟原生返回值当作引擎成本。

## 过滤规则

原生对象仍需排除根框体、禁止访问对象、识别窗口与轮廓。显示状态、有效透明度、有效尺寸、鼠标命中与父级裁切均需通过；Texture 必须有纹理/图集及可见颜色，FontString 必须有非空文字及可见颜色。Frame 本身没有可见内容时不命中，检查其直接绘制区域；不靠名称猜测是否为锚点。因此类似 ExBoss 空容器、EUI TooltipCursorAnchor 不会仅凭占据空间被识别。直接 Region 同样检查其所属 Frame 与祖先透明度。

限制：几何与属性判断不能判断纹理内部每个像素，也不等同于处理所有旋转/遮罩/纯原生模型等特殊绘制。排序保持 strata、level、draw layer、区域大小的原规则，不在此次扩展第三方插件识别目录。

## 版本化证据

已执行 wowdoc source list/check，再 inspect/query。统一来源：sourceId=`wow-ui-source`，product=`retail`，requestedRef=`latest`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`；localCommit 与 remoteCommit 一致。

| path（相对 Interface/AddOns/Blizzard_APIDocumentationGenerated） | line | excerpt |
| --- | --- | --- |
| SystemDocumentation.lua | 5 | `Namespace = "C_System"` |
| SystemDocumentation.lua | 11 | `Name = "GetFrameStack"`；返回 `objects`，Type `table`，InnerType `ScriptRegion` |
| SimpleFrameAPIDocumentation.lua | 366 | `GetEffectiveAlpha`，`RequiresScriptObjectAlphaAccess = true`，Alpha 可能受限 |
| SimpleFrameAPIDocumentation.lua | 968 | `IsVisible`，Shown 可能受限 |
| SimpleFrameAPIDocumentation.lua | 576 | `GetRegions`，多返回 SimpleRegion，Hierarchy 可能受限 |
| SimpleFrameAPIDocumentation.lua | 188 | `DoesClipChildren`，返回 clipsChildren |
| SimpleRegionAPIDocumentation.lua | 24 | `GetDrawLayer`，返回 layer、sublayer |

矩形、纹理、颜色等沿用 [可见内容检查证据](2026-09-11-inspector-visual-fallback.md)。所有受限值继续先检查再比较，不启用来源记录或修改任何 Fstack CVar。

## 回归与测量

`lua tests/addon_inspector.lua` 通过。覆盖原生列表的 Frame/Texture、空输入焦点、空锚点盖住图标、隐藏/全透明父级、空文字、透明颜色、裁切、受限矩形、识别窗口/轮廓排除、输入焦点与原生空列表冲突、原生错误兼容、候选 128 上限、原生排序与重叠、Shift/停止后零取样。

测试禁止创建 GameTooltip；公共 GameTooltip/FrameStackTooltip 设为访问计数陷阱，读写为 0；EnumerateFrames 调用为 0。模拟 API 每次新建返回表以计入其分配，不用固定表伪装零分配。

两次专项：128 候选 × 100 次为总 CPU 56 / 57 ms，最大单次读数 2 / 2 ms，累计分配 300.0 / 297.3 KiB，停止后增长 0.0 KiB、新 UI 对象 0。10,000 次指针更新累计分配 0，来源读取与全局枚举 0。100 次开关累计约 219.8 KiB、增长 0.0 KiB。原扫描基线 4,096 框体约 44–46 批、23–25 ms 总 CPU；输入口径不同，不据此计算性能收益。

游戏实测尚未完成：EUI 冷却/Buff/Debuff 来源、空锚点排除、正常 Tooltip 与 Fstack 共存、原生取样耗时/分配、战斗与关闭。当前通过项为源代码证据及离线回归，不能替代实机验证。回滚使用新的 git revert。

交付检查：完整 `powershell -NoProfile -File tests/check_contract.ps1` 通过（含 Lua/XML/TOC 和交互/生命周期检查）；wowdoc validate 返回 checkedLua=75、valid=true、无诊断；git diff --check 通过。完整回归中的原生列表模拟为 100 次 / 56 ms 总 CPU / 2 ms 最大单次 / 295.3 KiB 累计分配 / 0.0 KiB 保留增长。
