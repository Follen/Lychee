# 斜杠命令搜索入口修订

版本 0.2.7。运行提交 `a60468b`（入口限制）、`968feb6`（特殊字符命令 ID）。

## 行为与验证范围

原始输入首字符必须是 ASCII `/`。普通文字、旧 `cmd:` / `命令:` 路由、前导空格、全角斜杠、来源筛选及自定义别名不能绕过限制；仅 `/` 返回有界命令列表。历史和固定项仍可直接恢复。双语提示同步更新，不新增存档或 SDK 字段。

搜索策略的内部 rawPrefixes 声明在规范化前排除来源，同时覆盖静态结果、自定义别名与来源筛选。Provider 自身在扫描、观察共享库、申请资源之前拒绝不合格输入。

## 离线验证

- `tests/check_contract.ps1` 完整通过；包含四客户端与 locale 矩阵、查询取消、停用恢复、过期归属、Top 20、超限及无空闲资源回归。
- `/?` 回归在修复前明确失败：`punctuation command must not invalidate batch`；修复后通过，另验证可逆恢复、非法编码及非规范编码拒绝。
- 四客户端 wowdoc validate 均 valid=true，Lua/XML/TOC 静态检查、仓库文档、SDK 和发布清单、git diff --check 通过。
- 接口未增加；沿用 [命令来源证据](2026-09-20-slash-commands.md) 和 [归属接口及运行证据](2026-09-20-slash-ownership.md)。
- 普通文字在策略阶段排除命令来源；直接调用的拒绝路径无需资源 scope。性能替身回归保留有界扫描、Top 20、回收增长及回调预算检查；本轮不声称完成真实客户端完整 CPU/no-GC 性能验收。

## 真实客户端发现

Retail 12.1.0.69875 / Interface 120100 / zhCN，晴昼秋岚—白银之手。使用 lychee-dev 后台自动化，读取完整 Ticket 后 ACK 并清理标记。

- `LYCHEE-20260920-120831-0036`：初次验收在 `/` 列表断言失败。
- `LYCHEE-20260920-121005-0037`：诊断确认 `/rs`、`/dev` 和拒绝路径通过，单独 `/` 的 Provider 返回 INVALID_SCHEMA。
- `LYCHEE-20260920-121123-0038`：逐条契约检查定位 `/?` 的 `slash:/?` ID 非法，其余前 20 条有效。将特殊字符命令表示为可逆 `slash-hex:` ID；不改变普通命令已有引用。

## 交付

按发布清单覆盖同步 186 个运行文件至本机 Retail 的 AddOns/Lychee，逐文件 SHA-256 一致，保留目标额外文件。仅修改已加载模块，无新增 TOC 条目或顺序变化，使用握手 `/reload`。

离线四客户端通过不等于四客户端实测；其余客户端、英文真实界面、物理鼠标点击、战斗场景及完整性能矩阵未在本轮覆盖。

## 最终实机验收

Ticket `LYCHEE-20260920-121432-0039`，request `slash-gate-20260920-04`，revision 4，完整 payload 4826 字节，SHA-256 `f339e9b40bb2fd909f215cbcea2f797dfc2b1ccc655d3ef15443b64efb2baa75`。24 项断言全部通过；11 组宿主搜索中普通 `rs`、`dev`、旧路由、前导空格与强制来源均返回零条命令，`/rs`、`/dev` 正常，`/` 返回 20 条，不存在命令为空，取消后重试正常。历史引用可恢复，取消 scope 零残留且无晚到回复。其他来源仍可返回普通 `dev` 结果。

完整原始报告保存在本机 `%LOCALAPPDATA%/LycheeDev/automation/received/LYCHEE-20260920-121432-0039/content.json`。ACK received 完成，临时任务 slash-gate-live 已移除。查询报告中的 wallMs 包含固定观察等待，不能解释为查询 CPU 耗时。
