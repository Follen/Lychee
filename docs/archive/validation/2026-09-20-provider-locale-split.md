# 内置 Provider 单语言词典

基线提交 `90aef9f`，插件 0.2.3 → 0.2.4；SDK / Provider API 保持 1.0.0。

## 所有权与成本计划

16 个内置 Provider 共 273 个词条。旧实现无条件创建 enUS/zhCN 原始表，Module 再生成当前语言字典，注册时 SDK 又生成一份。新实现每个 Provider 有独立的 Locales/enUS.lua 与 Locales/zhCN.lua，首部先按会话语言返回；只创建一张选中词典，内部翻译器复用它并保留有界格式计划。已翻译的内置注册描述不再重复提交 i18n。第三方 Compile 的校验、隔离与逐键回退完全保留。

触发仅为 TOC 加载及首次 Module 获取；重复获取复用缓存，词典表替换使缓存失效。语言在客户端会话内固定；zhTW 回退 zhCN，enGB/其他语言回退 enUS。每模块仍最多 256 键、键 96 字节、文字 1024 字节、键值 128 KiB；不新增事件、timer、Frame、SV 或空闲/战斗工作。内置两种语言在离线检查中必须完整，不能借此删除英文搜索别名。

TOC 仍读取两份 Lua 源文件，未选中语言只是不执行表构造；不得把本次优化描述成完全不解析英文文件。新增文件需要完整客户端重启。旧游戏目录的 Locales.lua 默认保留，但新 TOC 不引用，不执行；发布清单不包含旧文件。

## 离线验收

- 旧版词典独立导出后逐键对照：16 模块 × zhCN/enUS/zhTW/enGB/frFR，1365 项文字检查全部通过；缺键、格式参数、SDK 外部修改隔离、模块命名空间及替换表回收检查通过。
- 完整 tests/check_contract.ps1 通过，包括四客户端 × 两语言真实 TOC 装配、Provider 搜索/动作、UI、取消/恢复及原有性能约束。额外 20000 次缓存获取没有重编译，GC 后保留增长 0.0 KiB。
- 全部 Lua 语法、Bindings XML、文档与生成 TOC 检查通过。发布清单：游戏 182 文件，独立 SDK 60 文件。
- wowdoc 对全部 44 个改动 Lua 文件的局部校验 checkedLua=44、diagnostics=[]、valid=true；本轮未重跑完整客户端 TOC 闭包的 wowdoc 扫描。

固定 Lua 5.1、Mainline TOC，旧/新交替各 5 轮，包含源文件解析与执行、排除登录和真实引擎 UI。原始数据在本地 analyze/locale-loading-measurements.json。

| 语言 | 版本 | 加载 CPU 中位数/最大 ms | 累计分配 KiB | GC 后常驻 KiB |
| --- | --- | --- | --- | --- |
| zhCN | 旧 | 28 / 31 | 5185.5 | 2258.9 |
| zhCN | 新 | 30 / 30 | 5102.7 | 2217.4 |
| enUS | 旧 | 28 / 29 | 5203.4 | 2276.6 |
| enUS | 新 | 30 / 31 | 5120.5 | 2242.7 |

中文常驻减少 41.5 KiB，英文减少 33.9 KiB；累计分配分别减少 82.8/82.9 KiB。加载文件 104 → 120，中位 CPU 增加约 2 ms，仍满足既有 <61 ms 门槛；2 Frame/4 Host 事件保持不变。接受这项以少量一次性加载开销换取更少常驻重复表的取舍，不声明启动提速或帧率提升。

## 实机基线与待验收

使用 lychee-dev 后台消息通路。基线 Ticket `LYCHEE-20260920-105417-0033`，requestId `locale-before-20260920-01`，revision `locale-1`；Retail 12.1.0.69875 / Interface 120100 / zhCN，晴昼秋岚—白银之手，运行插件 0.2.3。291 项通过、0 失败，16 Provider 注册。实际保留 32 张原始语言表、16 份 SDK localizer；16 个模块的选中词典均为另外编译的表。273 词条排序后 Adler-32 为 `7c60acbb`。

5 轮各 10000 次 Module + Text 读取耗时分别为 4.5815、4.5822、4.5770、4.5673、4.5672 ms。刷新后的 Lychee 归因内存 16322.634 KiB，是自然 GC 状态下的整体观测，不是回收后常驻；全局刷新耗时 49.579 ms 单列，不计作词典耗时。未更改 GC 或 profiling 配置。

完整 payload 保存于 `%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260920-105417-0033/content.json`，同目录包含 report.json/evidence.json；19660 字节，Adler-32 `3f381a75`，SHA-256 `661e17b4ad008b4b5e14b75a079680036452508f938d51131029ff94dce5e59b`。ACK received 已确认并清除。

新版本待完整重启后按同一探针复测，比较文字校验和、Provider 注册/标题、格式化/缺键失败、缓存取词 CPU、实际词典及 SDK localizer 数量。随后覆盖搜索面板开关和来源文字。新版本实机功能与性能尚未记作通过；其他语言/客户端、战斗、团本和姓名板峰值未做本轮实机验收。改动不涉及对应事件驱动，但不能用离线覆盖替代这些场景。

## WoW 依据

sourceId=wow-ui-source，product=retail，requestedRef/matchedTag=12.1.0，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。

- Interface/AddOns/Blizzard_APIDocumentationGenerated/LocaleDocumentation.lua:49–55：GetLocale 返回非空 localeName。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua:25–38、94–96：GetAddOnMemoryUsage 接受 AddOn 名称并返回 number；UpdateAddOnMemoryUsage 刷新统计。
- Interface/AddOns/Blizzard_AddOnList/AddonList.lua:761–770：官方标明全局内存刷新昂贵，避免 OnUpdate 调用。本探针仅在开始时调用一次。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:509–517：debugprofilestop 返回自上次 debugprofilestart 后的毫秒数；探针只相减，不重置共享计时器。

回滚使用新 git revert，重新同步并完整重启，不改写已发布历史。
