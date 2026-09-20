# 斜杠命令 Provider 验收

## 实现前约束

基线提交：2087612。新增 builtin.slash-commands，覆盖 retail/classic/titan/anniversary；默认参与全局搜索，沿用角色显式开关。Provider 自带 enUS/zhCN 词典、zhTW/enGB 回退和独立 64×64 图标。无新增业务存档。

查询才读取普通命令注册表及其暴雪代理/哈希，不扫描全部 _G，不导入或修改暴雪命令表，不安装 hook，不新增空闲事件、Frame 或 timer。查询分批、容量和回调预算统一见 [PERFORMANCE 第18节](../../../PERFORMANCE.md#18-斜杠命令来源)。查询作用域负责取消和释放；元数据只在本次查询内保留。

执行时重新读取注册身份并校验仍有效，保护调用捕获第三方错误；战斗中拒绝执行。受保护命令不冒充普通函数直接执行。查询、历史恢复不执行任何命令。

## 功能覆盖矩阵（实现前）

- 动态注册：pending、proxy、hash、重复别名、注销、替换、延迟注册。
- 搜索：dev、/dev、rs、双语 Provider 名称、无结果、快速换词、关闭重开。
- 执行：左键、空参数、原 editBox 参数、失败后重试、注销后的旧条目、战斗拒绝。
- 集成：RurutiaSuite /rs 和原插件 Logo；Lychee Dev /dev；普通未识别来源回退图标。
- 生命周期：取消、禁用、重新启用、历史/固定引用恢复；零空闲资源。
- 客户端：四 TOC 静态/离线矩阵；实机分别标记，不能用正式服代表其他客户端。
- 语言：zhCN/enUS/zhTW/enGB；源标题、结果类别、管理说明一致。
- 性能：加载、首次查询、重复查询累计分配/保留增长、取消后队列；真实客户端功能与性能分别结论。

## 证据与结果

完整契约检查通过（`pwsh -NoProfile -File tests/check_contract.ps1`）；16 组四客户端/四语言测试通过。新 Provider 测试覆盖注册/暴雪导入哈希/重新注册/注销、空参数及 editBox、错误重试、战斗拒绝、取消、禁用恢复、历史恢复、容量报错和独立全扫描排序参照。宿主对同分结果使用自身稳定引用排序，单独比较候选顺序与最终集合。

Lua 5.1 语法、Bindings XML、客户端清单、SDK 生成副本、交付清单和 git diff --check 均通过。四套精确 TOC 的 wowdoc validate 返回 valid=true；这仅说明静态检查未发现错误。

同机同入口加载（Lua 5.1）：基线 120 文件、29 ms、分配 5128.0 KiB、回收后 2245.2 KiB；新增后 123 文件、32 ms、分配 5177.7 KiB、回收后 2264.2 KiB。新功能约增加 19.0 KiB，来自 Provider 代码、活动语言词典及元数据；无全量命令目录，Frame=2、事件=4 均不变。单次样本不能证明 CPU 差异有统计意义。历史参考总量超线主要在基线已存在，本轮接受这个有限增量以提供动态命令入口，不调整 CPU 门槛。

1000 命令的 20 次查询约分配 3.3 MiB、回收后增长约 39–40 KiB、单回调最大 2 ms；关闭和取消后无活动任务，无新增 Frame。图标是独立 64×64 RGBA TGA（约16 KiB像素），已查看 28/34/48 像素预览；游戏原生纹理内存未实测。

原始本地输出：`analyze/slash-commands/contract.log`、`loading-before.log`、`loading-after.log`、`validate-*.json`。可追溯源码摘录见 [版本化证据](2026-09-20-slash-commands-evidence.json)。sourceId=wow-ui-source；retail 使用已核对的 12.1.0 快照（查询时锁定 commit，未跟随移动标签）；其他产品 requestedRef=latest，具体 resolvedCommit 已记录。

RurutiaSuite 本机 Core/Init.lua 第194行以 AceConsole 注册 rs；第4行导出 RurutiaSuite；TOC 第10行声明 IconTexture。仅为这个已核对的明确接入显示工具箱名和原插件 Logo；不推断任意共享库包装器的插件归属，不宣称通用自动 Logo 识别。查询不复制第三方图片。

**实机功能与性能：待验收。** 本轮已加载 lychee-dev 工作流，当前唯一运行实例为 retail 12.1.0.69875。因新增模块/TOC 必须重启，用户已答复同步后重启进入角色；在取得本次安装提交的 Ticket 前，实机左键、实际 /dev 和 /rs 面板、关闭重开、战斗/taint、冷/热查询、真实内存/帧时间均不标通过。其他三客户端及英文客户端实机同样待验收。尚未下发实机任务，无本轮待清理回执。

交付顺序：相关文件提交成功后覆盖已核对的同名 Lychee 目录，逐文件 SHA-256 校验，保留目标额外文件。回滚使用新 git revert。提交 hash 和同步哈希记录保留在本次任务输出及本地交付清单。
