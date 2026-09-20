# 背包定位原生流光（0.3.7）

运行提交：ffce8fb → b0c7522 → 87daff1。复用 Blizzard AutoCastOverlayTemplate；正式服隐藏 Corners、外扩 4 UI 单位抵消 Mask 内缩，旋转周期从 4 秒改为 2 秒，Shine 使用 ADD 混合。无第三方库、附加素材或叠加动画。怀旧服保留其原生共享流光实现。

## 生命周期与成本

首次定位懒建一份模板，单个三秒计时器。目标切换先清理旧效果；超时、背包实际隐藏、BAG_UPDATE_DELAYED、PLAYER_REGEN_DISABLED、Provider 停用时停止原生效果、取消计时器、清除事件及锚点并重新挂回 UIParent。保留模板自带 OnShow/OnHide；没有逐格 hook、新增 OnUpdate、SV 或目标缓存。

正式服实测固定 1 Frame / 3 Region / 0 子 Frame，动画组复用。离线 100 次定位分配 47.7 KiB，回收后增长 0.0 KiB；这不是整个客户端的内存读数。实机全局 Lua 自然读数包含 Ellesmere 的 RefreshInventory 和其他插件：三组十次定位约 393024 / 398705 / 404386 KiB，不可归因为流光保留增长，也不宣称整个客户端零分配。未执行强制 GC；原生图形显存字节未单独测量。对象上限和清理验证通过，可接受本次参数调整；上游刷新成本不属于本次视觉调整。

## 来源证据

sourceId=wow-ui-source；retail requestedRef=12.1.0 resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。
- Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/AutoCastTemplates.xml:3，AutoCastOverlayTemplate；Shine 使用 UI-HUD-ActionBar-PetAutoCast-Ants，Rotation 原始 duration=4，Mask 内缩 4，Corners 独立纹理。
- 同目录 AutoCastTemplates.lua:3 / 16：ShowAutoCastEnabled 设置状态；UpdateShineAnim 根据状态和显示性调用 Play/Stop。
- Blizzard_APIDocumentationGenerated/SimpleAnimAPIDocumentation.lua:300：SetDuration(durationSec, recomputeGroupDuration=true)。SimpleAnimGroupAPIDocumentation.lua:48：GetAnimations 返回已有动画。
- SimpleTextureBaseAPIDocumentation.lua:381：SetBlendMode(blendMode)。
- classic latest=ecadf9d3326fa87828cacca7f13c0ab5f41840a6、titan latest=84ef503f0d2617494db84cc9c7e7b530e976f6e7、anniversary latest=1463c686270b6c64e2c5c228f447c4597c0f8ba6：Classic/AutoCastTemplates.xml:9 提供同名模板；Classic/AutoCastTemplates.lua:17 显式启停共享管理器。

## 验证

完整契约、仓库检查、发布构建、retail wowdoc validate、git diff --check 通过。运行文件同步并核对 SHA-256。实机为 Retail 12.1.0.69875 / zhCN / 晴昼秋岚—白银之手 / EllesmereUIBags。

- 0056（0.3.6）失败保留：探针误将 CloseAllBags 当作关闭 Ellesmere，窗口实际未隐藏；不用于证明关闭失败或成功。
- LYCHEE-20260920-172405-0057：14 项通过，30 次复用、超时、实际隐藏、重开、事件清理与重试。
- LYCHEE-20260920-172624-0058：16 项通过，另验证 Corners 隐藏、42 单位效果对齐 34 单位格子；中断后的 reload 清理通过原 nonce 恢复，未重跑任务。

战斗仅回放清理事件，不代表真实战斗/taint 验收；其他背包和客户端仅离线/来源核对。无受保护物品使用，未测真实战斗或怀旧服实机。

最终 Ticket LYCHEE-20260920-173104-0059：18 项通过，包括两秒周期、ADD 混合、实际显示及全部清理流程。三组全局自然 Lua 读数 395881 / 401562 / 407243 KiB，十次定位总 CPU 136.53 / 217.23 / 264.85 ms（包含第三方完整刷新，不是流光独立耗时）。三个有效 Ticket 均已 ACK 并清理标记，自有 bag036 / bag037 任务已移除。
