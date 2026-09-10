# 动态效果开关

综合设置的“标准/减少”文字按钮缺少可点击提示，替换为已有 Components.CreateToggle，旁边明确显示开启/关闭。开启对应 reduceMotion=false，关闭对应 true；保持已有保存值和动画减少行为。

控件仍在综合设置首次访问时创建并复用；固定圆角 Region 增加仅限这一控件，沿用已有有界原生动画组，无新 timer、事件或常驻更新。回归验证操作后开关、状态文字、保存值一致；原有切页和重复进入复用验证保留。

完整 check_contract、Lua/XML/TOC、wowdoc validate（45 Lua，valid=true）、git diff --check 通过，见 motion-toggle-checks.txt。API 沿用版本化公共组件依据：wow-ui-source / retail / latest / 8ea15b61e45c0ed4eba01439c90757f86eb78d34，SimpleFrameAPIDocumentation.lua:1482 SetShown(shown)，SetPoint 与原生动画依据见前次记录。游戏内视觉尚待 reload 确认。
