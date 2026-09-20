# 综合设置

把动态效果从设置页顶部移到新增的“综合设置”标签，功能来源/已固定导航保留。综合设置行沿用共享尺寸，右侧标准/减少切换保留原有保存方式。

首次进入才创建一行、图标、两段文字和操作控件，之后复用。切页停止旧区域动画，来源列表隐藏并释放绑定身份；无新增事件、timer 或每帧工作。公共 UI 预算测试 1,000 来源、8 行、324 替身对象、427.1 KiB，20 刷新 37.4 KiB、池增长 0；不代表游戏引擎内存。

新增真实设置导航回归验证：进入综合设置、修改选项、返回来源、重新进入复用原控件。完整契约、Lua/XML/TOC 静态、wowdoc validate 45 Lua / valid=true、diff 检查通过，日志 general-settings-checks.txt。

API 使用既有 SetShown/SetPoint/Frame 构建，wowdoc sourceId=wow-ui-source / product=retail / requestedRef=latest / resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；SimpleFrameAPIDocumentation.lua 定义 SetShown。未改变加载顺序，reload 生效；游戏内视觉与操作尚待确认。
