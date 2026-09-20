# 仅显示红色滑块

移除公共 CreateScrollbar 的灰色轨道纹理；透明 12 宽命中区、红色滑块及全部滚动操作保持原样。每个滚动条少一个 Texture，无新增驱动、事件、缓存或热路径工作。DESIGN.md 同步为无可见轨道。

Lua/XML/TOC 静态检查、wowdoc validate（45 Lua，valid=true）、git diff --check 通过。完整契约中其他项目通过，背包冷启动首次 CPU 53 ms / peak 3.36 ms 超预算；保留原始失败日志，独立复测 Provider 仍失败；相关 interaction_smoke、ui_motion、performance_ui --check 单独通过，未放宽门槛。见 scrollbar-track-checks.txt、scrollbar-track-recheck.txt。该计时波动发生于未改动的 Provider 路径，不作为样式性能收益。

此改动仅删除绘制代码。目标来源 wow-ui-source / retail / latest，resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34，查档结果保存在 scrollbar-track-api.json。游戏内显示尚待 reload 确认；不将离线结果视为实机验证。之前报告的动画漏绘仍未定位，此改动不宣称解决该问题。
