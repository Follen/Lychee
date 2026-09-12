# 搜索存储与扩展契约

Provider API 2 / revision 6 保持不变。Host 内部采用紧凑记录和字符集合；扩展继续提交普通具名对象，不需要数字编号、数组下标或私有 Storage。

- `entries` / Update / query reply / resolve 返回值先经完整安全校验和隔离复制。错误、增量原子性、取消与结果身份保持原契约。
- 自定义数据放 `payload`；其嵌套字段和稀疏键保留。不能随意添加未在 SDK 声明的顶层字段。未来 Host 新增合法顶层字段时，存储层可按需保存而不要求所有 Provider 改格式。
- `actions.run` / `drags.begin` 收到普通具名记录副本，可正常遍历；修改它不会改变已登记内容。内部元表、数字槽位、canonical 引用不是公开契约。
- Host 导出快照保持具名记录和原 schema；不要把 LycheeInternal 或内存布局写入自己的 SV。
- 正常匹配、权重、过滤和动作契约保持。候选很多的模糊匹配现在按稳定记录键选择有限候选；旧版本依赖无序哈希，不保证所有错拼的入选项与旧版相同。不要依赖并列模糊候选的旧偶然顺序。

新增 Provider 使用既有 RegisterProvider；新生命周期/字段需连同输入验证、注销/恢复、外部修改隔离及搜索等价测试更新。实现设计见 [紧凑搜索存储](../docs/architecture/2026-09-12-compact-search.md)，硬门禁仅在 [PERFORMANCE.md](../PERFORMANCE.md) 维护。
