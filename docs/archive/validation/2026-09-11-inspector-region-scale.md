# 独立缩放区域的命中与按钮可见交集

基线 c23c2ac000925746a070d033dfb60e2854482e3a。
用户报告 complete，83/83，无截断；Rurutia按钮和Text均为outside-pointer。
本机 RurutiaSuite/Modules/ChatBar/Core.lua:949-950 按钮默认24x18；:990 对文字启用缩放。
Core/UILib.lua:290-329 的 SetupButtonScaleAnimation 在 OnEnter 只对Text:SetScale(1.2)，
按钮尺寸不变；字体居中 :235-238，ChatBar文字字号可独立配置。
原算法用父Frame有效缩放解释Region:GetRect，并要求文字矩形完全包含在按钮内。
这两条假设不成立：区域有独立缩放，文字也可能高于按钮。
同样的独立缩放可出现在冷却/Aura装饰层，修复采用通用几何规则，不写插件白名单。

先在真实Provider Poll路径重放24x18按钮、居中文字1/1.2切换；旧代码失败。
改为Region:GetEffectiveScale独立换算；不可读/secret/非正缩放明确拒绝，不能回退父缩放。
按钮留白以内容矩形、按钮矩形、最多16层裁剪祖先在屏幕坐标中的交集证明可见；
内容允许伸出按钮，但完全分离、透明、隐藏、空白或完全裁剪仍拒绝。
原生命中、fallback、上轮结果复核共用这条规则。

成本（实现前约束）：原有0.1秒活动轮询不变；每个通过内容过滤的Region增加一次受保护读取有效缩放。
按钮留白仍只使用已有GetRect/16层裁剪交集，标量计算不分配临时表。
每批128对象/0.75ms、总512候选，区域扫描32/组保持不变；原生调用仍不可抢占。
不新增Frame、Region、timer、事件或缓存，关闭/战斗无新增活动；原有离线性能预算不提高。

版本证据：wowdoc source list/check 已执行；sourceId=wow-ui-source，product=retail，
requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。
Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua:38
`Name = "GetEffectiveScale"`，返回effectiveScale number且具有Scale secret aspect；:179 SetScale。
SimpleScriptRegionAPIDocumentation.lua:169 GetRect，left/bottom/width/height为uiUnit，可无返回/secret。

测试替身有效缩放改为自身缩放乘父级有效缩放，以覆盖独立缩放和继承。
既有不同裁剪祖先缩放场景显式抵消按钮缩放，保持原先屏幕几何输入不变。
离线几何用例不能证明此次实机全部属性值；报告未记录实际矩形与缩放，若仍失败需要这些字段。

## 次级资源条纯色背景

用户追加complete 53/53报告：ERB_SecondaryFrame._barBg被texture-empty-or-unreadable拒绝。
本机EllesmereUIResourceBars.lua:3770创建背景，:3796 SetAllPoints(secondaryFrame)，
:3800-3802 SetColorTexture黑色/自定义半透明填充，非普通贴图路径。
仅GetTexture/GetAtlas不能证明这类内容为空。
SimpleRegionAPIDocumentation.lua:110 IsObjectLoaded返回bool；SimpleTextureBaseAPIDocumentation.lua:401 SetColorTexture。
文档未明确空白纹理的loaded返回语义，所以不能单凭加载状态直接放行。
首次原生取样时，在现有永久隐藏stackRoot下创建两个1x1纹理，验证：空白loaded=false、
纯色loaded=true，且原有alpha读取能识别透明与不透明纯色。只在该对照通过时启用loaded补证。
自检不改第三方UI、不添加hook；失败保守拒绝，并在报告输出solidTextureProbe明细。
新增固定2 Region复用一次，没有新Frame/持续驱动；首次上限仍16Frame/48Region。
离线回归先失败再修复，覆盖非文件纯色、透明纯色、空白、受限loaded值，客户端样本语义仍待实测。

验证完成：聊天按钮1/1.2独立缩放反复切换、被裁剪原生聊天文字后的fallback、
非按钮装饰区域、文字越界但相交、完全分離、secret缩放、隐藏、透明、祖先裁剪均通过。
纯色背景、透明纯色、空白纹理、secret loaded、自检两种样本都loaded时保守拒绝通过。
完整check_contract.ps1通过，wowdoc validate 75 Lua / diagnostics=null，git diff --check通过。
离线仍12Frame，Region由37增至39；首次保留37.2KiB，100次启停6ms/393.2KiB，
10000次跟随7ms/0分配，未观察到保留增长。空闲无新增活动。
未实机执行/reload：尤其IsObjectLoaded对空白纹理的返回尚未读取，
若solidTextureProbe.enabled=false，纯色背景仍保守不选；不宣称这份ERB截图已实机验收。
