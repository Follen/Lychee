# 客户端范围、Forever 与默认绑定验收

## 变更与边界

客户端身份来自 GetBuildInfo 的 Interface；tools/client_manifest.json 是身份范围、默认支持范围及各 Provider 独立范围的唯一构建入口。生成加载清单继续按客户端裁剪。新增 ClientSupport 为冷发现、注册 Scope 和可选 SDK 实现选择提供一致的闭区间匹配，不探测任意全局变量、不创建业务适配器。

SDK / Provider API 保持 1.0.0。通过 SupportsFeature("client-implementations", 1) 使用可选 SelectClientImplementation；最多16个实现、每个8段、总计32段，拒绝非法输入与全部产品上的重叠。初始化后不保留声明；查询热路径不重新选择实现。

Forever 声明基础来源：技能、背包、基础菜单、暴雪设置定位、插件识别、普通斜杠命令。正式服专属模块、坐骑、成就、装备方案及第三方 UI 集成不进入其 TOC。API 存在不代表业务通过，声明支持不代表下列未测项通过。

默认 Alt+Space 旧逻辑在 SetBinding 之前写入 defaultBindingAttempted，失败也永久停止尝试。新逻辑读取回验并保存成功后记录 defaultBindingComplete；失败保留登录/脱战重试，战斗中不写。保留用户的其他快捷键和已占用 Alt+Space。已有新完成标记的主动解绑不会被重新绑定。旧 attempted 无法区分历史失败和旧版主动解绑，因此旧版未绑定且 Alt+Space 空闲时会修复一次；不清空角色存档。

## 预先定义的用户流程与断言

| 流程 | 断言 | 本次状态 |
| --- | --- | --- |
| 全新安装、登录后呼出 | Alt+Space 注册为 TOGGLELYCHEE 并可保存 | 离线通过；修复版实机待测 |
| 设置失败后再次登录/脱战 | 可重试，完成后不重复保存 | 离线通过 |
| 已有其他快捷键、占键、主动解绑 | 不覆盖已明确的用户选择 | 离线通过；旧版实机已有 Alt+Space 正常 |
| 五客户端 TOC 与能力缺失 | 唯一身份、范围匹配，不加载越端模块；缺能力安全拒绝 | 五端双语言离线通过 |
| 永恒法术书/天赋/缺失菜单 | 使用 PlayerSpellsUtil；缺失入口安全失败；无正式服专属菜单 | 离线通过；实机待测 |
| 搜索技能、背包、菜单、命令 | 内容正确，关闭/重开、快速换词、取消后无旧结果 | 修复版实机待测 |
| SDK 正常/范围错误/重叠/取消/注销重注册 | 只选一个实现；冷热范围一致；不注册未选中的实现 | 离线通过；独立第三方实机待测 |
| 英文、其他三个客户端、战斗安全操作 | 对应功能与 taint 验收 | 本轮实机待测 |

## 源码证据

sourceId 均为 wow-ui-source；product 与 requestedRef 单独固定：

- forever，requestedRef 1.60.1，resolvedCommit 70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e，PIN-de1d6d876f8476fcf10897a1c22c09d916e93d5ba3ca3063a76cb1647625d626。
- retail，requestedRef 12.1.0，resolvedCommit 78282522143e25c3540583734fd192c3d69be910，PIN-1b23405fd36b2183970d75442737537f2bdc79c292ea9cce4b2d6efaae7702ee。

Forever 路径与原文片段：

| path | line | excerpt | 用途 |
| --- | --- | --- | --- |
| Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/PlayerSpellsUtil.lua | 32 | OpenToClassTalentsTab | 原生天赋入口 |
| Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/PlayerSpellsUtil.lua | 50 | OpenToSpellBookTab | 原生法术书入口 |
| Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Keybindings.lua | 139 | SetBinding(newKey, nil, bindingContext); | 原生按键写入调用 |
| Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Keybindings.lua | 143 | SaveBindings(GetCurrentBindingSet()); | 保存当前按键集；不假定返回 true |

后两项全文证据 CAP-167437017566d19dc92e633ce542a1ee1a805a0c8267ad6cac68dc2b47f59ed1，SHA-256 8e2eaac91a2d36ef6abd36488930f29662013ddbe09a0d130d31e5f9e7226bfb。原生函数的调用示例不能证明受保护执行上下文或所有参数类型。

## 修复前实机证据

