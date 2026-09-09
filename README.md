# Lychee

Lychee 是 World of Warcraft 游戏内的通用搜索工具。Provider 提供可搜索条目及其交互，Host 负责搜索、排序、统一展示、最近使用与执行约束。内置功能和第三方插件使用同一套公共 SDK；业务种类不由框架枚举。

`package/Lychee` 是唯一运行时 AddOn。`lychee-sdk` 是开发包，不作为独立插件安装。默认快捷键为 Alt+Space，也可在游戏按键设置中修改。

## 开发文档

- [架构](docs/ARCHITECTURE.md)：模块职责、生命周期、扩展边界。
- [SDK 接入](docs/SDK.md)：API 2 快速开始和可运行示例。
- [协议参考](docs/PROTOCOLS.md)：字段、限制、错误和行为约定。
- [SDK 开发包](lychee-sdk/README.md)：LuaLS 类型、辅助函数和第三方示例。
- [框架决策](docs/architecture/2026-09-10-provider-framework.md)：方案比较、取舍和验收范围。
- `docs/comet/` 保留先前工作流的规格与历史；当前 Provider API 2 以以上架构与协议文档为准。

## 当前实现

已实现静态目录和增量更新、同步或延迟查询、当前条目恢复、普通回调动作、技能安全动作、独立拖动、托管视图和动作菜单。内置玩家技能通过公共 Provider API 注册。API 2 不提供旧 SDK 适配；SavedVariables 使用全新的 schema 2，不迁移旧历史或索引。

在仓库根目录执行 `pwsh -File tests/check_contract.ps1` 运行契约检查。真实 WoW 的视觉、硬件点击、战斗/taint 和 CPU/帧时间仍须在客户端验证，离线测试不能替代这些证据。
