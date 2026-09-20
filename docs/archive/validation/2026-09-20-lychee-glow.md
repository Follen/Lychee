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
