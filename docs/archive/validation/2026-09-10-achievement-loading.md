# 成就首次搜索时序优化

前版本 686dfd7。明确复现界面缺陷：SearchSession 收到同步空结果就无条件清除 searchPending，尽管 ProviderRuntime 尚有异步 job。修正后根据 Host 当前任务保留加载状态，结束/超时通知界面；不会把异步未完成误报为无匹配。测试独立注入 pending true/false，覆盖同步空结果与最后完成。

成就目录仅自身使用 CatalogProvider 的可选 batchSize=128 / batchDelay=0，其他 Provider 保持 32 / 0.01；约 1 ms 时间预算不变，仍按数量和耗时双重让出。计时器 0 表示让出后恢复，不是取消分批；低帧率客户端仍可能较慢，不宣称固定实机完成时间。6000 条目录仅按数量门槛估算调度下限从约 188 批变为约 47 批，耗时门槛可使实际批次更多，该估算不是游戏测量。

查询目录未就绪时保存一个 resumeQuery，等待构建完成通知，不再每 0.01 秒启动新检查。新查询/取消/停用清空等待闭包；准备完成后 onReady 恢复等待查询。若 Host 的 5 秒超时已经取消等待，目录完成通过现有 SourceChanged 合批机制重查当前会话；隐藏或战斗不执行界面重查。不延长 Host 超时，不缓存历史查询。查询扫描和结果物化的批次延时也改为 0，256/8 与约 1 ms 门槛不变。

生命周期与成本：无新增 Frame、事件、OnUpdate；有且只有一个等待闭包，取消解除引用。冷启动首次查询测试在启用后立刻发起，断言只新增 Host timeout 而没有等待轮询 timer；6002 条目录完成后自动得到“引领潮流”，所有待查状态清空。保留目录 563.4 KiB（包括新增冷查询测试的 Host 结果；旧纯目录约 560.6 KiB），20 次查询分配 150.4 KiB、回收后未见增长，模拟批次峰值 2 ms（粗粒度时钟）。未调整已有 4 MiB / 1 MiB / 128 KiB 预算；共享 CatalogProvider 默认行为没有变化。

完整 check_contract PASS，包含成就冷查询、取消、启停、战斗，以及 SearchSession pending 回归。Lua/XML/TOC 静态与 wowdoc validate 见 checks 和 wowdoc 日志。C_Timer.NewTimer 沿用已查档接口，无新 Blizzard API；onReady/HasPendingQuery 是 Lychee 内部接口。未验证游戏中低帧率、大目录、其他插件引起的调度延迟，游戏帧时间与原生 API 成本不能由模拟替代。超过 Host 5 秒等待仍可能先结束本轮请求，但目录就绪后会自动重新查询；没有伪报超时为永久目录为空。

没有修改 Shift 左键分享，也不重建成就界面。更新后 /reload。回滚使用新的 revert 提交并同步。
