# 空鼠标焦点下的图标识别

## 实施前范围与预算

基线 `3e07553`。用户延时读取实际得到 `foci 0`，并明确中间 Ellesmere 冷却管理器、右上角 Buff/Debuff 均漏识别。保留输入焦点优先与已有来源解析；仅无有效焦点时补充可见纹理／文字的几何命中。禁止取样 GameTooltip、SetFrameStack、插件名映射、修改第三方对象及其鼠标属性。

预先确定的预算与生命周期：

- 仅主动识别且脱战时检查，复用既有定时器；进行中的批次间隔 0.01 秒，一轮结束后恢复 0.1 秒。有效输入焦点、Shift 锁定有效目标、复制、关闭、禁用与战斗停止扫描。
- 每批最多 128 个框体、约 0.75 ms 后在框体边界让出；每个命中框体最多看 32 个 Region，父级排除与裁切检查最多 16 层。单个原生调用无法抢占，预算不是客户端硬实时保证。
- 只保留枚举游标、当前最佳候选、上一轮结果和鼠标位置等固定状态，不存全量对象目录，不新建 Frame/Region，不安装 hook。关闭后清除所有扫描引用。
- 独立测试至少覆盖 4,096 个框体的分批遍历，记录批次数、总时间、最大批次、累计分配和 GC 后保留增长。普通鼠标焦点路径保持已有 100 次开关预算；不能把离线结果当作游戏内耗时。

先加入“空焦点、可见冷却图标”回归，运行 `lua tests/addon_inspector.lua` 在旧实现实际失败：`zero input foci must still identify a visible cooldown icon`。

## 最终行为与边界

已有输入焦点走原路线；无有效焦点时，`EnumerateFrames(previous)` 分批推进，仅读取现有对象，检查 Region 的 `GetRect`、父框体有效缩放、IsVisible、alpha、纹理或非空文字、颜色 alpha 和父级裁切。只处理 Texture/FontString，不把无绘制区域的 Frame 当成结果。光环测试使用另一个未知插件名，证明没有 EUI 专用目录。

重叠区域按 strata、frame level、draw layer、小区域优先排序。这是界面几何检测，不是逐像素渲染拾取：纹理文件内透明像素、旋转／mask、相同 frame level 的实际创建顺序，以及超过 16 层父级／32 个 Region 的非常规控件仍有限制。原生绘制但不暴露普通 Region 的对象不在本次补齐范围内。

只有扫描完成后提交候选；鼠标移动清空上一位置的游标与结果。扫描过程中对保留结果重新检查可见性与当前位置，避免显示已隐藏的旧图标。窗口位置更新不执行枚举。没有新增 Lua/XML/TOC 文件或加载顺序变化。

## 版本证据

Blizzard 证据统一为 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。本会话已执行 source list/check，快照与远端一致。

| path | line | excerpt / 用途 |
| --- | --- | --- |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/InputDocumentation.lua` | 54 | `GetMouseFoci` 返回 ScriptRegion 表；优先路径 |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua` | 169 | `GetRect` 返回 left、bottom、width、height；返回值可能为空或 secret |
| 同上 | 545 | `IsVisible`；按可见性过滤 |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua` | 366 | `GetEffectiveAlpha`；包含父级透明度，可能返回 secret |
| 同上 | 381 | `GetEffectiveScale`；指针物理坐标与区域矩形换算 |
| 同上 | 576 | `GetRegions` 返回 SimpleRegion 可变参数，可能包含 secret |
| 同上 | 188 | `DoesClipChildren`；父级裁切 |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua` | 66 | `GetVertexColor` 返回 RGBA；透明纹理颜色过滤 |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua` | 217 | `GetTexture` 返回可空纹理文件 |

全局 `EnumerateFrames` 没有在本次 Blizzard 生成文档查询中找到直接定义。使用 wowdoc 的已索引 ElvUI 源码交叉确认实际调用：

- `sourceId=elvui`，`product=main`，`requestedRef=fdc08aaefc7c0810af685404d43b8ccfade8c497`，`resolvedCommit=fdc08aaefc7c0810af685404d43b8ccfade8c497`。
- `path=ElvUI/Game/Shared/General/Toolkit.lua`：第 627 行 `object = EnumerateFrames()`；第 635 行 `object = EnumerateFrames(object)`。wowdoc 返回这两处调用关系，并读取相同固定提交的原始文件核对参数。
- source check 显示 ElvUI 远端已更新；这里明确采用已有固定快照，没有称其为当前最新。运行时检查全局接口存在性，不可用时保留鼠标焦点路径。

## 离线验证

`lua tests/addon_inspector.lua` 覆盖：空焦点下冷却图标、光环图标、动态父级来源；空锚点、隐藏与透明框体、空文字、透明纹理颜色、父级裁切、secret 几何、自身区域、层级排序、UI 缩放、鼠标移动与部分扫描失效；4,096 框体分批、有界枚举、正常定时器与快速批次切换、Shift、停止后的零枚举。测试禁止创建 GameTooltip。

独立专项运行两次的大场景观测：

| 样本 | 批次 | 总 CPU | 最大批次读数 | 累计分配 | GC 后保留增长 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 47 | 25 ms | 1 ms | 1.8 KiB | 0.1 KiB |
| 2 | 44 | 24 ms | 2 ms | 1.8 KiB | 0.0 KiB |

无新增 Frame/Region。计时使用宿主 Lua 5.1 的毫秒级时钟，0.75 ms 是帧对象之间的让出目标，观测峰值并非严格低于该数值，不能把它当作硬实时保证。真实批次等待还要增加约 `(批次-1)×0.01 秒`，因此首次结果有延迟；没有将分批误报为总耗时消失。

普通鼠标焦点路径：100 次开关累计分配约 221 KiB（基线约 345.7 KiB），通过去掉方法读取时重复创建的闭包降低临时分配；现有 1 MiB 分配、64 KiB 保留增长等预算不变。10,000 次指针更新分配为 0、枚举为 0、来源读取为 0。仅说明固定离线场景，不推断游戏帧率收益。

实机仍待验证：这张截图里的 EUI 冷却图标和 Buff/Debuff 实际命中、角色 UI 的实际框体总数、首次定位延迟、批次峰值、动态图标布局、secret/taint、关闭及战斗后的零活动。测试通过与同步不等于实机通过；回滚使用新 git revert。

提交前结果：`powershell -NoProfile -File tests/check_contract.ps1` 全部通过；`wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest` 返回 `checkedLua=75`、`valid=true`、无诊断；`git diff --check` 通过。完整检查中的第三次大场景为 46 批／23 ms 总 CPU／2 ms 最大批次读数／1.8 KiB 累计分配／0.0 KiB 保留增长。
