# UI 性能审查与设置页虚拟化

基线：`4e12531`；优化源码由本轮统一提交记录。范围为 `package/Lychee/UI` 全部 8 个 Lua 模块，实际修改 `SettingsView.lua`。按根目录 PERFORMANCE.md 执行。

## 成本、预算与生命周期

- 设置页首次打开才创建；刷新触发源为切换页签、固定项编辑或来源状态变更；没有 OnUpdate、ticker 或新增 timer。
- N 为当前来源数或固定项数，K 为可见行数。旧实现每次 Refresh 全量解析固定项，并按 N 创建永久行；新实现刷新复用元数据、计算排序及 y 坐标，滚动二分定位首行，处理 `O(log N + K)`；排序刷新仍为 `O(N log N)`，并未宣称消除所有全量工作。
- 永久行池预算为历史最大视口 `ceil(height / 46) + 1`（包含部分可见行），仅按实际需要扩容。正常窗口高度受 Palette 的 600 上限约束；标题组最多 2 个，空列表复用 1 个。
- 元数据表由 SettingsView 独占，容量为当前 N，不保留历史来源。每次刷新复用条目并截短尾部；关闭释放整份快照和行交互 ID。Frame/文字/纹理结构保留复用，Hide 不代表销毁。
- 固定项只有可见时调用 Resolve；用于绑定后立即清除快照中的 resolved item，只保留必要的标题、pin、位置。撤销继续保留最后一项已删除 pin，为既有产品行为。
- 滚动和重绑均在战斗中直接返回；隐藏只清 Lua 引用，不操作受保护几何。重新打开重新整理数据；尺寸变化按事件重新绑定，不轮询。
- 测试预算：400 高视口不超过 10 行；1,000 来源新增替身保留内存小于 1 MiB；20 次相同刷新累计分配小于 512 KiB。时间只报告分布，不用 Windows Lua 粗粒度时钟设置不稳定门限。

## wowdoc 版本证据

先执行 `wowdoc source list --source wow-ui-source --product retail`，确认本地 retail/live 已有 12.1.0。查询统一使用 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=latest`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:103`：`Name = "SetVerticalScroll"`；105 行 `IsProtectedFunction = true`；111 行 `offset` 为 `uiUnit`。因此保留非战斗调用门禁。[原始证据](../design/2026-09-10-project-perf-ui-scroll.json)
- `Interface/AddOns/Blizzard_AccountSaveUI/Blizzard_AccountSaveUI.lua:169`：`function AccountSaveFrameMixin:OnSizeChanged()`，170 行通过 `self.Text:SetWidth(self.ContentInsets:GetWidth())` 响应尺寸变化；返回关系指向同目录 XML 第 81 行 `OnSizeChanged`。采用同类尺寸事件更新可见范围。[原始证据](../design/2026-09-10-project-perf-ui-size.json)
- 完整运行时 wowdoc validate 返回 `ok=true`；该命令是静态兼容性检查，不能证明游戏实际事件时序和 taint。[输出](../design/2026-09-10-project-perf-ui-validate.json)

## 可重复测量

Windows Lua 5.1，纯离线 Frame/Region 替身，1,000 个固定第三方来源，视口 400，30 个固定项；5 次基线/新实现交替独立进程。首次建立前先完整回收，首次操作后再回收计保留量；20 次重复刷新期间停止 GC 计累计分配，完成后恢复 GC。全部为替身 Lua 成本，不含 WoW C Frame、字体或纹理内存，不可冒充游戏插件内存。

| 指标 | 基线 | 优化后 |
| --- | ---: | ---: |
| 首次来源行数 | 1,000 | 9 |
| 替身对象总数（含 Frame/Region/fixture parent） | 18,018 | 180 |
| 首次新增回收后保留 | 15,412.6 KiB | 446.1 KiB |
| 首次 Refresh 中位数 / 最大值 | 30 / 31 ms | 1 / 2 ms |
| 20 次 Refresh 中位数 / 最大值 | 46 / 48 ms | 19 / 22 ms |
| 20 次 Refresh 累计分配 | 5,946.0 KiB | 42.4 KiB |
| 20 次首尾往返后池增长 | 0 | 0 |
| 首次显示 30 个固定项的 Resolve 次数 | 30 | 9 |

[五轮原始输出](../design/2026-09-10-project-perf-ui-measurements.json)。旧源码运行 `--check` 在行池预算断言失败，证明测试能检出原问题。

### 交叉审查后的按下身份修复

交叉审查发现虚拟化在 `row2.up OnMouseDown → 滚轮向下 → 原按钮 OnMouseUp/OnClick` 时会把操作施加到新绑定条目。新增真实事件序列先报 `scroll during up press must cancel stale click`，再修复：每次换绑定增加代次，按下时保存代次，点击时同时校验代次和当前真实 pin/provider 对象。相同 pinIndex 被排序/删除替换、相同 providerID 被重新注册也会使旧按下失效。隐藏或禁用保持失效标记，重开/恢复不使旧点击复活；新一次按下恢复正常操作。按钮 OnMouseUp 继续使用原 Components 的视觉逻辑。

