# Comet Native Build 编排


仅在已加载 comet-native Skill 且 `comet native status` 确认处于 Build 时应用：

- 主 Agent 先拆分依赖明确、文件互斥的工作单元；有两个以上独立单元时立即派发 2–3 个子 Agent。不能安全并行修改时派发只读调查、测试分析或审查；任务很小且无并行收益时用一行说明。
- 每个子 Agent 明确目标、允许/禁止修改路径、验证命令和返回格式；共用绑定 worktree，不创建分支、worktree 或 change，不并行修改同一文件。
- 子 Agent 禁止修改 `.comet/**`、`docs/comet/**` 和 Runtime 状态/证据，禁止执行 Native 的 new、select、next、checkpoint、receipt、archive 或 doctor --repair。
- 子 Agent 返回完成内容、修改文件、验证命令、实际结果和剩余风险。主 Agent 汇总全部结果、检查冲突、集成并完整验证；只有主 Agent 可更新正式产物、推进阶段、生成 receipt、提交 Verify/Archive，并按 continuation 继续。
