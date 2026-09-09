# Provider API 2 验证记录

日期：2026-09-10。实现版本：Lychee 0.2.0 / Provider API 2 revision 1。基线提交：884ad34。

## 交付范围

统一 RegisterProvider，内置玩家技能与第三方示例均使用公共接口。支持静态目录、原子增删改、单次同步/延迟查询与取消、当前条目恢复、命名普通动作、Host 技能安全动作、独立拖动、托管视图、多动作菜单和限定身份的最近使用。

不提供旧 SDK 适配；SavedVariables schema 2 不迁移旧数据。索引及动作载荷不持久化。README、架构、SDK 教程、协议参考、LuaLS 类型、helper 和两个示例均同步到 API 2。

## 自动化验证

- `pwsh -NoProfile -File tests/check_contract.ps1`：10 项测试全部通过。包含 Provider 公共契约、Registry 边界、内置与第三方集成、默认按键、交互与视图、结果 UI、搜索平台、会话、内部命令目录和能力查询器。
- `luac -p`：运行时、SDK、测试共 45 个 Lua 文件解析通过。
- Bindings.xml XML 解析与 TOC 文件存在性、加载顺序检查通过。
- `git diff --check` 按仓库换行配置通过；CRLF 转换提示不属于差异错误。
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`：checkedLua=30、valid=true、无 diagnostics。原始结果见 `../architecture/2026-09-10-framework-validate.json`。

重点回归：跨 Provider 相同局部 ID、退休句柄/晚回复不能覆盖新实例、输入复制、非法批次原子性、真实增量与无变化不增加版本、批量删除映射、更新重入拒绝、查询超时/取消/重复完成、动态恢复使用当前数据、scope、只读条目、完整 20 条预算、菜单过期校验、首次视图状态与直接 Update、菜单焦点、安全覆盖层右键、次要安全动作准备不计为执行成功、按钮回收。

## WoW API 来源

sourceId=wow-ui-source，product=retail，requestedRef=latest，resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。

精确 path/line/excerpt 保存在 `../architecture/2026-09-10-framework-wowdoc.json`。涵盖 C_Timer.NewTimer、UnregisterAllEvents、C_Spell.PickupSpell、MenuUtil.CreateContextMenu、菜单按钮、Frame 父级与层级、所属 region 隐藏时原生菜单自动关闭等证据。

## 离线性能对照

可复现脚本为 `tests/index_benchmark.lua`，原始数字见 `../architecture/2026-09-10-index-benchmark.json`。Windows Lua 5.1，1000 条目录；这只测核心索引，不含 SDK 边界校验和真实 WoW 引擎成本。

| 指标 | 884ad34 | 新实现整批快照 | 新实现单条 delta |
|---|---:|---:|---:|
| 更新样本数 | 10 | 10 | 100 |
| 平均更新 ms | 64.1 | 2.4 | 0.04 |
| 平均搜索 ms | 2.02 | 2.01 | 2.01 |
| 保留的未变更索引对象 | 0/10 | 10/10 | 100/100 |
| 冷建 ms | 54 | 58 | 49 |

冷建值存在运行波动，不据此声称启动加速。运行时无新增 OnUpdate；query deadline 只在等待时存在，来源刷新使用一次可取消的合并 timer。静态增量仅验证、复制、编译变化项；无变化更新不触发版本或界面刷新。

## 实机证据边界与同步

本轮没有取得真实客户端登录、空闲、单目标战斗、团本/姓名板峰值和窗口打开/关闭的 CPU、内存、帧时间对照，也没有宣称真实硬件施法、taint 或战斗锁定验证通过。离线 Frame 和 timer 适配器不代替这些验证。

运行时代码提交为 `51c8320`（Build unified Provider API 2 search framework）。提交成功后，已将 package/Lychee 的 35 个运行时文件复制到 D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee；35 个 SHA-256 全部匹配，文件清单差异为 0。本次新增 TOC 模块，需要重启客户端加载并验证；文件同步成功不代表实机验收完成。
