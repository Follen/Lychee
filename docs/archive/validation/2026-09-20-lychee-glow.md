# LycheeGlow 初始验收（0.3.8）

## 设计和边界

UI/LycheeGlow.lua 独立模块，I.LycheeGlow:Start(target,options)/Stop(target,key)。参考已安装 LibCustomGlow minor 23 的成对启动/停止、key、可配置颜色/速度/偏移及资源回收设计，未复制库源码。单目标容量，新的 Start 替换旧效果；八个光点、八个原生 Path 动画组、48 个控制点，只在首次使用创建。普通配置不写 SV。颜色、速度、尺寸和时间参数有界；目标隐藏、事件、超时和手动停止清除事件、计时器、父级、锚点及目标身份。

无 Lua OnUpdate、无第三方库、无新素材。原生动画仍有引擎成本，不能据此宣称比 LibCustomGlow 更快。默认两束四光点尾迹，约 1.54 秒一圈；减少动态效果不播放动画。小型 star4 游戏资源共享。

## 来源

wowdoc sourceId=wow-ui-source，retail requestedRef=12.1.0 resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。
- SimpleAnimPathAPIDocumentation.lua:10 CreateControlPoint(name,templateName,order)，:66 SetCurveType(curveType)。SimpleControlPointAPIDocumentation.lua:37 SetOffset(offsetX,offsetY)。
- Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:50 使用 interface/cooldown/star4，ADD 混合。
- classic latest ecadf9d3326fa87828cacca7f13c0ab5f41840a6、titan latest 84ef503f0d2617494db84cc9c7e7b530e976f6e7、anniversary latest 1463c686270b6c64e2c5c228f447c4597c0f8ba6：SimpleAnimPathAPIDocumentation.lua:10 同样支持 CreateControlPoint。

## 离线验证

完整契约通过，包含四客户端加载、背包动作及安全使用。专项覆盖路径闭合、矩形边界、尺寸变化、重复启动、key 隔离、静态减弱模式、超时、隐藏、事件和停用清理。100 次定位仍为 1 Frame / 8 Texture / 8 AnimationGroup，约 1 ms，累计分配 46.2 KiB，回收后保留增长 1.6 KiB；这是替身边界下的 Lua 固定状态，不是游戏显存或客户端整体开销。比较上版为 1 Frame / 3 Region，新增原生对象是尾迹效果的固定代价；没有随定位次数增长。

仓库检查、发布清单、retail wowdoc validate 和 git diff --check 通过。新增模块要求重启。实机外观、动画位移、真实关闭/重开、跨背包、战斗及重复定位性能待重启后验收，不能用离线结果代替。

UI.xsd 的 ANIMCURVETYPE 定义为 NONE / SMOOTH；使用 NONE 保持矩形边缘，不使用无效的 LINEAR。

## 0.3.9 密集环绕修订

提交 e62d354：32 个光粒均匀分布整圈，取消双束分组；小光粒7、大光粒10 UI单位，每四粒一亮点，小光粒80%亮度，约1.82秒一圈。固定1 Frame / 32 Texture / 32原生Path / 192 ControlPoint。与八粒版本相比增加固定的原生对象，资源不按点击增长。

完整契约、wowdoc静态验证、仓库、构建与差异检查通过。离线100次定位约3ms、累计46.2 KiB、回收后增长1.7 KiB；初始相位按36×36格子的144周长每4.5单位一粒验证，路径闭合与调整尺寸复用通过。

实机 Ticket LYCHEE-20260920-191210-0060 / requestId=lycheeglow039-20260920 / revision=2 / Retail 12.1.0.69875 / zhCN / 晴昼秋岚—白银之手，complete=true/status=succeeded。32组动画播放且原生时钟推进，无Lua OnUpdate；30次定位每轮32 Region、0子Frame，超时、实际关闭Ellesmere、重开、背包更新、模拟战斗事件、重试、减少动态效果、错误key及显式停止均通过。重载标记清理中断通过原nonce恢复，没有重复执行；ACK及任务清理完成。

三轮（每轮10次）包含Ellesmere完整背包刷新的总CPU为144.44 / 229.88 / 280.31 ms；全局自然Lua读数398789 / 404470 / 410151 KiB，包含第三方及客户端分配，不归因为流光独立性能或保留增长。不增加GC干预，不声称整个客户端内存降低。原生图形/控制点的引擎内存字节未测。32粒是本次明确的视觉密度成本，可接受固定容量及零空闲Lua工作；不宣称比LibCustomGlow更快。其他客户端、真实战斗及其他背包实机仍未覆盖。


## 0.3.10 正式服技能触发光

正式服改用原生 FlipBook；经典服保留 0.3.9 Path 分支。正式服固定一个框体、两张纹理、两个动画组和两个 FlipBook，首次使用创建并复用，无 Lua OnUpdate。0.3 秒开场结束后切换 0.85 秒循环；三秒到期、隐藏、战斗和背包更新清理引用、事件、计时器及动画。减少动态效果只显示静态帧。

证据：sourceId `wow-ui-source`，product `retail`，requestedRef / matchedTag `12.1.0`，resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml` 的 ActionButtonSpellAlertTemplate 定义 Start/Loop atlas 与 6 行、5 列、30 帧 FlipBook；`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimFlipBookAPIDocumentation.lua:115` 定义 `SetFlipBookRows(rows)`。复用客户端资源，不新增媒体文件或外部库。

离线：两条分支的背包适配、取消、超时、隐藏、重试、减少动态效果、过期 key 与原生对象复用检查通过；正式服 100 次定位分配 44.6 KiB，回收后增长 0.0 KiB（测试替身，不代表客户端堆）。实机覆盖按开场到循环、原生时钟、隐藏、重开、三轮重复定位、超时、事件清理和减少动态效果执行；结果待追加。
