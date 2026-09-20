# 0.3.18 大米计算交互修订

基线 c3b6074，用户反馈计算页面层级、入口与滚动问题。

- 旧代码回归可复现：navigation_binding 的 header back must return inside the view 失败；ldt_provider 的 repeated wheel must advance 失败。
- 修复：ViewHost 通用可选实例 Back 回调，LDT 只消费计算→怪物一层，保留技能/页码/视角；怪物→搜索由Host完成。同步SDK类型和中英文生命周期文档。
- 滚动内容与 scrollbar.value 同步；范围变化时钳制原生偏移；按钮、编辑框、空白与滚动条转发滚轮，无新增常驻驱动。
- 固定技能/层数/刷新工具栏；结果优先，校正折叠、缺少跳数明确提示，确认直接读输入框；自动填充不变成手动编辑。计算入口移至技能列底部。
- 复用固定控件，新增toolbar/editor/effects三个Frame，无新素材、timer、事件和SV；50轮离线开关零新增Frame，保留-1.03KiB；LDT模块约435.9KiB，相较上轮430.8KiB增量约5KiB用于布局与方法，接受有界成本。不代表游戏全局/原生内存。

完整契约、Lua解析、XML/TOC、diff检查通过；版本0.3.18。精确记录见 analyze/survival/redesign-contracts.txt 与 redesign-validation.json。实机验收另追加，不能以离线替代。

WoW证据：sourceId wow-ui-source / retail / requestedRef与Tag 12.1.0 / resolvedCommit 4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。source list/check已执行。

- Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:103–112，SetVerticalScroll(offset:uiUnit)，原生偏移设置。
- Interface/AddOns/Blizzard_AccountStore/Blizzard_AccountStoreCardTemplates.lua:105–107，OnMouseWheel向祖先转发。
- Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua:600–608，OnTextChanged(userInput) 仅对用户输入触发回调。

精确excerpt保存于 analyze/survival/scroll-evidence.json、wheel-evidence.json、text-evidence.json。视觉保留现有黑底、暖白、稀疏荔枝红，机械layout扫描无发现（Lua原生布局需实机检查）。

## 2026-09-21 实机结果

运行提交9387af7已同步到正式服Lychee，199文件SHA-256逐一一致，73个旧文件保留。仅更新现有模块，TOC加载顺序不变；reload后元数据0.3.18。

Ticket `LYCHEE-20260921-000005-0076`，task ldt-redesign-live / request ldt-redesign-20260920 / revision ui-1，status succeeded、complete true，10/10断言通过。环境：12.1.0.69875、Interface120100、zhCN、灵止光—死亡之翼。完整payload：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-000005-0076/content.json`，sha256 `1e8e43c87791560b68da8d75aa8094dbe0963fcf3e1d0639b5ca3b62961ae02b`。ACK confirmed/cleared，自有任务已remove；上轮0075未确认ACK也已补齐并清理。

真实资料17/134739/270292（净化构造体/净化烈焰）：客户端说明明确每秒伤害但未给总持续时间，页面正确要求补全持续跳数，自动填充manual=false。默认校正收起、固定工具栏可见；展开后viewport332/content532。空白、效果行和输入框滚轮按脚本触发，偏移0→32→64→96且原生GetVerticalScroll一致。确认最新字段后成功计算并收起、偏移归零。顶部返回第一次保留怪物页与270292技能，第二次返回搜索；退出后业务事件和resources清空。

WGC实机截图 `analyze/survival/ui-live-5.png`（默认）、`ui-live-9.png`（展开）核对：技能、层数、刷新不随正文滚走，外援默认可见，展开参数后滚动容器裁切正确，无控件相互遮挡。回归使用原生页面、脚本触发事件；真实硬件滚轮/拖动、英文、小视口、战斗、其他客户端仍待单独实机验收。离线50轮复用与全契约通过，不冒充这些未覆盖的游戏场景。
