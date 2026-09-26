# 搜索延迟优化

## 问题与范围

用户反馈首次搜索、连续输入和后续补全都慢。运行基线为0.4.1，仓库基线b534daf。本轮已复现完整团本技能查询的跨帧延迟；其他来源的真实首批延迟尚未取得有效报告，不能称为全面解决。

输入去抖仍为40ms，默认来源、完整目录、排序、动作、SDK 1.0.0和持久数据不变。候选计算仍在查询作用域，取消/关闭释放资源，无新增空闲任务或全量缓存。

## 复现与改动

命令：`lua tests/providers/raid_abilities.lua zhCN --frame-paced`。使用真实Provider、SDK、完整生成目录；仅外部API和timer为离线替身，timer至少跨1/30秒。修复前约2533ms，断言“完整缓存查询不足1秒”失败。此处模拟的是调度等待，不是实机帧率测量。

三项假设：分批过碎增加等待；慢来源阻塞首批；重复列表刷新。现有证据确认第一项，另外两项仍需真实首批/各来源数据。

改动：

- 未命中和不能进入Top 20的技能跳过难度关系解析；命中后保留原始难度并集、section及优先级。
- 首领/副本等公共字段每首领评分一次，再按原规则合并技能字段及跨字段多词评分；数字ID不重复清洗。全部临时状态属于当前查询，没有跨查询名称缓存。
- 廉价扫描数量上限128→512，单批1ms预算及8ms离线回调门禁不变，避免未用满时间预算就空等下一帧。
- 通用FindLiteral在没有任何字面命中时直接返回，避免重复检查英文短词边界；有命中时仍按原规则检查。
- Normalize保留原空白与标点归一化，在归一化空白后通过首尾空格字节去边界，避免两次冗余正则；全部256字节及1000组混合文本独立参照通过。

## 验证

中英文模拟30FPS完整查询最终分别约833ms、867ms；同固定20次混合查询，原实现CPU约1652ms、累计分配2998KiB；优化后分别528/485ms、2635/2629KiB。回收后保留增长均约0.8KiB，单回调峰值约2ms（低于原8ms门禁）。CPU样本为本机Lua5.1替身，不是游戏CPU收益承诺。中间版本在完整契约中达到1000ms而失败，进一步优化后重跑；没有提高1秒目标或8ms回调门槛。

26组完整目录差分对照通过：包含宽泛、多词、中文、数字ID、短英文词和难度前缀，结果集合/顺序/文字/置信度/匹配证据/payload/interaction一致。原始对照位于本机analyze/search-latency-before.txt及after.txt。已有小目录用例覆盖同名不同技能、跨难度去重、名字中的Heroic、异步/同步/失败名称加载、取消/禁用/恢复、战斗拒绝和section跳转。完整契约及静态检查结果完成后补记。

## 实机与未覆盖项

按lycheedev执行，未使用Computer Use。旧窗口身份变化后，用户确认已登录，新连接为SESSION-5b8b78d290d563075046ef3773ac4389e471ea0368f250b9913919734f561cff，正式服12.1.0.69933、灵止光/死亡之翼。

基线探针PRB-9112aff59cac7218e0f8fd7a64f421e86df6572ffa78423d487964588cfa51aa，操作OP-c06b8b0b4f6b8bc546fa244398393c5a。load已返回操作，run及同一操作resume均返回command.cancelled/context deadline exceeded；report unavailable、cleanup pending。没有重复创建操作、强行释放锁或ACK未读报告。恢复必须继续此operation，不得将该探针标为通过。

待实测：首批可交互结果、冷/热全来源、快速输入/输入法、慢快来源并发、关闭重开/取消/重试、实际CPU/内存和其他客户端。探针预算为首批150ms、完整1s，仅为采样目标，尚无游戏测量值。

## 源码证据

sourceId=wow-ui-source，product=retail，requestedRef/resolvedCommit=78282522143e25c3540583734fd192c3d69be910；PIN-1b23405fd36b2183970d75442737537f2bdc79c292ea9cce4b2d6efaae7702ee，source list确认已索引。

- Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:508，debugprofilestop返回自debugprofilestart起的毫秒数；CAP-a4057e563ca4a3b36fd0e1ba0ebe1f47ada942199cd3223a4de241f6b95b4bf0。
- Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua:38，NewTimer(seconds,callback)返回TickerCallback；CAP-58661f79a19a1c2412b312622963d172fb05e307eacccf013b578c00f1060334。查询因limit标为truncated，以上精确函数定义完整返回，未据此声称全部关系覆盖。

运行改动沿用已有C_Spell.GetSpellName和计时接口，不改变游戏API参数、事件或保护边界。静态验证及交付结果完成后补记。

## 最终检查

- 完整tests/check_contract.ps1通过，含新增模拟30FPS断言、双语言团本语义、既有历史和SDK回归；原始输出analyze/search-latency-contract.log。首次启动CPU门禁失败、单项复测34ms通过，第二次中间实现跨帧1000ms失败；两份失败日志单独保留，后续优化后完整通过，门槛未放宽。
- 全部运行/SDK/测试Lua解析、Bindings XML、TOC生成、SDK生成、发布清单内存验包、文档链接/版本与git diff --check通过。
- 五端staticValid/loadValid=true、load issues=0；complete=false，Interface基线unresolved，动态参数、战斗、taint和运行行为未被静态工具覆盖。
- 最终静态capture：Retail CAP-dd0d6ac836345f9cc2b9dd710efa9b8e08eca20177712af0c7ddd9e746f6a703；Classic CAP-cbf8371486a4dcc8fee5a4115f892f50845460a331466e04aaf0e5d164c2f8a6；Titan CAP-60fef310a658591df77d8b34ee0523e599286b956dc539de6049c7572f096263；Anniversary CAP-337ab79a66c75c9e670ac3b618c0680a1e1bcca68ddd0d3b5edc7362b502244e；Forever CAP-7be04fe1878719532ebe8ad8318708a717e16dce2eb6d783358e8bdc2a96044c。

版本0.4.2，运行提交b66f6e88407f0b2bd2599b421fcfb0cc7b73b1cb；正式服D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee已覆盖同步203个运行文件，逐文件SHA-256一致，证据analyze/search-latency-delivery.json。目标旧文件保留。原实机操作仍需恢复与清理，未绕过窗口所有权另发reload，未发布平台或npm。不能声称新版本已在当前进程加载。