回归覆盖上移、下移、删除和开关的按下中滚动、同索引换 pin、同 ID 换 Provider、视图隐藏重开、单按钮隐藏恢复、禁用恢复，以及正常真实点击和旧直接 OnClick 测试。全部通过。守卫只存标量代次及当前可见对象身份，不持有按下时旧记录，不新增 Frame、timer 或每帧轮询。最终数据已包含守卫成本：首次保留较第一轮虚拟化多约 9 KiB，20 次刷新分配为 42.4 KiB，仍低于 512 KiB 预算。

修改前追加 wowdoc `OnMouseDown` 查询，同一 retail commit，返回 `Interface/AddOns/Blizzard_AlliedRacesUI/AlliedRacesModelControlButtonMixin.lua:11` 的 `OnMouseDown` 实现以及相关脚本绑定关系；[原始证据](../design/2026-09-10-project-perf-ui-press.json)。

命令及结果：

```text
lua tests/performance_ui.lua analyze/project-performance-2026-09-10/baseline/package/Lychee
  PASS（只测量）；加 --check 在 row pool must be bounded by viewport 失败
lua tests/performance_ui.lua --check
  PASS：池预算、保留/分配预算、末行来源开关、绝对固定索引、禁用末项下移、跨视口拖动、600 高重排、战斗滚轮无操作、关闭释放与重新打开、分组间距、空列表释放
lua tests/interaction_smoke.lua
  PASS：既有 secure combat / launcher / Provider views / menu / recent / scrolling / settings / pins
lua tests/result_list_ui_smoke.lua
  PASS
luac -p package/Lychee/UI/*.lua（逐文件）
  8 个模块 PASS
git diff --check
  PASS（仅 CRLF 工作区提示，无差异错误）
```

## 逐文件覆盖与未修改结论

| 文件 | 审查结论 |
| --- | --- |
| SettingsView.lua | 修复按 N 建真实行、全量 Resolve pins、反复分配列表；保留视觉位置和绝对拖动索引；新增关闭释放。 |
| ResultList.lua | 8 行固定池，Resize 不扩容；文字/纹理/选择状态有 guard；Clear 清 item/action/session。单例 tooltip 5 行，Hide 清锚点 owner。SetItems 中 EnableMouse 属重绑交互重置，未用可能与安全层失步的缓存替换。 |
| Palette.lua | 首次打开创建；首页从有限 pins（API 上限 64）与 recent（保存 8，显示 5）生成，不为搜索建全库控件；dirty 触发重新解析；原生菜单由 Blizzard 管理复用。GLOBAL_MOUSE_DOWN 只在可见时注册，延迟焦点检查会话，可见设置刷新仅一个 pending。首页有限结果仍在隐藏期间保留作为重开模型，不宣称完全卸载。对篡改超大 SavedVariables 的统一容量治理由主 Agent 的 Core 范围审查。 |
| Components.lua | 按创建期构建按钮和 surface；事件驱动视觉状态；原生菜单 attachment 在 compositor 复用时必须重新着色，不能跨其 reset 保留样式戳。未新增长期缓存。 |
| Theme.lua | canonical 不可变色表做 setter key；Font 成功后写字号戳；没有循环/订阅。当前主题和字体配置静态，不在本轮引入动态主题变更接口。 |
| Input.lua | 文本变化 guard，焦点/鼠标事件驱动；无输入轮询。 |
| FocusController.lua | 保存当前和上一个焦点，Restore 清引用；没有后台工作。 |
| ViewHost.lua | 单 panel owner；Unmount 先断开 panel 引用，再调用 Unmount/Dispose；第三方 factory 的实际资源释放属于外部实现边界，宿主无法销毁 WoW Frame。未为低频生命周期调用改写异常隔离。 |

## 剩余验证与风险

- 未运行游戏：登录、空闲、单目标/团本/姓名板峰值 CPU 和帧时间、实际 UI 缩放/裁剪、真实跨视口拖动、战斗切入及 taint 验证均待实机。此改动没有新增常驻驱动；不能据此宣称上述场景已通过。
- 高 N 首次设置元数据排序仍同步，但离线 1,000 来源首次已为 1–2 ms；不凭该值保证任意第三方 Resolve 回调成本。滚动最多调用可见 K 个 pin Resolve，无法抢占第三方同步回调。
- 性能收益来自 UI 对象与数据复用，不改变 API/TOC/布局尺寸；回滚应按最终统一提交执行新 revert，再按仓库交付流程同步。
