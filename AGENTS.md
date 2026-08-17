# Lychee 性能优先开发准则

本文件是本插件的实现与评审约定。目标是让插件在战斗、团本、大量姓名板和低端硬件上保持稳定帧时间，而不是只在登录时看起来加载很快。

## 参考基线

本准则根据 [EllesmereGaming/EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI) 当前代码整理。抓取基线为提交 `1b37158d7533deb2d5b0a74292438a8ea2191588`（Release v8.9.1，2026-08-17）。该仓库根目录没有 README；因此以下结论来自实际 Lua 实现、各模块注释、`SKINNING_API.md` 和 `CONTRIBUTING_TRANSLATIONS.md`，不把不存在的 README 内容当作依据。

可对照的上游模式：

- `EllesmereUI_Ticker.lua`：订阅数为零时隐藏驱动；数组 + 索引表做 O(1) swap-remove；动画优先使用 AnimationGroup。
- `EllesmereUI_UICore.lua`：重刷新按成本分层，重 widget 刷新约 15 Hz；完整 GC 延后到过渡结束后数帧。
- `EllesmereUI_AuraKit.lua`：过滤器和颜色曲线缓存；样式字段生成 key，只有 key 改变才调用昂贵的 `Set*`；受限 API 采用 `pcall` 分级降级。
- `EllesmereUIRaidFrames/EUI_RaidFrames_AuraContainers.lua`：批量/池化 aura 按钮、缓存 frame level 和曲线、成功后再写状态戳。
- `SKINNING_API.md`：皮肤注册一次完成；原语幂等，重复调用只做一次查表；没有 OnUpdate、事件或每帧工作。

## 1. 总体原则

1. **先量化，再优化。** 任何新增常驻逻辑都要说明触发频率、受影响对象数量、战斗中最坏路径和预期 CPU/内存成本。没有数据时先用 `GetFunctionCPUUsage`、`GetAddOnCPUUsage`、`UpdateAddOnCPUUsage`、`debugprofilestop` 或本地计数器建立基线。
2. **默认零空闲成本。** 功能未启用、窗口隐藏、没有活动动画/任务时，不应运行 Lua 回调。驱动必须 `Hide()`/注销；不要保留无条件运行的全局 `OnUpdate`。
3. **事件驱动优先于轮询。** 能由 `UNIT_AURA`、`UNIT_HEALTH`、`PLAYER_TARGET_CHANGED`、`NAME_PLATE_*`、`BAG_UPDATE_*` 等事件表达的状态，不得用每帧扫描替代。必须轮询时给出固定间隔、停止条件和对象上限。
4. **把工作放到正确的层。** 能交给 WoW C 引擎的动画、冷却、状态条和滚动框，不在 Lua 每帧重算；Lua 只在事件、节拍或状态变化时提交新值。
5. **局部增量更新。** 状态改变哪个对象就更新哪个对象；禁止为了一个图标/字段重建整页、整组或所有单位框。

## 2. 更新循环、动画与计时器

### 2.1 驱动契约

- 使用共享驱动或模块自己的 driver；driver 只在第一个订阅者加入时显示，最后一个移除时隐藏。
- 订阅 key 必须稳定且幂等：重复 `Add(key, fn)` 是替换，不是追加；结束路径必须无条件 `Remove(key)`。
- 回调内允许移除自身；使用密集数组 + key→index 映射，移除采用 swap-remove，避免 `table.remove` 的 O(n) 搬移。
- 回调只读取已经缓存的状态，避免在同一 tick 内重复调用昂贵 API、字符串拼接或创建闭包。

```lua
local driver = CreateFrame("Frame") -- 在本模块主 chunk 创建，归因清晰
local Tick = EllesmereUI.Tick.NewDriver(driver)

local function Arm(key, update)
    Tick.Add(key, update)            -- 幂等，不要先 Has 再 Add
end

local function Update(elapsed)
    -- 只处理已变化的对象；完成后立刻自移除
    if settled then Tick.Remove("my_feature") end
end
```

