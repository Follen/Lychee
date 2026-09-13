# 搜索首项被后到结果挤下

基线 `f5c3072e894587097e5e40d3d0bfe4ff08a6973e`。用户录像 `20260913-181735.mp4` 中，同一次“毒牙”搜索在2.4–2.8秒和5.8–6.2秒先显示收藏/成就，随后换成地城资料与团本技能，原首项及高亮向下移动。分帧证据位于 `analyze/candidate-shift/contact.png` 和 `detail.png`。

## 复现与原因

`lua analyze/candidate-shift/repro.lua` 使用真实 Provider → Query → SearchSession → Palette → ResultList，只替换原生框体与timer。两个来源分别先返回“毒牙撕咬”、后返回更精确的“毒牙”，未触发鼠标事件、关闭动效，仍连续两次稳定失败：`display: first` → `display: exact,first`，断言 `first visible candidate was pushed down by a later provider`。这是本次录像的候选换位，不是IME预编辑或窗口几何问题。

原实现将未收齐的搜索排名直接展示；后到候选参与正常排名时重排列表，ResultList沿用原选中身份，高亮也跟着下移。现行设计原本要求首批非空结果立即展开，测试因此允许这种行为。修复位于SearchSession接收入口：未完成的结果只发布等待状态，不送入列表；输入/过滤开始时仍立即清空旧结果和动作。完成、失败或已有deadline结束后，一次交付最终排序结果。Query、Provider、匹配规则、同词记忆、Top20和候选集合均不改动。

来源刷新时保留旧列表外观，旧动作由既有查询代次检查失效，最终结果再替换；换词、关闭、输入法暂停、战斗及迟到回复继续使用原有取消路径。没有增加固定延时：首屏改为等待本次查询完成，最坏仍受原Provider五秒deadline约束。这是消除中途换位的体验取舍，不宣称首次结果更快。

## 验证与成本

先修改 `tests/ui/search_publication.lua` 的期待，在旧实现失败于 `unfinished ranking must not become a visible first candidate`，再修改运行代码后通过。原最小复现变为只输出一次 `display: exact,first`。正式回归另覆盖两种异步返回顺序、超时、超时后迟到回复、重新打开、来源刷新中的空批次、最终第一项选择；保留过滤、取消、最终空结果和别名解析重入回归。

`python tests/run.py --report analyze/candidate-shift/full.json`：103/103通过，含完整原性能门禁、UI交互、IME、静态语法和发布清单；未提高阈值。不含LDT加载1493.5596KiB/24ms，完整加载1855.6045KiB/28ms；基线分别1493.5361KiB/22ms、1855.5811KiB/28ms，编译后常驻增加约0.0234KiB。没有新增Frame、timer、事件、缓存、表或持久字段，每次已有回调只多一次等待分支。最近使用100轮268ms、峰值4ms、累计分配24137.5KiB、0新增Frame；与基线相同场景245ms、峰值4ms、相同分配比较，未观察到保留增长，不将计时波动称为优化。低层高度算法的边界测试保持，用于保证旧内容布局安全；实际搜索发布行为由真实来源链路测试约束。

登录、空闲、团本、姓名板和游戏内不同缩放未实测，本次不改变这些场景的活动驱动。用户录像用于确认旧症状，不能作为修复后的实机通过证据。

## 原生证据和交付

修改前 `wowdoc source check` 确认sourceId=`wow-ui-source`、product=`retail`，本地与远端commit一致；inspect的requestedRef/matchedTag=`12.1.0`，resolvedCommit=`4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua` 第39行摘录 `Name = "NewTimer"`，参数为seconds和callback，返回cbObject。核对现有Provider五秒截止机制，无新增原生调用。修改后 `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0` 检查45个Lua文件，valid=true、无诊断，原始结果在 `analyze/candidate-shift/wowdoc.json`。

通过文档与差异检查后提交，只同步五个插件包的188个运行文件并核对SHA-256，保留目标旧文件。同步清单记录于 `analyze/candidate-shift/sync.json`。没有新增模块或TOC，更新后 `/reload`，客户端仍需复查同词搜索首项的稳定性与实际等待时间。
