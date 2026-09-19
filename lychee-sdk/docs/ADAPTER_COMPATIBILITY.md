# 第三方适配与兼容性

性能、容量与生命周期规则统一见[性能规范与内存审查](PERFORMANCE.md)；本页说明接口使用方式。

统一Provider入口减少宿主的业务分支，不代表与上游完全解耦。对方没有稳定公开接口时，
依赖内部字段的代码必须集中在Provider自己的adapter，记录版本证据、缺失能力和维护范围。
产品过滤与实现版本选择仍遵循[客户端差异](CLIENT_VARIANTS.md)，不新增宿主业务判断。

## 当前 Elles 适配契约

`addon/Lychee/Builtin/Ellesmere/Adapter.lua` 在适配插件内部集中版本敏感访问；Provider 保留查询、稳定 ID、捕获容量、排序与取消。此路径仅说明本仓库实现，不是第三方需要遵循或导入的目录契约。
以下是Lychee内部维护接口，不是第三方SDK的新公开字段：

| 上游能力 | 用途 | 不可用时 |
| --- | --- | --- |
| EllesmereUI / EnsureLoaded / _deferredLoaded / _modules | 首次明确EUI查询时加载设置并读取模块 | 显示现有不可用提示；不编造目录或建UI替身 |
| config.pages | 查询、resolve、点击时验证目标页面 | 目标移除即不可用；不持久缓存可变页面集合 |
| L / TAB_LABEL_OVERRIDES | 本地化及页面显示名 | 非法返回、翻译异常或缺失时用原文 |
| _RegisterSearchEntry / _searchIndexSuppress | 被动收集原生注册的具体设置 | 页面目录仍可用；不宣称已收集所有设置 |
| NavigateToElementSettings | 页面/分区/控件定位 | 失败返回EUI_UNAVAILABLE，不关闭搜索或记录成功 |
| EnsureUnlockCore / OpenUnlockMode / _unlockActive | 解锁动作 | 战斗或失败返回原有不可用状态 |

原生导航仍负责首开延迟与页面构建；搜索不执行动态tooltip、不预建页面、不修改值或调用内部索引预构建。
定位参数保持module、page、section、selector callback、label顺序。返回false不是已定义的上游失败契约，
不会擅自重解释；调用抛错会被隔离。

不可移除的 hook 只有所属插件生命周期有效且属于当前上游对象时收集；所有者结束时释放捕获记录并短路。用户关闭来源的搜索开关，只改变参与搜索的偏好，不停止捕获或清空这些记录。
只有hook安装成功才记录已绑定，失败允许后续重试。上游在同一对象上替换已hook函数等变化仍需专门适配，
不能靠反复hook或轮询承诺所有未来版本兼容。

## 缓存与结果正确性

- 区分不可变代码/声明和上游可变状态；没有可靠版本或失效事件时不跨查询缓存目录。
- 分批期间上游可能变化，不能仅凭table身份或长度认定内容没变；resolve/动作仍重新校验页面。
- 查询只为进入前K的候选构造完整记录，评分字段和选中容器有界复用；保留原分数、ID、排序和结果上限。
- 捕获仍最多4096条/2MiB文本；每批32项或1ms让出。查询取消释放该次任务和业务引用；所有者结束才释放后台捕获，空闲不轮询。
- 相关校验已在同一同步候选处理步骤完成时可复用该结果，不重复遍历一次页面列表。

## 版本与验收

已有版本证据：sourceId=ellesmereui，product=main，requestedRef=latest，
resolvedCommit=271ffc30d3265d9f77746b0e15224d918f0fafcb。
`EllesmereUI.lua:5565`为EnsureLoaded，`:9316`为NavigateToElementSettings；
`EllesmereUI_GlobalSearch.lua:22`为_RegisterSearchEntry。实际源位置以验证记录中的wowdoc结果为准。

上游升级时：先source check并查对应版本，再跑缺失/异常/重试/页面变化与真实导航参数测试；
同时比较完整结果、顺序、resolve和动作参数，不能只看“没有报错”。历史44组对照基于优化前3b0af04，不代表本分支或更新后的上游已经通过实机验收。

在完整源码仓库根目录运行 `lua tests/ellesmere_adapter.lua`、`lua tests/ellesmere_equivalence.lua` 和 `lua tests/ellesmere_provider.lua`；独立 SDK 包不包含这些项目测试。
离线通过不证明新版游戏与全部第三方版本可用；游戏内仍需验证首次打开、分区定位、selector及解锁。
