# 紧凑搜索存储验收

2026-09-12。修改前：28f97751306c1cd5460645bc18fbfaa5eabb8b37；修改后见本记录所在功能提交。用户要求可扩展性、SDK/文档同步、搜索引擎简单高效。本轮压缩内部记录/索引行及字符集合，默认来源、角色设置、UI/动画不调整。

## 实际离线结果

固定2689条目录。32位Lua 5.1 CLI（PE machine 0x14c）原版约6888.7 KiB，最终约5300 KiB，下降约23%；48次查询分配1823.9→1773.4 KiB，保留增长0.1 KiB。收紧门禁至5632 KiB（5.5 MiB），未删数据或强制产品GC。

64位 Lua 5.1/Lupa 的每轮实际内存输出保存在 comparison.json；下列为第一轮原始记录，不能与32位预算或游戏AddOn counter混用：

```
MEMORY entries=2689 builtins_KiB=4586.3 combined_KiB=8945.2 48_queries_alloc_KiB=2369.0 retained_growth_KiB=0.1 query_mean_ms=0.292
MEMORY entries=2689 builtins_KiB=3324.4 combined_KiB=6550.0 48_queries_alloc_KiB=2305.9 retained_growth_KiB=0.1 query_mean_ms=0.292
```

7轮交替新旧顺序，每轮120次查询；Python perf_counter计量实际CPU墙钟，模糊预算使用固定测试时钟以排除候选被计时噪声截断。中位耗时单位ms：

| 场景 | 前 | 后 |
| --- | ---: | ---: |
| 120次热查询 | 42.039 | 36.554 |
| 完整离线场景 | 202.971 | 205.352 |
| 100次单条元数据更新 | 4.327 | 4.814 |
| 完整索引重建 | 53.480 | 65.207 |
| 坐骑禁用+恢复 | 31.982 | 35.515 |

热查询门禁≤原版1.15倍通过。最大值和每轮原始值也保留；7轮不能代表尾延迟分位数。完整离线场景包含fixture构建/断言/查询/GC，不能冒充纯Provider构建耗时。完整重建仍有额外成本；关闭/重开面板不调用全量重建。数组存储将部分增删成本从哈希操作转为局部移动，因此不宣称所有操作都加速。已用按序批量插入/反序移除与非搜索字段更新复用编译字段降低这项成本；后续实机若产生可感知卡顿应继续处理，不能抬预算。

## 正确性与扩展

- 全量 tests/check_contract.ps1 通过：角色/default-on、现有Provider、独立全扫描/字面短词、UTF-8/语言、过滤、TopK、SDK隔离、原子更新/重入、动作、动画几何和禁用/关闭等原有门禁保留。
- 新 compact_storage 覆盖未来稀疏字段codec往返、false/nil、嵌套payload、普通SDK回调/导出快照、私有布局不能作为公开输入、回调修改隔离、失败更新、注销GC根、6000次混合集合增删、无ID分类、非搜索字段更新复用索引、饱和错拼候选稳定顺序。
- 7轮前后对照检查固定查询的ID/顺序/显示文字/来源/分类/置信度/匹配证据/动作描述。期望由普通字段结果建立，不按槽位推导。
- **明确行为修订**：超过fuzzyLimit的错拼候选从无序哈希选择改为按稳定记录键选择；这部分不承诺与旧版偶然入选项完全相同。字面匹配、权重和数量/时间预算保持。不是通过缩小数据集证明等价。

Storage 是唯一布局声明；引擎热循环取同一 EntrySlots 的局部常量，Provider/UI不散布数字下标。SDK仍为API2/revision6，外部普通具名字段及payload扩展不变；新顶层字段仍需更新Boundary契约。快照仍具名schema1，不持久化内存布局。无新常驻timer/OnUpdate/Frame/GC。

## 验证与复现

- powershell -NoProfile -File tests/check_contract.ps1：PASS，原始 contract-final.txt。
- python tools/performance-test/verify.py：PASS，62安装文件/61 Lua/58产品模块，0.3.1-compact-search；原始 diagnostic-final.txt。报告带真实提交/dirty/源码树hash。
- luac -p 全部81个生产Lua：PASS；TOC/四产品/语言清单、XML由契约入口检查；git diff --check通过。
- wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest：81 Lua，valid=true，无diagnostics；原始 wowdoc.json。
- python docs/validation/2026-09-12-compact-search/compare.py：需要64位Python及lupa.lua51（本机 analyze/tools/python）；可在仓库根目录运行。原版两模块来自上面固定提交，原版跳过新增Storage，其他生产模块及输入一致。运行会重写 comparison.json，未改产品。

版本化证据：sourceId=wow-ui-source, product=retail, requestedRef=latest, resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34；source check本地远端一致。Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua:509 debugprofilestop，:511说明毫秒计时，:515 elapsedMilliseconds。查询使用原计时API和原模糊时间预算；精确excerpt在clock-evidence.json。本轮存储操作为普通Lua，未新增Frame/Secure/API调用。

## 实机与交付边界

未运行游戏，以上不是实机常驻内存或帧率。新增Storage模块后重启客户端，用新版独立诊断包复测默认全来源、冷/热/关闭、角色切换、实际页面高水位、战斗和视觉。旧报告不自动转为新版本通过。提交后同步到正式服Lychee并按文件哈希验收；诊断包按既有授权同步，旧未加载文件不自动删除，用户原ZIP不覆盖。回滚以新git revert提交后同步，存档格式和用户角色数据无本轮迁移。
