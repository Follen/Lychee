# 详情交互与设置标题验收

## 交付行为

- 多技能组标题整行与右侧箭头共用展开、收回逻辑。子技能点击仍选择准确 ID；Shift 左键优先贴入准确链接，过期按下事件不能操作新绑定。
- 目录生成时排除萨拉塔斯的赠礼（1221063）的全部 44 个怪物引用。搜索索引、详情与旧引用恢复使用同一过滤结果；原始 enemies.json 不变，其余字段及技能与独立事实对照一致。
- 怪物详情底栏默认空字符串，阻止 Host 通用提示回退。快捷键提示仅保留在 Tooltip；链接失败临时提示，重试成功后清空。
- 设置标题从正文 12 改用 input 档位 16，与搜索栏及详情标题一致；继续使用整体 1.15 缩放。

## 版本化证据

wowdoc：sourceId `wow-ui-source`，product `retail`，requestedRef `12.1.0`，resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`。

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua:271`：`Name = "RegisterForClicks"`，点击类型为 ClickButton。沿用现有 Button 点击注册与脚本回调。
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:500`：`Name = "SetFont"`；参数 fontFile 为 FontAsset、fontHeight 为 uiFontHeight、flags 可空，返回 success。沿用 Theme 的自有字体设置。
- wowdata `db2 rows SpellName --ids 1221063 --source remote --region cn --product wow --build latest --locale zhCN` 返回 `ID: 1221063, Name_lang: 萨拉塔斯的赠礼`。本地读取曾返回 `db2_warm_failed / unsupported DB2 type: 0x45544C42`，改用远程查询成功；不以本地失败结果推断技能身份。

## 自动验证

- 完整 `python tests/run.py --report analyze/tests/detail-polish.json`：92/93 通过；唯一失败为最近使用生命周期单次峰值 6 ms，原门槛未修改。
- 单独复测 `ui.interaction_smoke`：通过，100 次循环总计 239 ms，峰值 4 ms，新增 Frame 0，持续内存增长约 0 KiB。证据 `analyze/tests/detail-polish-interaction-recheck.json`；保留首次失败记录。
- LDT 回归通过：标题整行开合、子项准确选择、Shift 优先、过期点击、空底栏、失败后恢复、屏蔽 ID 搜索和旧引用拒绝。
- 全量生成事实对照通过：16 个副本、462 个怪物、1538 个运行技能 ID，44 个屏蔽引用，其余事实不变。
- wowdoc validate：Host 44、Encounters 14 个 Lua 文件通过，无诊断。
- 完整入口包含 Lua/XML/TOC 静态语法、SDK 契约、目录生成漂移、文档与发布清单检查；git diff --check 通过。

## 实机范围

未在真实客户端验证字号、Tooltip、点击命中与战斗表现。运行文件加载顺序及 TOC 未改，提交并同步后使用 `/reload` 生效。同步依照五包清单覆盖复制并核对 SHA-256，保留目标旧文件；具体提交与文件哈希见本次本地 delivery JSON。
