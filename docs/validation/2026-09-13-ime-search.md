# 输入法组词引起的搜索列表跳动

基线提交：2693a0dfb21b78c8e2e39e141f18702852ca1514。用户提供 `C:/Users/follen/Videos/20260913-173025.mp4`，18.77秒、30fps。抽帧保存在本地 `analyze/search-jump-173025/`，不随运行包交付。

## 复现与根因

录屏约1.6秒，组词中的 `d` 已显示长结果列表；约2.0秒 `du'ya` 时列表清空、窗口仍高；提交“毒牙”后重新填充。约5–6秒，`tu'jin` 与提交“突进”再次呈现等待空白、结果填入和高度收缩。该录屏的可见触发点是输入变化。

Input 的 OnTextChanged 将每次预编辑文字传给 Palette，再由 SearchSession 清空结果并调度查询。查询返回后触发列表与高度更新；旧高度动画和异步结果可能继续影响正在选词的画面。原有重开布局与查询代次防护没有区分未提交的 IME 文本。

先增加 `tests/ui/input_composition.lua`，经实际 Input → Palette → SearchSession → Provider 链路驱动输入。修复前运行 `lua tests/ui/input_composition.lua`，在 `IME preedit must not query providers` 断言失败；修复后通过。输入法状态、原生Frame和计时器由离线替身提供，不能据此认定原生事件顺序已验证。

## 修复与生命周期

- Input读取原生 IsInIMECompositionMode。一次组词仅通知一次暂停；后续预编辑不查询、不改变模式。原生状态结束后的文本变化恢复查询，包括取消后回到原词。
- Palette停住当前高度动画，不跳到旧目标；关闭旧tooltip/菜单并释放安全动作覆盖层。显示的结果引用保留，但查询身份失效，不能继续执行旧动作。
- Session取消去抖、进行中的查询与来源刷新，只发布身份和等待状态，不发布空列表。组词期间来源更新仍标记首页失效，停止实际重建和查询；提交后走正常刷新。
- Enter、方向键和Esc在原生组词状态中不触发搜索列表操作。禁用输入立即清除状态并忽略文本回调，关闭、动画中途重开和战斗退出均清理会话暂停。
- 缺少原生IME方法的客户端沿用普通输入路径；没有假定其他客户端支持该方法，也没有新增未查到的组词事件。

触发源是现有文本/键盘事件。每次文本事件常数次状态检查；每段组词至多一次取消，取消成本沿用现有有界查询资源清理。仅当前Input与Session各持有一个标量状态，首次创建输入控件时增加一个回调；不建Frame、纹理、逐帧驱动、timer、字符串缓存或结果副本。空闲不执行新工作，战斗仅沿用已有关闭清理。CPU、内存及对象预算继续由 PERFORMANCE.md 定义，没有放宽门槛。

## WoW接口证据

修改前执行source list/check与精确inspect；sourceId=`wow-ui-source`，product=`retail`，requestedRef=`12.1.0`，resolvedCommit=`8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

路径 `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua`，509–518行摘录：

```lua
Name = "IsInIMECompositionMode",
Type = "Function",
Arguments = {},
Returns = {
    { Name = "isInIMECompositionMode", Type = "bool", Nilable = false },
},
```

`wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：45个Lua文件，valid=true，无诊断。这里只证明接口静态证据，不证明特定系统输入法的提交/取消事件顺序。

## 验证范围与交付

新回归覆盖连续拼音、提交/取消、选词按键、旧异步reply、已排去抖的迟到timer、来源刷新、空预编辑首页、正在运行的高度动画、动画中途重开、战斗关闭与缺失API回退。100次连续预编辑新增Frame为0、不发起新查询。查询生命周期回归新增SuspendInput取消回调重入，保证不能覆盖回调创建的新查询。

最终 `python tests/run.py --report analyze/search-jump-173025/tests.json`：103/103通过，包含Lua/XML/TOC静态检查、完整契约、性能与188文件发布清单检查。文档链接/版本检查和 `git diff --check` 通过。完整正式服加载1853.2012KiB/23ms，不含LDT为1491.1563KiB/20ms；相对基线1850.2109/1488.1660KiB均增加约2.99KiB，仍为2Frame/4事件登记。最近使用100轮离线交互240ms总量、4ms峰值、0新增Frame；此测量不代表真实客户端帧时间。

游戏仍需执行 `/reload` 后按原录屏重复输入“毒牙”“突进”，检查候选选择、取消组词、方向键/Enter/Esc的真实事件顺序，以及打开、关闭和不同输入法配置。当前没有修改后实机录像或taint/帧时间证据，不能把离线通过说成实机问题已消失。

检查通过并提交后，按五包188个运行文件覆盖同步并核对SHA-256，保留目标旧文件。提交和同步清单保存在 `analyze/search-jump-173025/sync.json`；本次无新模块或TOC变化。
