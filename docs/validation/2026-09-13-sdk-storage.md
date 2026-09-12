# 子插件存储阶段验证

日期：2026-09-13。分支 `codex/provider-sdk-1.0.0`，未提交工作区；基线 `050111d`。这是 SDK 独立模块验证，不是整个拆包验收或实机内存报告。

## 实现与边界

`lychee-sdk/Storage.lua` 不读取 Host 全局或数据库，通过子插件的 ready/root 访问器取得当前存档命名空间。没有 Frame、事件、timer、OnUpdate 或 GC 调用。缺省读取不落盘；普通设置有既有数量/字节边界，Get/Set 隔离可变值。Import 仅向缺失目标原子导入；Migrate 按显式版本步骤成功后一次提交。

存储句柄由包数据层负责关闭，与 Provider/query/view 的托管活动资源分开。SDK 不删除外部迁移源，不自动发现数据库，不处理大型成就目录 schema，不声称能限制绕过接口的任意第三方代码。

## 已执行

| 命令 | 实际结果 |
| --- | --- |
| `lua tests/sdk_storage.lua` | 通过：未就绪、角色根替换、同包隔离、可变值隔离、额度、原子导入、已有目标拒绝覆盖、迁移失败保留、并发写入/根替换拒绝提交、访问器重入与关闭、新版本拒写、多份 SDK 独立 |
| `lua tests/sdk_resources.lua` | 通过；1000 次固定托管生命周期增长 6.012 KiB，新增 Frame 0，禁用后资源 0；这是托管资源旧门禁，不能当作 Storage 堆大小 |
| `luac -p lychee-sdk/Storage.lua` | 通过 |
| `python tools/build_sdk.py --write` 后 `--check` | 生成结果与契约一致；包括 Storage 文件、文档和错误码 |
| `python tests/sdk_delivery.py` | 15 项通过，含漏文件、版本漂移、错误码漂移和越界路径拒绝 |
| `python tools/check_repository.py` | 40 份当前文档的链接、锚点、独立 SDK 引用和版本标签检查通过 |
| `git diff --check` | 通过；仅有仓库既有 LF/CRLF 转换提示 |

## 未完成的集成验收

成就仍读取 Host CharacterStore；五包加载与新协议仍在迁移，未运行完整契约，也未提交或同步游戏。必须继续完成实际 TOC 的 SV 声明与恢复时序、业务数据迁出、角色隔离、来源身份升级、未知版本/损坏存档保护、全部功能包合计内存和首查延迟测试。SDK 单模块测试不能替代这些检查。

原预算不变；没有实机前后样本，不宣称常驻内存已经减少。规范见 [PERFORMANCE.md](../../PERFORMANCE.md) 和 [SDK Storage](../../lychee-sdk/docs/STORAGE.md)。
