# 插件识别恢复鼠标焦点方案

用户要求保留原方案，仅修复漏识别；撤销 `4de68c2` 引入的原生 FrameStack 取样。使用 `git revert --no-commit 4de68c2` 生成回退，再保留两个独立修正，不改写历史。

## 最终范围

- 仅通过 `GetMouseFoci` 取得目标。第一项为根框体、受限对象或 secret 时，继续检查后面的有效焦点，最多 32 项。
- Shift 先取得第一个有效目标再冻结；没有目标时保持摘要，不展开空白详情。
- 删除私有 GameTooltip、SetFrameStack 及取样生命周期。也撤掉了尚未交付的模板隔离、原生候选遍历、透明度与区域绘制判断。
- 动态创建来源、父级推断、现有跟随窗口与动作保持原方案。没有外部插件名称黑名单，不操作正常 GameTooltip 或 `/fstack`。

边界：不接收鼠标输入、未出现在焦点列表中的装饰文字或纹理仍可能取不到。本次不宣称与 `/fstack` 的识别范围相同。用户反馈的空黑框尚未在真实客户端复现到具体对象；撤销新增取样 Tooltip 消除这次改动带来的交互路径，不据此断言黑框属于哪个插件。

## 回归

命令：`lua tests/addon_inspector.lua`。

在原方案上先添加 `[WorldFrame, forbiddenFrame, validFrame]` 的回归，实际失败：

```text
invalid first mouse focus must not hide later valid targets
```

修复后通过。测试同时覆盖按住 Shift 启动、空白处 Shift、取得目标后冻结，以及已有复制／Esc／战斗／禁用／过期回调。CreateFrame 替身拒绝创建 GameTooltip，防止再次引入取样提示框。

本轮 Lua 5.1 离线样本：7 个 Frame 替身、35 个 Region 替身，首次保留 35.4 KiB；100 次开关累计分配 345.7 KiB、保留增长 0.5 KiB、总耗时 2 ms。10,000 次跟随耗时 8 ms、分配 0 KiB、来源读取 0、重复锚点写入 0。仅为离线预算结果，不代表游戏实测。

生命周期维持原有约束：首次使用创建并复用窗口；仅活动模式一个 0.1 秒定时器；每帧只跟随鼠标；目标变化时才解析来源；退出／禁用／战斗停止全部活动。无新增对象、缓存或常驻驱动。焦点检查最多 32 项，每项自身排除检查最多 16 层；不遍历全局框体。

## wowdoc 依据

- sourceId: `wow-ui-source`
- product: `retail`
- requestedRef: `latest`
- resolvedCommit: `8ea15b61e45c0ed4eba01439c90757f86eb78d34`
- path: `Interface/AddOns/Blizzard_APIDocumentationGenerated/InputDocumentation.lua`
- line: `54`
- excerpt: `Name = "GetMouseFoci"`，返回 `Type = "table", InnerType = "ScriptRegion"`（第 59 行）。

本轮已核对 source check，本地与远端一致。完整契约检查、Lua/XML/TOC 检查、wowdoc validate、diff 检查在提交前执行。游戏内仍需 `/reload`，销毁上一版已经创建的取样对象，再核对正常提示框和原有识别交互；本次未改加载顺序，不需要重启客户端。

执行结果：`tests/check_contract.ps1` 全部通过；wowdoc 校验 75 个 Lua 文件，`valid=true`、无诊断；`git diff --check` 通过。未进行游戏内验证。
