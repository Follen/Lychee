# 2026-09-20 音量文案与历史恢复

## 问题与证据

基线 main `fe23c35`。用户的“设置音量为30”显示“主音量 / 音量暂不可用”；最近使用混杂无图标的“设置音量”和两条无法区分的“主音量”。

lychee-dev 只读 Ticket `LYCHEE-20260920-013611-0016`，来源 `automation_result`，retail 12.1.0.69875 / Interface 120100 / zhCN，完整成功，无截断。完整 payload 位于 `%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260920-013611-0016/content.json`，4555 字节，SHA-256 `068c1ab97829ba0736ee4c3cd1eab781a70e3535bd0b87686da5c7190b8428c6`。ACK 已确认并清码。

实机 CVar 主音量为 `0.3`，AudioAdapter 返回 30，命令解析也得到 master/30。历史依次包含音乐 set-volume/0、普通主音量入口和主音量 set-volume/30；引用本身有准确参数，展示丢失，不能按相同标题删除记录。

1. TOC 先加载 BlizzardSettings Provider，编译并缓存词典；Audio/Locales 随后原地追加格式词条，缓存未失效，Format 返回 nil，标题和副标题触发误导性回退。旧 UI 测试手工提前加载 Audio/Locales，未覆盖真实顺序。`lua analyze/audio_locale_repro.lua` 在修复前断言失败。
2. 滑块 BeginEdit 只保存动作标题，具体 Invocation 恢复合成通用记录，不读当前业务展示，丢失通道、百分比、图标和类别。`lua tests/providers/audio_history.lua` 在修复前失败：`slider history lost channel/value: 设置音量`。

## 修复与边界

- Audio 发布新的语言表，让真实 TOC 顺序下后续消费者重新编译；不更改 TOC 或启动顺序。
- 使用已有 reader 的 `context.ref` 传递隔离的完整 Invocation。reader 只读恢复展示，Host 仅在动作、目标和规范化参数完全相等时采用其标题、说明、图标和类别；执行仍使用已验证保存引用。失败和不匹配保留既有回退，不从同名条目推断动作。
- Audio 根据保存的通道与百分比恢复展示，包括旧 `entryID=set-volume` 和参数不同但 entryID 相同的记录。原存档不迁移、不清空、不改写。
- 字典更新只在加载期发生；恢复最多对当前可见引用各增加一次已有 reader 调用，首页近期上限 8，固定项仍受 64 条容量限制。无新增事件、计时器、Frame、持久缓存或后台工作；普通搜索路径不增加恢复调用。

## 离线验证

- 新回归覆盖真实 TOC、准确标题/副标题、旧滑块存档、真实 BeginEdit 产生的历史、30/50 参数隔离、reader 引用隔离和错误返回回退、原存档不改写，zhCN/enUS/zhTW/enGB 全通过。
- 现有音量执行后行刷新回归通过；完整 `tests/check_contract.ps1` 通过，包括 SDK、生命周期、存储、TOC/发布清单、性能和其余业务回归。
- 207 个 addon/tests Lua 文件通过 Lua 5.1 语法检查，Bindings XML 解析通过；wowdoc 递归校验 111 Lua，valid=true、diagnostics=[]；git diff --check 通过。TOC 由完整契约验证。
- wowdoc source list/check 后使用精确 ref 12.1.0：sourceId `wow-ui-source` / product `retail` / resolvedCommit `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua:20`：GetCVar 接收 cstring name，返回可空 string value。本次不改音量原生读写接口。

## 交付与实机

提交后同步单包清单并逐文件核验；修复后的实机界面与报告待收尾补记。离线性能门禁通过不代表实机 CPU/内存专项测量；本次未改变目录规模或常驻驱动。
