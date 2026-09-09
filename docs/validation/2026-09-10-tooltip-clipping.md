# Tooltip 滚动裁切修复

日期：2026-09-10。基线：4d7237d。用户截图中，最近使用上方只露出提示框底部的“拖动 放到动作条”。

## 复现与判断

命令：lua tests/result_list_ui_smoke.lua。

在实际 ShowItemTooltip 调用链外建立最近使用同构的 ScrollFrame → content → Button 层级，模拟滚动视口上沿 600、入口上沿 556，屏幕上沿 900。提示框位于屏幕内，但超出滚动区域。修复前确定性失败：

recent tooltip clipped by scroll ancestor: only 1/5 lines visible

文字都已生成。由于 showTooltip 将提示框 SetParent(owner)，它进入了滚动子树。仅删除该重设父级调用后，同一复现通过，五行均可见。该结果来自离线裁切模型，不是原生客户端渲染采样；修改后实机仍需 /reload 确认。

## 修复

提示框保持创建时的 UIParent 父对象，SetPoint 仍定位到入口。屏幕 clamping 保留。搜索结果和最近使用的 OnHide 负责清理提示框，最近内容替换、条目失效、动作菜单打开、窗口关闭同样隐藏并释放 owner。样式、字号、红线和交互不变。

## 验证

- 原始裁切回归由失败变为通过。
- 10 项契约测试全部通过，包括根节点提示框在结果/最近视图隐藏时清理，以及现有菜单、技能按钮、最近使用、拖动、动态查询。
- 45 个 Lua 文件解析与 Bindings.xml XML 解析通过。
- wowdoc validate：valid=true，checkedLua=30，diagnostics=null。
- git diff --check 通过，无临时日志。
- 原对象池保持不变；减少悬停/离开时 SetParent 调用，新增两处 OnHide 脚本，仅在视图隐藏时调用。无新增 Frame、纹理、timer、事件订阅或 OnUpdate。

## 来源与交付边界

sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；source check 显示本地与远端一致。

[来源记录](../architecture/2026-09-10-tooltip-clipping-wowdoc.json) 含 SetParent、SetPoint 与 GameTooltip_OnHide 的 path/line/excerpt。开始修改前已读取同版本生成 API 和 Blizzard OnHide 实现；[静态结果](../architecture/2026-09-10-tooltip-clipping-validate.json)。

本轮未获得修改后的实机截图，也没有真实客户端 CPU、内存、帧时间、taint 或安全点击测量。检查和提交成功后复制运行时到固定正式服目录，核对全量文件清单与 SHA-256；无 TOC 变化，可 /reload。回滚使用新 git revert 提交并按相同顺序验证与同步。
