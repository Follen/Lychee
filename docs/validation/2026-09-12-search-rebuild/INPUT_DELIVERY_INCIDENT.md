# 2026-09-12 统一诊断输入交付撤回

用户反馈将 468817 字节的 `runtime-unified-study.lua` 粘贴到 Lychee Dev Run 后，游戏立即无响应，尚未点击运行。没有证据证明测试代码执行，也没有确认进程崩溃退出。输入 SHA256 为 `88B339140A84A8B603DA7EB9151CDAD6CA90F878C7150887A3D918A7AE26F552`。

交付前通过 Lua 语法及隔离流程测试，但未验证原生多行 EditBox 对这一规模输入的布局能力。这个遗漏属于交付路径缺陷；不能将其解释为已测出的业务构建/GC 耗时。已停止巨大文本粘贴，不再覆盖剪贴板或操作当前游戏。

本机只读检查：当时 `Lychee Dev.lua` SavedVariables 长度 249720，最后修改 2026-09-12 14:24:30，没有 `lycheeLifecycleStudies`、`LYCHEE-STUDY-` 或旧 bundle 文本。该状态仍对应 Ticket `LYCHEE-20260912-142421-0010` 的采集证据。

当时安装的 `Lychee Dev/UI/MainWindow.lua`：CreateTextArea 约 533 行创建原生多行 EditBox；OnTextChanged 约 555 行更新 scroll child 几何，OnCursorChanged 延迟处理光标滚动。RunInput 约 825 行在显式执行后写历史；未发现输入草稿自动存档/自动重放路径。此代码路径提示原生输入/布局可能参与无响应，但不足以证明某个原生 API 是唯一原因。没有据此删除历史或存档。

用户决定改用独立 **Lychee Performance Test**：正常 TOC/Lua 文件、独立 SavedVariables、167 字节启动入口、显式启动、可取消、有时限。生成目录及 ZIP 位于 `analyze/performance-test-package`；离线验证在真实打包入口进行。源码与操作说明在 `tools/performance-test`。实际客户端安装/运行是下一步验证，未在此记录中冒充通过。
