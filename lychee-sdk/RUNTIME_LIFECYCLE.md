# SDK 所有权与生命周期约束

当前实现为 Provider API 2 / revision 6、UI Runtime 1。本轮采用角色存储和内部接收优化，未改变公开签名。用户允许未来破坏式更新，但旧 SDK 3/完全休眠候选不再是本轮实施要求。完整 [设计](../docs/architecture/2026-09-12-runtime-lifecycle.md) 与 [验证](../tests/LIFECYCLE_ACCEPTANCE.md)。

## Provider 接收

注册/更新/动态回复/解析结果仍是外部输入，必须通过访问性、secret、循环、metatable、深度、数量和记录语义检查。Host 在受控接收时复制隔离输入；内部已验证批次的一次性凭据只用于减少 Registry 重复遍历，不增加 public trusted/skipValidation 字段。调用方继续提供普通记录，不依赖任何 LycheeInternal 方法或私有标记。

外部修改输入、持有旧结果、失败后重试、注销再注册同 ID 均沿用原契约。Host 私有相等的动作/类别/短文字元数据可能共享，但交给外部业务回调的快照保持隔离；不允许插件修改 Host canonical 对象。共享池容量包含键和值、按 Provider 限定；大型或唯一数据不应被永久缓存。

## 启用与设置

来源开关、搜索模式、前缀、用户别名和选择记忆按当前角色保存。自带来源默认开启，EUI/EX 仍保留专用搜索入口，不自动打开上游设置。显式用户关闭优先于 Provider 自身 SetEnabled；后续登录、重新注册或版本升级不能重新覆盖角色选择。公开句柄 GetState 的行为保持不变。

面板关闭与来源禁用是不同动作。关闭取消当前查询与视图绑定，不关闭负责保持数据新鲜的必要来源事件；禁用/注销须释放自身 timer、query、事件、临时 UI 引用。成就这种昂贵恢复数据由有界权威缓存保留，不需要每次关闭丢掉目录。

## UI 与扩展性

UI Runtime 继续复用原生结构。release/unmount 清除活动 props/context/回调与任务，已创建 Frame 不视为普通 Lua 临时表。宿主首页也遵守该规则，动画完成后解除结果引用；独立 UI 库没有 CharacterStore 时，Motion 使用独立默认/本地减少动态效果状态。

新增 Provider 复用标准注册与 CatalogProvider 调度，不复制默认关闭或账号存档逻辑。新增设置通过角色存储入口维护；第三方自己的业务数据库归第三方所有，不由 Host 自动迁移。

## 验证

接收安全与隔离：`provider_ingestion.lua`、`provider_record_ownership.lua`、`provider_sdk_smoke.lua`。角色恢复：`character_settings.lua`、`character_pins.lua`、搜索个性化/策略回归。UI：`ui_runtime.lua`、`view_lifecycle.lua`、`interaction_smoke.lua`。统一由 `tests/check_contract.ps1` 执行，不能以 SDK 文档描述替代实际断言。

紧凑搜索存储保持 SDK 2/revision 6；扩展字段、普通回调和模糊候选稳定顺序见 [搜索存储契约](SEARCH_STORAGE.md)。
