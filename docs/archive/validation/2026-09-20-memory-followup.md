# 内存审计后优化 · 0.3.11

基线 346bbd8（运行 4d609f8，0.3.10），单 Lychee 运行包；SDK/API 1.0.0 不变。无存档 schema、事件、TOC 模块或媒体变更。新增测试只在仓库，不进入游戏包。成本目标：减少无变化目录的临时对象、首页原生按钮高水位；搜索集合/顺序/动作和关闭动画保持不变。不减少来源、数据或历史，不增加产品 GC。

## 实现与生命周期

- CatalogProvider 私有 put 支持已提交且签名相同的 ID 占位；保留4096条总容量和重复检查，完整快照删除判断仍有所有 ID。记录生成后才提交，成功后更新账本；失败、取消、停用和重注册仍按原 epoch/账本处理。
- 背包扫描全部有界1024格；单格位置直接用字符串，多个格位才分配数组。数量、位置、名称、图标变化仍物化完整动作记录。玩具沿用同一签名复用，名称异步补全和收藏变化不变。未增加常驻业务缓存。
- 首页布局元数据归当前 sections 所有，所有条目仍参与布局；屏幕相交条目才绑定池按钮，首次8个，之后按实际视口高水位增长。布局 O(N)，滚动候选扫描 O(N)、实际绑定 O(K)，未声称所有工作变 O(K)。视口/缩放变化重新绑定；键盘移动和激活能定位未绑定目标。按钮复用通过 InteractionBinding 代次、SecureBroker 失效和冷却解绑保护。
- 冻结过渡只释放业务身份，保留画面；真正退出清纹理、文字和 setter 缓存。原生Frame保留供复用，不能按Lua GC当作已销毁。

## 离线对照

Lua 5.1，固定输入，同机；不是游戏总内存。背包测量API返回表复用，排除模拟API info表分配，未包含Host提交成本。

| 场景 | 0.3.10 | 0.3.11 |
|---|---:|---:|
| 200种物品、20次无变化构建：完整记录 | 4000 | 0 |
| 同场景累计分配 KiB | 4166.0 | 713.6 |
| 同场景回收后增长 KiB | 0.1 | 0.1 |
| 同场景CPU ms（单次测量） | 15 | 7 |
| 69项首页、300高视口原生按钮池 | 69（旧预建容量最大77） | 28 |
| 新版20次首尾滚动新增按钮 | — | 0 |
| 2025条组合、48查询分配 KiB | 1888.8 | 1888.8 |
| 同组合查询回收后增长 KiB | 0.1 | 0.1 |
| TOC回收后保留 KiB | 2369.1 | 2372.6 |

背包累计分配约减少82.9%；静态新增约3.5 KiB为额外生命周期/视口逻辑，接受。首页替身对象含大量Lua方法，未把其MiB读数换算成真实引擎字节。

测试包含未变化/格位变化/多格顺序与总数、提交失败重试、删除/取消/重注册、玩具中英文收藏/异步/同步/失败加载、首页69项、过期按压、键盘/视口外激活、冻结/关闭/重开、原交互回归及完整契约。普通查询与设置虚拟列表保持原成本。

## 未采用的方案

- 有序三字节倒排容器849.81→94.23 KiB，但判断慢约2.3倍，且未验证全查询/更新/模糊候选顺序，不接入。
- 本轮整数成员实验826.14 KiB，仅比哈希849.81 KiB少23.67 KiB，尚未计入编号映射；增加映射及回收机制得不偿失。源码保持原字符串成员。
- 规范化缓存固定1024项，同场景约52 KiB；保留其热查询作用。最终候选延后物化会依赖所有动态来源完成，损害首批响应，未采用。

## API 与验证证据

wowdoc source check 后固定 sourceId=wow-ui-source / product=retail / requestedRef=12.1.0 / resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。SimpleTextureBaseAPIDocumentation.lua:600，SetTexture 的 textureAsset 可 nil；ScrollFrame SetVerticalScroll 保留既有调用。retail validate valid=true，132 Lua/0 XML。完整契约、生成清单、仓库链接、发布清单及 diff 检查通过。

## 实机状态

受影响流程：正常搜索/关闭/重开、目录未变化与变更、首页滚动/键盘/按压重绑、冻屏清理、真实背包定位与玩具声明。实机性能与功能分别记录；安全物品使用、真实战斗/taint、其他客户端/语言、团本/姓名板压力不能由脚本模拟宣称通过。

第一次旧版性能探针 Ticket LYCHEE-20260920-194944-0062 / memory0311-before-20260920 / revision 1 在50秒诊断总时限失败；未形成可比较基线，完整失败报告已读取并ACK。此前用户正在操作导致就绪码未返回，按用户明确要求重新发命令后恢复；不归因于运行代码。第二次扩大诊断总时限，产品查询时限未改。后续结果待追加。


### 实机性能对照完成

