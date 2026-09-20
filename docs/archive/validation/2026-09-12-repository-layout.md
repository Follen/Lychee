# 目录与文档整理验收

日期：2026-09-12。基础提交：55834e1。运行时业务与游戏插件名 Lychee 不变。

## 变更范围

- package/Lychee迁至addon/Lychee；旧ZIP保存在忽略的dist/legacy，不删除用户产物。
- SDK教程、协议、专题集中在lychee-sdk/docs；SDK首页按任务导航，旧版本兼容单独成页。旧docs入口保留短链接。
- DESIGN.md按视觉、控件、动效、内容与角色、识别分组，修正过时图标、分隔尺寸、管理接口描述。
- PERFORMANCE.md保留已有硬门禁，集中补齐预算、专项容量与历史坑；纠正已回滚数组方案和旧成就共享缓存描述。SDK规范副本自动生成，不改变任何测试阈值。
- AGENTS.md按地图、触发条件、验证与交付整理；保留本地文件策略与Comet管理块，将条件并行细则移入维护指南。
- 增加文档/版本/SDK本地链接闭合、显式发布清单、可重复ZIP字节与负例检查。

## 官方建议依据

读取了[GPT-6 Astra官方指导](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)和[AGENTS.md官方说明](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。采用明确授权范围、识别冲突指令、按风险测试及简洁项目入口的原则。用户提到的OpenAI Developers X原帖未定位到，不声称已确认原帖内容。

## 证据与边界

所有性能数字沿用现有测试，未新增游戏内采样。历史报告原文、旧路径与旧提交读数保持；当前文档链接检查不重写历史源证据。

最终结果见下节；本轮验证布局与交付完整性，历史实机待测项仍未验证。

## 最终检查结果

- 完整 `tests/check_contract.ps1` 通过；原始输出见 [contract.txt](2026-09-12-repository-layout/contract.txt)。最后追加的发布边界用例另执行 `python tests/repository_delivery.py`，共10项通过；SDK交付15项通过。
- `tools/check_repository.py`：38份现行文档的路径、锚点、SDK本地链接闭合、版本徽章与协议当前版本通过。历史设计/验收原文和Comet管理记录不作为可执行现行文档扫描。
- `tools/build_sdk.py --check`与`tools/build_release.py --check`通过：插件137文件，6文件。SDK附带的性能规范由根文件生成，所有本地文档链接在SDK内闭合。
- 153份Lua经luac -p通过，Bindings.xml解析通过；[wowdoc记录](2026-09-12-repository-layout/wowdoc.json)有效、无诊断。
- 迁移前后137个运行文件数量与SHA-256全部相同，见[字节基线](2026-09-12-repository-layout/runtime-sha256.json)。游戏名、资源路径、TOC内容和加载顺序未改；只改仓库外层目录。
- git diff --check通过。旧未跟踪ZIP移至dist/legacy/Lychee-before-layout.zip保留；AGENTS.md保持本地忽略策略，Comet ambient块未改。
- 无游戏业务或加载字节变更，本轮不重复同步正式服，不要求重启；没有新增游戏内CPU/内存/视觉测量，不宣称实机性能改善。
