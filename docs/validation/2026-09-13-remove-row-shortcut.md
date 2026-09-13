# 移除结果行次要操作快捷按钮

- 根据用户截图移除结果行右侧“…”按钮及该按钮的悬停提示，删除其动作派生、点击绑定、事件脚本与安全覆盖层中的层级处理。结果行主操作、拖动、常规 tooltip 和右键菜单保持原有入口；“定位背包”等附加动作仍由右键菜单访问。
- 来源标签固定距右缘 12，不再随选中项切换至 42。DESIGN.md 同步明确这一规范。
- 八个复用行各减少一个 Button、一张背景 Texture 和一个 FontString，同时减少对应交互绑定；无新增事件、timer 或逐帧工作，性能门槛未修改。
- 定向回归验证无行内快捷按钮、分类锚点稳定、右键打开当前行菜单；真实 Provider/Palette 装配验证列表重绑定后旧菜单点击失效，重新右键仍可执行当前条目的次要动作。
- `python tests/run.py --report analyze/tests/remove-row-shortcut.json`：93/93 通过，包含 Lua/XML/Python 解析、TOC、发布、SDK、交互和性能门禁。tooltip 静止 1000 帧为 0.00 KiB 分配、零新增对象。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44 个 Lua 文件，valid=true，无诊断。`python tools/check_repository.py` 和 `git diff --check` 通过。

版本证据：本轮 source list/check 后固定 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=12.1.0`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua:271` 定义 `Name = "RegisterForClicks"`，参数为 `buttons:ClickButton`，`StrideIndex=1`。结果行既有 `RegisterForClicks("LeftButtonUp", "RightButtonUp")` 保留；本次没有增加 API 调用。

离线测试不等于实机验证，尚未取得移除后的游戏截图或战斗/taint 测量。无新模块或 TOC 变更，游戏中 `/reload` 后检查按钮消失、来源对齐和右键操作。提交成功后按五包发布清单覆盖同步，核对 SHA-256 并保留旧文件；同步记录为 analyze/tests/remove-row-shortcut-sync.json。