旧版 Ticket `LYCHEE-20260920-195249-0063` / request `memory0311-before2-20260920` / revision 2；新版 Ticket `LYCHEE-20260920-195746-0064` / request `memory0311-after-20260920` / revision 3。均 complete/succeeded、未截断；Retail 12.1.0.69875 / zhCN / 晴昼秋岚—白银之手，环境完全一致。探针源码相同，只更换任务request身份。完整payload已解析，24次查询的ID/Provider/标题/顺序逐条一致，结束visible/pending/jobs全部false。两份ACK received。

| 真实客户端测量 | 0.3.10 | 0.3.11 |
|---|---:|---:|
| 69项、约302高视口：首页按钮池 | 69 | 28 |
| 20次首尾滚动后的按钮池 | 69 | 28 |
| 关闭后首页图标绑定数 | 69 | 0 |
| 第1轮搜索关闭回收后 Lychee KiB | 14384.72 | 14386.77 |
| 第2轮搜索关闭回收后 Lychee KiB | 14301.13 | 14305.18 |
| 第3轮搜索关闭回收后 Lychee KiB | 14304.50 | 14305.67 |
| 大首页场景结束回收后 Lychee KiB | 13707.16 | 13686.65 |

普通搜索常驻基本不变（约1–4 KiB差）；大首页场景后Lua读数约少20.51 KiB。原生按钮少41个（约59%），引擎/纹理实际字节仍未测，不能把离线替身3.46 MiB当作实机节省。查询完成约2.3–2.7秒，含后台帧率/调度与来源等待，不声称CPU或帧率改善。两次三轮自然Lua读数约22.35/19.11/19.03 MiB，基本不变。

诊断工具独立统计：旧约4351 KiB、新约4387 KiB，包含新增任务源码；不计为Lychee业务占用。全局Lua包括所有第三方，不归因给本改动。测试用诊断GC只发生在固定采样点，产品代码无新增GC。当前角色实际背包/玩具规模由功能探针另记。

完整原始报告分别在 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-195249-0063/content.json` 与 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-195746-0064/content.json`。运行提交 `78de60c`（主实现 `1c08273`），197运行文件SHA-256一致、旧文件保留，自动reload完成。功能探针结果待追加。


### 独立功能覆盖

Ticket `LYCHEE-20260920-195957-0065` / request `memory0311-func-20260920` / revision 1，完整 succeeded，Retail/zhCN/同角色。测试来源只执行无副作用回调，不模拟安全物品使用。覆盖首批结果/慢来源完成、正常回调、菜单与冷却绑定、设置切页清理、6→1→6结果、失败可见/重试、取消/关闭/重开、注销/重注册；另覆盖69项首页、滚动后旧按压失效、末项可见、重绑回调、键盘带入视口、20次滚动池稳定、冻结保留素材、关闭逐按钮清纹理及重开绑定。

真实当前目录：背包84种、玩具145件，无变化build分别复用84/145项、完整记录生成均0。真实背包定位返回成功；测试结束停止发光、关闭Ellesmere背包，冷却bindings/groups=0、listening/scheduled=false、查询无待办；两临时Provider删除。未测真实安全点击/放置、战斗taint、其他客户端/语言、团本和姓名板峰值。ACK received。

最终补充提交 `717b382`：滚动后刷新原生scroll child rect，离线新增断言并通过原交互回归；197文件重新同步并核对。对应API证据同固定retail commit，SimpleScrollFrameAPIDocumentation.lua 的 UpdateScrollChildRect。最后实机复测另记，不用前一Ticket覆盖后续修改。

### 最终版本复测与收尾

用户暂停操作后重新发送重载，nonce `req-20260920-120340-2b8a45` 返回 reload_ready。最终运行提交 `717b38243c5f42b6713cd809d21ef9f2be0c907a`，0.3.11，197个运行文件已同步并逐一核对SHA-256。

Ticket `LYCHEE-20260920-200623-0066` / task `memory0311func` / request `memory0311-func2-20260920` / revision 2，Retail 12.1.0.69875 / zhCN / 同角色，complete=true、status=succeeded、outputTruncated=false。完整2657字节payload已读取并核对身份，包含最终新增的 `native scroll geometry refreshed` 断言；前述功能覆盖再次全部通过。首页69项使用28个按钮，背包84项、玩具145项复用，完整记录生成均0；关闭后冷却bindings/groups=0、listening/scheduled=false，查询无待办，临时Provider已删除。

完整报告：`C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260920-200623-0066/content.json`。ACK received 已确认，本轮 `memory0311` 与 `memory0311func` 自动任务已移除。最终完整契约检查PASS，wowdoc validate valid=true，相关静态/清单/diff检查通过。未覆盖项仍为真实安全点击与地面放置、战斗taint、其他客户端/语言及团本/姓名板峰值；不将诊断脚本回调视为这些流程的验收。
