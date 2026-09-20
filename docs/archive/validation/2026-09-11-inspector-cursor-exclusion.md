# 直接排除鼠标圆圈

用户明确要求直接屏蔽这个鼠标圆圈插件的识别；替代 `910959c` 的运动检测。
安装文件 `Rurutia_SimpleCursor/Core/Core.lua:205` 创建全局 `SC_CursorFrame`，
圆圈纹理、圆点、`SC_GCDFrame` 都在其子层。`:328`创建RSC_SettingsPanel，`:519`创建SC_EventFrame。
按这三个全局根对象身份及已有最多16层祖先检查排除，
不依赖移动、来源记录、可见性或脚本读取；不禁用插件，不修改第三方框体。
这是一条用户指定的目标排除，不扩大为所有鼠标装饰或相似名称的黑名单。

实现前预算：删除运动检测、8条跟随记录和额外属性读取；在现有 CheckFocus 中增加
三个全局读取和每层身份比较，无新增缓存、Frame、Region、timer、hook或事件。
沿用0.1秒活动采样、16层祖先、512候选上限与128对象/0.75ms批次。
首次采样即排除；关闭/战斗生命周期不变。预算沿用已有完整契约，空闲新增活动为0。

版本证据：wowdoc source list/check、inspect GetParent；sourceId=wow-ui-source，product=retail，
requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。
`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleObjectAPIDocumentation.lua:34–46`
声明GetParent返回CScriptObject，SecretReturnsForAspect=Hierarchy。
使用现有保护读取 GetParent 遍历祖先，禁止访问/secret处理不变。

回归先失败于 `cursor addon is excluded on the first stationary sample without creation-source records`，
修复后通过首次静止选择、匿名冷却子层、空白区域、设置后代、未加载与延迟加载场景。
移除已不适用的运动判断测试，保留600次原生排序对照与其余可见性回归。
完整 `tests/check_contract.ps1` 通过（原始输出 `%TEMP%/lychee-cursor-exclusion-contract.log`）；
wowdoc validate：76个Lua文件，valid=true、diagnostics=null；git diff --check通过。
运行时无新增对象或缓存，关闭后无活动采样；提交后按项目流程同步唯一正式服Lychee目录并校验哈希。
实机需 /reload，离线检查不代替游戏验证。