Retail 12.1.0.69933，灵止光/死亡之翼，旧运行包0.3.38。OP-cc15fb20c7d4dea38cbb62866b417087 已 verified、ACK 完成；CAP-79aea66be6cbcd920a0f9a3a6362832cf690fc4892531f775db18b83857d0da3，SHA-256 4de76b680f30dd4fd7a68bbea699b207edff3621193341e5e06c5ea163635f29。

读取 ALT-SPACE 为 TOGGLELYCHEE，GetBindingKey 返回 ALT-SPACE，bindingSet=2，旧 attempted=true。因此当前角色不能复现用户的新安装报告；旧代码失败路径由 tests/core/default_binding.lua 确定复现，不能把该逻辑缺陷称为所有报告的唯一原因。

另已连接 Forever 1.60.1.70009（Auto/Forever）；连接只确认身份与工具可用，尚不证明荔枝已加载。

## 离线与性能

完整 tests/check_contract.ps1 通过；额外的非法 manifest 范围与永恒菜单分支测试通过。254个 Lua 文件 luac -p、Bindings XML、运行交付清单通过。五端新 lycheedev 静态检查结果另行补记；未完成性与动态未决项不等同错误，也不能称作全覆盖。

离线同输入 TOC 加载：改前正式服134文件、34 ms、累计分配5677.2 KiB、保留2456.2 KiB；改后136文件、32 ms、累计分配5719.5 KiB、保留2481.9 KiB。单次样本不声称 CPU 收益。约25.7 KiB新增常驻来自范围声明与共用选择函数；新增对象由插件生命周期持有，选择器输入与结果不缓存，匹配热路径不分配范围表。Forever92文件、32 ms、累计分配3941.7 KiB、保留1623.5 KiB；不同 TOC 的体积差不能称作同功能优化比例。两端均2个启动Frame、4个事件，没有新增定时器或常驻轮询。

游戏 CPU/内存、关闭后活动、战斗/团本峰值与独立第三方场景仍需实机验证；离线预算通过不替代这些结论。

## 交付

运行版本0.4.0；提交、逐文件同步 SHA-256 及重启后的 Ticket 在实际交付后补记。不得用旧进程的版本号或 /reload 证明新增 TOC 的首次扫描成功。未同步 SDK 至游戏目录，未进行平台或 npm 发布。

## 新版 lycheedev 静态结果

合并 matrix 返回 vault.blob_limit，改用五次单端验证。以下各端 loadValid=true、staticValid=true、load issues=[]，但 complete=false、interfaceStatus=unresolved；工具没有判定这些固定 commit 的 Interface 基线。notChecked 为 binding-identity、argument-types、dynamic-code、combat、taint、runtime-behavior。未决数量包含 Lua 标准库及插件本地/动态调用，不解释为缺失 API 数量。

| product | commit | 未决引用 | capture |
| --- | --- | --- | --- |
| retail | 78282522143e25c3540583734fd192c3d69be910 | 10924 | CAP-802538bc5857e557770d1f7bc348588169eb93369019ef6aa51cb42699705df6 |
| classic | ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | 8904 | CAP-6b88240d6ec19df7cc6b15d8ffbce60e2849bbee8d54fca01b8302041b103159 |
| titan | 84ef503f0d2617494db84cc9c7e7b530e976f6e7 | 8904 | CAP-d930b4aedc4f211f8f47bc04218c62fe6a20525f8a323b0a783de89b9d505bbe |
| anniversary | 1463c686270b6c64e2c5c228f447c4597c0f8ba6 | 8658 | CAP-a02055667539d1349181dd2f0523cb871dca396131e28facb16a7619c9f4b59d |
| forever | 70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e | 8658 | CAP-67294d6f6d273a10b09a72decb8f2c0461c794c919886c31e098f1ece9f863dc |

## 已完成的运行包交付

运行提交 eadd4bc3b98d0276f781360db7282531cf162d35，版本0.4.0。正式服 `D:/Game/World of Warcraft/_retail_/Interface/AddOns/Lychee` 与已确认的 Forever `D:/Game/World of Warcraft/_classic_beta_/Interface/AddOns/Lychee` 均覆盖同步203个清单文件，全部与源文件 SHA-256 一致。目标旧文件未删除。证据保存在本机 analyze/client-support-validation/delivery.json。

截至本记录，两端均等待完全重启后验证；新运行包的功能与性能结论仍为待验收。已准备 PRB-7255c3712d11cc1ae64b130af12a0518ae553c47353ab37119a2ce6fc0f5136d（尚未 load/run），它只测试绑定状态及目标函数、来源/SDK 生命周期和查询开关，不能代替物理 Alt+Space 输入、独立第三方冷加载或战斗验证。没有进行 npm 或平台发布。