### 2.2 选择更新机制

- **一次性变化：** 事件回调里直接 `SetValue`/`SetShown`。
- **平滑过渡：** 使用 `AnimationGroup`、`Animation`、`Cooldown` 或原生 StatusBar；不要用 Lua `OnUpdate` 模拟可由 C 侧完成的补间。
- **真实时间节拍：** 使用固定间隔的 Animation ticker（例如 0.05 s），回调返回 false 时停止；不要用每帧 ticker 做 0.5 s 轮询。
- **必须每帧：** 仅限鼠标跟随、确实依赖 frame delta 的短动画等；运行期间需可见/可用，结束立即隐藏或解绑。
- **节流：** 视觉更新与重计算分离。便宜的颜色/alpha 可每帧更新，昂贵的 widget/layout 刷新应累积 elapsed 后以约 10–15 Hz 执行。
- **延迟重活：** 切换主题、批量销毁或大量重建完成后，将 `collectgarbage("collect")`、全量刷新等工作延后至少数帧，避免与渲染峰值同帧发生。

### 2.3 反模式

- `OnUpdate` 中遍历所有 group/unit/aura，并在每个元素调用多个 `Get*`。
- 为了“确保状态正确”每帧重复 `SetPoint`、`SetSize`、`SetTexture`、`SetFont`、`SetColorTexture`。
- 创建多个互相独立的 ticker，让每个小组件各自跑一份循环。
- 动画结束后仍保留回调、ticker 或可见驱动。

## 3. 事件与生命周期

- 在 `OnEnable`/`PLAYER_LOGIN` 之后再创建依赖数据库和玩家状态的 UI；静态资源、常量和可复用 frame 可在主 chunk 初始化。
- 只注册需要的事件；对 unit 事件优先 `RegisterUnitEvent(event, unit)`，不要让一个 handler 接收所有单位再过滤。
- 窗口隐藏、功能关闭、离开相关场景时注销或停用事件；`OnShow`/`OnHide` 要成对管理驱动。
- 事件 handler 只做去抖、记录 dirty 标记和局部更新。多个同帧事件合并成一次刷新，可用 `C_Timer.After(0, Flush)`，并保证 Flush 幂等。
- LoadOnDemand 模块和可选依赖必须有短路路径：依赖不存在、客户端版本不支持或功能未启用时立即 return，不创建 frame、不注册事件。
- 关闭/重载前清理 ticker、hook、临时表引用和待执行 timer，避免隐藏对象继续保活。

## 4. 对象、布局与内存

1. **创建一次，反复复用。** 行、图标、aura、姓名板 overlay 使用池或预创建批次；刷新时重置字段并 Hide 多余对象，不在每次事件中 `CreateFrame`。
2. **批量创建。** 对可预测数量的子对象一次性建立（上游 aura engine 以批次创建按钮），把初始化放在“对象创建时”，不要放在每次 Show。
3. **缓存稳定结果。** 规范化字符串、过滤器、颜色曲线、纹理路径、样式 key、frame level 等结果按输入 key 缓存；缓存键要包含所有影响结果的字段。
4. **状态戳与 change guard。** 先比较 `appliedKey`/字段快照，未改变就跳过 setter。调用可能因 secret/taint 失败时，必须在成功之后写戳，不能预写导致之后错误跳过重试。
5. **复用临时容器。** 热路径避免 `{}`、`table.concat`、`string.format`、匿名闭包和大量短字符串；可复用 scratch table，清空用 `wipe`/手动 nil。不要为了微优化牺牲可读性，先用 profiler 证明属于热点。
6. **数组优先。** 高频遍历用连续数组和数值 `for`；字典 `pairs` 只用于低频配置/初始化。需要删除的数组项使用 swap-remove 或 free-list。
7. **避免隐性保活。** 隐藏 frame、timer、闭包和事件注册仍可能持有大型表；功能关闭时断开引用，池中对象只保留必要的共享资源。

