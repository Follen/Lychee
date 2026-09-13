# 截断前个性化排序验收

日期：2026-09-13。基线提交：`00b633fc7d75ba6c04cc67490468e55153296a50`。实现范围和版本化 WoW API 证据见[设计记录](../architecture/2026-09-13-personalized-ranking.md)。SDK / Provider API 保持 1.0.0，新增可选能力；不增加时间戳、次数、持久字段或上下文监听。

## 自动化结果

`python tests/run.py --report analyze/tests/personalized-complete.json`：完整 **93/93** 通过。包括 Lua/XML/Python 静态解析、公开 SDK 输入拒绝、独立全扫描 Top K 对照、Catalog Search/Query 一致性、动态 Provider 中间截断、角色与来源隔离、异步迟到/重入、UI、存储、生成一致性与交付检查。

自带动态来源覆盖 Ellesmere、Exwind、Achievements、Bosses 中英文、LDT；验证原本前 20 条以外的多个收藏/最近项进入结果，以及 LDT 同一怪物的非首个技能不会提前被代表项筛选淘汰。保留文本匹配资格、原 confidence/evidence 和同词搜索记忆；无关、过滤、禁用和失效结果不因偏好注入。

`wowdoc validate --path addon/<package> --source wow-ui-source --product retail --ref 12.1.0`：Lychee、Lychee_Player、Lychee_Encounters、Lychee_Integrations、Lychee_Inspector 五包均 valid=true。原始输出位于忽略目录 `analyze/tests/personalized-wowdoc-<package>.json`。Host 在最终运行代码修改后重新验证。

## 性能结果

以下为本机 Lua 5.1 离线测量，不是客户端帧时间。全部既有阈值保留，没有扩大候选容器或性能上限。

| 场景 | 实际结果 |
| --- | --- |
| 满容量 200 次查询，关闭偏好 | 平均 0.310 ms，最大 2 ms；分配 5867.5 KiB，回收后增长 0.14 KiB |
| 满容量 200 次查询，开启偏好 | 平均 0.345 ms，最大 2 ms；分配 5874.0 KiB，回收后增长 0.14 KiB |
| ranker 创建后的 10,000 次标量评分 | 分配 0.00 KiB |
| 搜索/清空 100 个交互循环 | 合计 243 ms，最大 4 ms；分配 24137.4 KiB，回收后无增长，新增 Frame 0 |
| 冷加载基线场景 | 100 文件，20 ms，保留 1473.8 KiB，2 Frame / 4 Event |
| 冷加载完整场景 | 105 文件，25 ms，保留 1850.2 KiB，2 Frame / 4 Event |
| 五包综合运行内存 | 5549.6 KiB；48 次查询分配 2563.2 KiB，回收后增长 0.4 KiB |

初轮检查曾出现冷加载超预算、生成模板漂移、索引测试沿用原型单例，以及交互循环峰值 5–6 ms。通过共用内部函数、收拢最近使用逻辑、修正生成源/真实实例测试、跳过空查询和空交付中的重复工作、减少资源新键的重复检查后，最终完整入口通过。修改前提交在相同相对路径、同一交互测试的一次对照为合计 263 ms、最大 4 ms、分配 23965.6 KiB；单次对照只作参考，不据此宣称稳定的百分比加速。

## 交付与未验证项

检查通过后按五包 release manifest 提交、覆盖复制和核对 SHA-256；实际提交与复制清单保存在本次交付输出及忽略目录 `analyze/tests/personalized-delivery.json`。保留目标旧文件，不修改游戏存档。

没有新增 TOC 文件或改变加载顺序，游戏中 `/reload` 后生效。未执行真实客户端搜索手感、战斗、taint、安全点击或 CPU/帧时间采样。第三方自行扫描的 Provider 需使用新 ranker 并在每层截断前接入；最终 Host 排序无法恢复已经被其私有算法丢弃的候选。
