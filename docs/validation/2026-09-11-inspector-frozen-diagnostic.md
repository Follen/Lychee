# 未识别时完成同一位置的逐候选诊断

基线 23a634d32e0aac5c4b6d80ed4472b6a7f21ed8f9。
用户报告：pending，checked=35 queued=83 capped=false；原生命中为聊天
FontStringContainer 后代，nativeFilter=clipped-or-unreadable。
这不证明 RS 按钮被哪条规则排除：队列还没完成，汇总未记录对应对象。

现有 Poll 在 Shift 且 hasDiagnostic 时直接返回，因而复制冻结在中间状态。
现改为无目标时 Shift 请求诊断重放，使用最近一轮快照与其原鼠标坐标。
已检查项也重放以生成明细；继续沿用每批 128 / 0.75 ms、总队列 512 上限。
不重新采样原生栈，也不受移到弹窗按钮的指针位置影响。原有目标仍直接冻结。
本轮完成或找到目标后锁定，未完成且没目标时禁止复制。

仅主动诊断读取 GetDebugName / GetSourceLocation，最多 512 条记录，
名字 120、路径 160 字符，每条附实际筛选原因。报告上限 196608 字符。
普通扫描不生成逐项字符串，恢复正常新一轮时释放明细；关闭、战斗、禁用释放全部。
为支持刚完成时按 Shift，最近一轮 queue/seen 保留至下轮替换或 Stop，总容量不变。
不追加历史快照、计时器、UI、全局扫描或落盘记录。

版本：wowdoc wow-ui-source / retail / latest，resolvedCommit
8ea15b61e45c0ed4eba01439c90757f86eb78d34，source check 无更新。
沿用已有 GetDebugName、GetSourceLocation、GetCursorPosition、GetFrameStack 和 C_Timer
证据与访问保护，没有新增 Blizzard API。诊断会读取现有控件状态，未修改它们。

验证：专项测试覆盖 pending 和 complete 两种 Shift 时机、移动到弹窗后仍使用
原坐标、原生取样次数不增长、全部候选原因入报告、退出诊断停止明细采集。
完整 check_contract.ps1、wowdoc validate（75 Lua，无 diagnostics）、diff check 通过。
普通识别离线成本仍在原预算：100 次统一恢复 11 ms / 6.1 KiB，
100 次启停 5 ms / 302.6 KiB，未观察到保留增长，空闲零工作，无新建 UI。
明细空间按 512 条、每条最多 280 字符来源/名字加固定原因有界；客户端重放和复制
成本仍待实测，不把离线普通路径指标当作诊断开销。

未完成：RS、EUI 资源条/Aura 的实机漏识别原因，必须依据新的逐对象记录判断。
此提交完善取证流程，不声称修复了这些控件的全部过滤失败。