## 5. UI 调用与 WoW 限制

- 原生 UI setter 属于有成本的边界调用；对 `SetPoint`、`ClearAllPoints`、`SetSize`、`SetTexture`、`SetVertexColor`、`SetFrameLevel`、字体和 mask 操作做 change guard。
- 不要反复拆装 mask、边框、cooldown 或层级；把几何/样式 key 绑定到对象，key 不变时不重绑。
- 对可能被 secret value、战斗锁定或客户端版本拒绝的 API，集中使用小范围 `pcall`，按“完整参数 → 去掉可选项 → 最小参数”降级；不要用全局大 `pcall` 掩盖逻辑错误。
- `pcall` 返回值必须被检查；失败时保留 dirty 状态并在限制解除后重试。只有真正成功才更新缓存戳。
- 保护框架和 Blizzard frame 只做允许的安全操作；皮肤/装饰优先 alpha、纹理和自有子 frame，避免 `Hide`、`SetParent` 等可能产生 taint 的操作。
- 将颜色、字体、尺寸等 canonical 状态放在单一表中，注册一次性元素；主题变化走局部 re-apply，不做整棵 UI teardown/rebuild。

## 6. 配置、数据和模块边界

- 配置读取集中在低频入口；热路径把 `db.profile`、当前 spec、颜色和开关解析成局部或轻量快照，配置改变时使快照失效。
- 不在战斗中迁移/深拷贝整份 SavedVariables；迁移一次完成并记录版本，后续读取走兼容默认值。
- 模块通过窄接口通信，避免每帧跨模块广播。需要广播时发送“哪个 key 变了”，订阅者自行判断是否相关。
- 本地化字符串在加载期生成；英语 key 保持稳定，避免在战斗热路径查找、拼接和格式化长文本。
- 可选功能按模块延迟创建。功能开关关闭时，不仅隐藏 UI，还要停止事件、ticker、timer 和数据采集。

## 7. 性能验证要求

每个影响常驻路径的改动至少记录以下场景的基线与修改后结果：登录、站立空闲、战斗单目标、战斗多目标/团本、姓名板峰值、配置页面打开/关闭。记录 CPU（总量与每秒）、对象数量、Lua 内存和帧时间；不要只凭主观“感觉更快”。

建议的最小验证步骤：

1. `/console scriptProfile 1`，`/reload`，执行目标场景；完成后 `/console scriptProfile 0`。
2. 用 `UpdateAddOnCPUUsage()` 后读取 `GetAddOnCPUUsage("Lychee")`；对比同一场景、同一持续时间。
3. 对短函数用 `debugprofilestop()` 包围采样，至少取冷启动、稳态和峰值三段；采样代码必须可关闭并不得留在默认热路径。
4. 检查 `GetMouseFocus`、驱动 `Count`、正在播放的 AnimationGroup、timer 数量、池峰值和 active frame 数，确认功能关闭后归零/隐藏。
5. 用 `/fstack`、`/eventtrace` 和错误日志确认没有重复注册、重复 hook、secret API 错误或受限失败后未重试。

性能回归门槛（除非有明确产品理由并在 PR 中记录）：

- 空闲状态不新增常驻 Lua 每帧回调。
- 战斗稳态不新增全量扫描；新增轮询必须有固定间隔和停止条件。
- 单个事件只刷新受影响对象；不得因局部变化触发全页重建。
- 热路径不得产生可避免的 frame、table、闭包或字符串分配。
- 任何性能换取必须同时验证 taint、战斗锁定、客户端版本和功能关闭路径。

## 8. 代码评审清单

