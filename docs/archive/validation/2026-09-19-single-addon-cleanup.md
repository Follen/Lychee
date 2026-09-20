# 2026-09-19 单包迁移后的代码与 SDK 清理

本轮基于 ec3fabd，保留 SDK / Provider API 1.0.0 与现有业务行为。游戏实测尚未完成，不能据此声称搜索速度或实机内存改善。

## 清理范围

- 删除无运行调用的私有索引快照、签名构建、空持久化函数及 UI / 查询转发方法；保留实际使用的 Rebuild 和公开 SDK。
- 暴雪设置统一走 Adapter、Language 与 Invocation，删除旧面板扫描回退和重复打开设置实现。测试改为加载真实 TOC 依赖并执行实际 Invocation 路径。
- 删除未使用字段表与被立即覆盖的转发声明；修正 SDK 的单包交付说明、失效测试链接和稳定引用说明。
- CancelAll 并非死能力：补上战斗与退出角色的调用，阻止角色切换后的迟到回调和排队编辑继续执行。新增生命周期回归覆盖取消、重入、资源释放及迟到响应。

## 验证

完整 tests/check_contract.ps1 通过，原始日志保留在本地 analyze/feature-port/cleanup-contract-2.txt。覆盖 SDK、搜索、设置、生命周期、交互与离线性能检查。启动事件检查现在精确限定登录、退出、进入战斗、退出战斗四种事件各一次，CPU 与运行时增长要求未放宽。

设置扩展测试现在包含真实设置模块依赖，因此其静态数字不能直接与旧回退路径的测试数字作内存回归比较；实机总量仍需相同环境测量。

隔离 wowdoc 诊断副本检查完整 111 个 Lua 文件，原始结果仍为 valid=false；已有工具局限及 15 类事件证据见 [wowdoc 复核](2026-09-19-wowdoc-review.md)。新增 PLAYER_LOGOUT 的官方证据：sourceId wow-ui-source，product retail，requestedRef 12.1.0，resolvedCommit 4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59，Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua:137，LiteralName = "PLAYER_LOGOUT"。未解析调用不计为已验证。

原始静态报告：analyze/feature-port/wowdoc-cleanup.json；SHA-256：57e26862ff6a1b52292120ba7c0c9df52a9c1ba21f8a852aa4eb35f45d28a888。

## 待实机验证

中文和英文功能覆盖、真实搜索耗时与内存、首页恢复、6 至 1 条结果切换及大米详情界面。离线检查不能替代这些结果。测试脚本须绑定本轮交付提交，确认目标游戏窗口后执行。
