# 0.4.4 启动器快捷键与 /l

## 问题与实现

反馈为解除快捷键冲突后启动器仍无法打开，按键表现为跳跃。截图不能证明完整操作顺序或具体绑定。本次确认并修复的是首次安装的一条独立失败路径：0.4.3 在发现 Alt+空格被占用时写入 `defaultBindingComplete`，此后解除占用也不再尝试绑定。新增回归在修复前失败，修复后通过。

0.4.4 在默认绑定未完成时通过现有 Bootstrap 框体监听 `UPDATE_BINDINGS`；完成后退订，不增加轮询。已有自定义绑定和成功设置后的主动解绑仍保留。旧版本已经写入完成标记的角色不会被猜测为失败安装；可以输入 `/l`，在综合设置中主动重新设置快捷键。

新增 `/l` 与 `/lychee`，通过现有 `Lychee_Toggle` 开关启动器，共用战斗限制。综合设置的快捷键按钮捕获 Alt/Ctrl/Shift/Meta 组合，拒绝裸空格、回车和 WASD；普通绑定或覆盖绑定冲突均拒绝，保留第二槽。赋值后回读有效动作，保存失败时回滚内存中的换绑。Esc、换页、关闭（包括退场动画开始）停止捕获；控件首次访问创建后复用。

## 源码依据

- 暴雪源码：sourceId `wow-ui-source`，product `retail`，requestedRef `refs/tags/12.1.0`，resolvedCommit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`；PIN `PIN-86f3a38c315f34ce64b6408f03bb771e42db9379738e312e9417a48ad032a49f`。
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Keybindings.lua` 108–140：生成修饰键组合、读取旧动作并解除冲突；142–143：`SaveBindings(GetCurrentBindingSet())`；169–180：赋值失败时尝试恢复旧按键。源码 CAP `CAP-e0e2308ff207af9482468da19e10324b55255bbbb5dd012b258b7356f2e355a0`。
- `Interface/AddOns/Blizzard_SharedXML/BindingUtil.lua` 116–139：依次读取 Alt/Ctrl/Shift/Meta 状态并组成 chord。CAP `CAP-dcb1debff2a2277d86aa0c0677c1beb5c5906784e67519d120cfd8a6ffb8a899`。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua` 1424–1432：`SetPropagateKeyboardInput` 有限制，参数为 bool。仅在非战斗创建设置 UI 时设置；取消时关闭键盘捕获。CAP `CAP-a5c3fddc194c17b2e0c76515e184b08c57cb7a8b2ef0b8166699eb83673f619c`。
- EasyFind 作者源码 commit `644aa29af573dfb86056c48e5530ce4ab90a4fbc`：`Shared/Utils.lua` 992–1005 拒绝裸空格/回车/WASD，Esc 取消；`Search/Results/Rows/SettingWidgets.lua` 288–322 捕获按键并保存原生绑定。`Core/Main.lua` 839–889 的启动器自身使用账号配置和 override click，属于另一套绑定所有权；本次保留 Lychee 原生 `TOGGLELYCHEE` 绑定。
- 本地 Lychee Dev `addon/Bridge/ReceiverBindings.lua`：检查普通与覆盖绑定冲突；override 安装后再次回读有效动作。它保存自己的接收器选项，不保存玩家原生按键。本次借鉴有效动作回读与失败恢复。

## 验证与交付

- `tests/core/default_binding.lua`：冲突解除重试、保存失败、战斗延后、已有绑定、主动解绑和 legacy attempted。
- `tests/core/launcher_binding.lua`：组合键、保留按键、普通/覆盖冲突、第二槽、保存失败回滚、手动换绑期间同步事件、旧角色主动设置。
- `tests/ui/interaction_smoke.lua`：实际捕获控件的 Esc、组合键保存、换页、关闭、重开、复用及命令注册；使用原生控件替身，不是物理输入。
- 完整 `tests/check_contract.ps1`、修改 Lua 的语法检查、`git diff --check`、发布包检查通过。未降低性能门槛。
- 固定源码 `source validate`：`staticValid=true`，`complete=false`，10971 个动态/本地符号尚未解析，Interface baseline 未解析；不代表战斗、taint 或实机验收。
- 运行提交 `db100fc733f8620cbb2cb7ae573e6fc37bb47dd0`。发布工具输出 Lychee 200 文件；逐文件 SHA-256 核对后同步到 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee`，保留目标额外文件。

## 实机状态：等待重启

正式服 12.1.0.69933，PID 140100，灵止光/死亡之翼；CON `CON-9b494044ea4343229b893bfb474395a3`。修改前实机 Alt+空格普通及覆盖查询均为 `TOGGLELYCHEE`，SPACE 为 `JUMP`，绑定集为角色级 2。本角色没有复现反馈，不能据此否定其他用户的问题。

同步后执行一次受支持的 reload，并取得新 runtime 身份。更新验证 PRB `PRB-e9eb7d271be09670a4fff69378a4acfe34d8593a1b369fa782c3d2b4a0e99e53` 在新模块存在性断言处失败，未进入换绑；报告已验证，清理完成。后续只读观察 PRB `PRB-ca0b95a849ff8ee6b80c362887bb49b1e8a28ef1aab2ddc702c3586d5bdc2e40` 显示仍加载 0.4.3，没有 `LauncherBinding` 和 `/l`，而磁盘 Bootstrap 哈希与运行提交一致。因此新版本实机功能尚未验收，需要重启客户端后继续，不重复 reload 或手动注入新源码冒充正常加载。

待覆盖：新版本正常开关、捕获取消/关闭/重开、原生保存回读、冲突保护、解除冲突后的重试及保存后的恢复核对。物理鼠标/键盘输入、真实战斗与其他客户端/语言尚未实测。诊断文件和 CON 原始记录保留在主目录 `.lycheedev/binding-044` 与 `.lycheedev/live`，不进入运行发布包。