- [ ] 触发源是事件/节拍，而不是无条件 `OnUpdate`。
- [ ] 驱动在无订阅者时隐藏，订阅结束时必定 Remove/Stop。
- [ ] 更新范围是 dirty 对象，且 setter 有 change guard。
- [ ] 新对象来自池/复用层；初始化与刷新职责分离。
- [ ] 缓存 key 覆盖全部输入，失败调用不会错误写入成功状态。
- [ ] 主题/配置变化走增量刷新，没有同帧 teardown + 全量 GC。
- [ ] 受限 API 有局部 `pcall` 与降级/重试，错误不会被静默吞掉。
- [ ] 依赖缺失、功能关闭、窗口隐藏和模块卸载路径都停止后台工作。
- [ ] 已在空闲、战斗和峰值对象量下采样 CPU/内存，并附上命令、持续时间和结果。

违反以上规则时，PR 描述必须给出具体测量、影响范围和回滚方式；“看起来没有开销”不算验证。

## 9. Git 提交与正式服同步

### 9.1 固定路径

- 源码仓库：`D:\Code\wow\addons\Lychee`
- 正式服插件目录：`D:\Game\World of Warcraft\_retail_\Interface\AddOns`
- Lychee 正式服副本：`D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`

### 9.2 每次代码修改的强制顺序

1. 修改 Lua/XML/TOC/媒体等源码文件。
2. 执行静态检查、针对性测试和 `git diff --check`；确认没有调试输出、临时文件或无关改动。
3. 查看 `git status --short`，只暂存本次变更相关文件。
4. 创建一次有描述性的 Git 提交：

   ```powershell
   Set-Location 'D:\Code\wow\addons\Lychee'
   git add <本次变更文件>
   git commit -m "描述本次变更"
   git rev-parse --short HEAD
   ```

5. 只有提交成功并记录 commit hash 后，才复制到正式服副本。
6. 复制完成后检查源目录与正式服副本的文件清单和关键文件哈希；再通过游戏内 `/reload` 或重启客户端验证。

未提交成功时，不把源码复制到正式服目录。代码改动、提交和复制必须在同一轮工作中完成；最终报告包含 commit hash、复制目标和验证结果。

### 9.3 正式服复制规则

- 复制目标固定为 `...\AddOns\Lychee`，不要直接把源码文件散落到 `AddOns` 根目录。
- 只复制插件运行时文件：Lua、XML、TOC、媒体和运行所需资源。
- 排除 `.git`、`.codex`、`AGENTS.md`、验证记录、补丁文件、编辑器配置和临时产物；这些文件保留在源码仓库。
- 复制前确认目标路径存在且最后一级目录名为 `Lychee`；路径检查失败时停止复制。
- 默认使用覆盖复制，不自动删除正式服目录中的文件。需要清理已删除的旧文件时，先列出删除清单并确认后再执行定向删除。
- 游戏客户端运行期间完成复制后使用 `/reload`；涉及 TOC、加载顺序或新增模块时重启客户端验证。

### 9.4 推荐复制与校验命令

```powershell
$src = 'D:\Code\wow\addons\Lychee'
$dst = 'D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee'

if (-not (Test-Path -LiteralPath $src)) { throw "源码目录不存在: $src" }
if (-not (Test-Path -LiteralPath (Split-Path $dst))) { throw "AddOns 目录不存在" }
New-Item -ItemType Directory -Force -Path $dst | Out-Null

Get-ChildItem -LiteralPath $src -Force -File -Recurse |
    Where-Object { $_.FullName -notmatch '\\.git(\\|$)|\\.codex(\\|$)' -and $_.Name -notin @('AGENTS.md') } |
    ForEach-Object {
        $relative = $_.FullName.Substring($src.Length).TrimStart('\\')
        $target = Join-Path $dst $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }

Get-ChildItem -LiteralPath $dst -File -Recurse |
    ForEach-Object { $_.FullName.Substring($dst.Length).TrimStart('\\') } |
    Sort-Object
```

### 9.5 回滚

- 回滚源码使用新的 `git revert <commit>`，保留可追溯历史；不要直接改写已交付 commit。
- 回滚提交后重新执行同样的验证、提交和复制流程。
- 正式服副本必须与已验证的 commit 对应，报告中同时记录回滚 commit 和复制结果。
