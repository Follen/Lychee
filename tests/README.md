# 测试

测试针对 SDK 1.0.0 / Provider API 3 revision 1、UI Runtime 1 和五个运行时包。预算唯一源为 [PERFORMANCE.md](../PERFORMANCE.md)，不以测试数量或离线替身推断游戏内覆盖率。

## 一个入口

需要 Python 3.10+、Lua / luac 5.1、PowerShell 7 与 ripgrep。入口自动切换到仓库根目录，每条命令在独立进程运行，顺序执行，避免性能测试相互争抢 CPU。

```powershell
python tests/run.py
python tests/run.py --list
python tests/run.py --suite sdk --suite integration
python tests/run.py --case ui.navigation_binding
python tests/run.py --report analyze/tests/latest.json
python tests/run.py --suite benchmarks
```

原来的 `pwsh -NoProfile -File tests/check_contract.ps1` 保留为同一入口的薄包装，也可传上述参数。

- 默认跑全部硬门禁，包含业务测试中的性能断言、静态语法、文档、生成数据与交付检查；`benchmarks` 是没有性能阈值的观测工具，显式选择才执行。
- [suites.json](suites.json) 是唯一命令清单。每项写清 ID、分组、文件和参数。相同文件的双语言、加载基线、默认启用等不同参数是不同场景，禁止重复登记相同命令。
- 检查发现未登记的测试、重复 ID、非法路径、缺失文件、拼错选择或空选择时，执行前失败。测试不能通过 `dofile` 执行另一份测试；仅可引用 support 和事实 fixtures。
- 失败继续收集其他用例结果，最终非零退出；不自动重试、不把超时当通过。默认每条命令最多 120 秒，可用 `--timeout` 调整离线执行器等待，**不改变任何业务性能断言或 SDK 查询期限**。
- `--report` 保存命令、退出码、耗时与完整输出，并注明全量还是选定范围。该耗时包含进程启动，不等于 Lua 业务 CPU；业务指标看测试输出。

## 按职责找测试

| 目录 / 分组 | 负责证明什么 |
| --- | --- |
| `sdk/` | 原始公开输入、API 3 拒绝旧协议、Catalog/Storage、托管资源、通知、语言、所有权与原子失败 |
| `search/` | 质量和排名、独立参考算法、会话/异步取消、快照、个性化、缓存有界 |
| `providers/` | Player/Encounters/Integrations/Inspector 的具体查询、动作、视图、数据和生命周期 |
| `ui/` | 真实控制器配原生替身：点击身份、导航回滚、设置、固定项、动效、模型及控件复用；模型细节另见 LDT 用例 |
| `integration/` | 真实 TOC、四产品、角色数据恢复、单包/缺包/反序加载、默认启用和明确关闭 |
| `performance/` | 五包合计加载、完整查询负载、启动、事件和增量更新、列表池；原阈值保持 |
| `delivery/` | SDK/运行包清单、生成事实全量对照、客户端清单、文档和构建漂移 |
| `contracts/` | 入口自身的反向测试、Lua/XML/Python 静态语法与依赖边界 |
| `benchmarks/` | 索引观测，不冒充完整业务性能门禁 |
| `support/`、`fixtures/` | 装配/原生替身与独立事实输入，不作为测试命令执行 |

详细风险与回归入口见 [生命周期验收](LIFECYCLE_ACCEPTANCE.md)。要查看每组完整命令，用 `--suite <名称> --list`，不再维护第二份手写执行列表。

## 夹具与断言的边界

- `support/runtime.lua` 依据实际 TOC 排序，只加载测试显式选择的模块；子包用当前 `../Lychee_Player/...` 等真实路径。旧 Shared/Core/Modules 路径报错，禁止静默吞掉。`integration/assembly.lua` 独立断言先后关系、无部分加载和错误拒绝。
- `support/package_loader.lua` 用真实五包 TOC 和 WoW AddOn 参数装配。`package_namespaces` 验证完整包组合，`package_combinations` 在独立进程覆盖 Host 单独、四个子包单独、反向加载及登录后就绪。
- `support/sdk.lua`、`support/palette.lua`、`support/package_providers.lua` 只准备各自外部环境和实际模块，不执行其他业务测试。每份用例自行设置就绪状态、创建面板或准备数据。
- `support/provider_fixture.lua` 是使用私有项目适配器的测试 AddOn，会补齐自己的 scope/i18n。它用于业务装配，**不得用它证明缺失字段会被公开 SDK 拒绝**。公开输入校验必须直接调用 `Lychee:RegisterProvider`、`Lychee.SDK.CreateCatalog` 等实际接口。
- 替身不得实现被测试的评分/生命周期算法，不偷填成功状态。独立结果对照先断言样本非空，再比较结果、顺序、显示与动作参数；不得用两个空列表证明等价。
- 性能夹具固定样本、预热、GC 与测量范围。综合内存场景复用相同数据装配，不再靠执行整份点击测试获得目录；这次测量范围清理不能当作运行时内存优化收益。

## 新增、修改、删除

新增测试放入职责目录并登记清单；优先覆盖错误输入、失败恢复、注销/取消、重入、身份变更和容量边界。已有契约变动时修改所属回归，不另外复制一套替身和相同断言。纯样式常量不写复述实现的测试。

删除前确认有效断言已有去处。此次只退役读取旧 Host 全量索引的 `profile_search_memory.lua`；原性能场景和阈值保留。原先嵌套执行的交互、Logo、SDK 冒烟都成为独立命令，准备步骤移入 support。[旧路径映射](path-migration.json) 用于查找历史报告的测试；历史验证记录保留当时提交的命令，不篡改过去的证据。

完整离线通过仍不证明真实客户端战斗、taint、安全点击、像素渲染或纹理内存通过。游戏检查与证据要求见生命周期验收；测试、SDK、文档与分析工具不进入游戏运行包。
