# 别名管理页面统一

基线 a97f81a。用户截图显示别名页按钮比正文更粗大、返回缺少方向提示，并同时显示一级标签与二级返回。代码确认 AliasSettings 的按钮包装未调用 Theme:SetFont，且 OpenAliases 未像 OpenProvider 一样隐藏标签。

成本和生命周期：保持原九行最大复用池，仅首次增加两个返回箭头纹理和一个页名 FontString。没有新事件、轮询或 timer。页面打开、切换编辑和列表数据量改变时，经 Palette 通用 settings-detail 高度入口与原 Motion 驱动调整窗口；相同目标高度跳过。短列表收缩，长列表保持 518 上限，返回恢复一级设置高度。关闭仍清焦点、停止滚动拖动并释放记录引用。

调整：统一 12 号按钮、11 号别名说明、左侧 8 内距和右侧操作边线；返回使用箭头和左对齐文字；编辑的保存／取消靠右；进入二级页隐藏标签、返回恢复。保留原别名设置、删除、搜索和旧点击身份契约，鼠标按下包装继续调用公共按钮状态处理。

验证：完整 `tests/check_contract.ps1`、wowdoc validate（71 Lua，无诊断）、diff --check 通过。交互回归覆盖进入隐藏一级导航、短列表收缩、返回恢复高度、长列表高度上限、编辑保存／取消、删除与旧点击保护、20 次反复打开无新增 Frame；内容／视口高度变化时更新原生滚动边界，无变化跳过。1,000 来源性能场景仍为 8 行、356 个替身对象、458.0 KiB 保留、20 次刷新分配 37.4 KiB、池增长 0。

用实际 AliasSettings.lua 的离线锚点投影检查简中／英文列表、空列表和编辑态，无操作重叠，短列表不再撑满窗口。投影使用替身字体与主壳，不是游戏截图。证据位于忽略目录 `.codex/alias-contact-sheet.png`、`preview_alias.py`、`alias-page-full.txt`。游戏客户端字体、缩放与高度动画待实测；提交同步不代表游戏验收完成。

查档：sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。先 source list/check，无待更新；Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua:199，excerpt `Name = "SetFont"`，参数 fontFile、height、flags。本轮复用既有 SetHeight 和 Motion，不新增原生 API。

同一来源版本的 Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:115，excerpt `Name = "UpdateScrollChildRect"`，无参数；用于内容或视口几何变化后的边界同步。
