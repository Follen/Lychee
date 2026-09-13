# 关于页与底部社交浮窗验收

基线：9f925c218c68f738a869d07126336811be6d18a3。根据用户要求新增设置“关于”页，并参考 Ellesmere 底部图标的浮窗交互，将联系方式放在整个设置窗口底部。关于正文只显示品牌、简介、安装版本和作者。设计规范同步至 [DESIGN.md](../../DESIGN.md)。

## 行为、资源和生命周期

- 中文客户端（zhCN/zhTW）：微信赞赏、GitHub、作者微信；英文及其他语言回退：PayPal、GitHub、X。四种语言入口分别有回归。链接分别使用用户提供的 PayPal、Follen/Lychee 仓库和 follenfang 的 X 地址，通过原生 EditBox 全选供复制。
- 设置首次打开时创建底部三个入口；关于内容首次进入时创建并读取一次版本。首次点击入口才创建一个遮罩、一个浮窗、一个地址输入框和一个码图纹理，后续复用；不新增空闲计时器、事件或扫描。
- 底部入口归属 UIParent，避免被内容区域裁切，按主窗口有效缩放和层级显示；离开设置或主窗口关闭时隐藏。浮窗限制屏幕边界，点击遮罩、返回按钮或 Esc 关闭，Esc 优先关闭浮窗。
- 关闭、切页、返回搜索和战斗关闭时释放输入焦点、清空地址与码图纹理、取消动效并隐藏遮罩。保留的固定结构有界，不持久保存 Provider 数据或用户输入。
- 设置通用行和页签创建采用共享循环，保持原有布局及行为。测试装配也加载真实 SocialLinks 模块，不能用桩模块绕开新增入口。

## 素材证据

两张用户原码经 imagegen 转为荔枝配色。用户于2026-09-13回复“两张都能正确识别”，因此采用对应已确认 PNG，不再重新生成。来源、提示词、PNG 和 SHA-256 记录见 [素材说明](../../assets/about/README.md)。五个语义图标中四个来自 Simple Icons（CC0），手托爱心由项目绘制；许可证随运行包交付。

构建工具只做本地素材格式转换：图标64×64透明RGBA TGA、码图512×512 RGBA TGA。检查七张纹理尺寸、编码与哈希，以及两张已确认源图哈希。另检查图标22/28/34/48像素预览及码图256像素预览，未见裁切或缺失；预览在 analyze/about-social/assets-preview.png。这是素材验收，不代表真实游戏窗口视觉验收。用户确认的是生成原图；游戏内256×256显示与不同UI缩放下的扫码尚待复验。

## 性能与回归

用户明确授权将“不含LDT的正式服组合”常驻门禁增加500 KiB，由严格小于1474改为严格小于1974 KiB；PERFORMANCE.md、生成的SDK副本及可执行断言同步更新。完整正式服1858 KiB、其他客户端1346 KiB及全部耗时门槛不变。这是预算变更，不作为性能改善证据。

最终离线测量：不含LDT为1486.4297 KiB/19ms，完整正式服为1848.4746 KiB/24ms，均为2个Frame、4个事件登记。相对基线1472.6338/1834.7021 KiB，本次功能增加约13.8 KiB。1000来源设置列表保留656.5 KiB，20次刷新累计分配0.4 KiB、耗时29ms，对象池增长0。100次最近使用交互231ms总量、4ms峰值，无新增框体；这些均为离线数据。

- 最终 `python tests/run.py --report analyze/about-social/final.json`：102/102通过，包含Lua/XML/Python静态解析、契约、加载清单、SDK、交互及原有性能断言。
- 新增四项 about_social 语言回归，覆盖懒创建、真实元数据、链接/码图、Esc/遮罩/开关、切页、反复打开复用和战斗清理；新增 delivery.about_assets 素材完整性检查。
- 第一次全量为101/102，失败是 performance_ui 独立加载列表遗漏新增SocialLinks，报nil模块错误；修正测试加载清单及原生框体替身后通过，预算断言未删除。原始失败报告保留于 analyze/about-social/full.json。
- 独立代码审查修正返回按钮方向参数后给出代码范围内ship结论；不替代游戏中的命中、动效及缩放验收。

## WoW接口依据

本轮沿用已检查的 sourceId=wow-ui-source、product=retail、requestedRef=12.1.0、matchedTag=12.1.0、resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34。未将远端latest漂移混入本次依据。修改前查询已完成，交付时再次核对关键符号：

| path | line | excerpt |
| --- | --- | --- |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua | 165 | GetAddOnMetadata；参数name:uiAddon、variable:cstring；返回value:cstring |
| Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua | 435 | HighlightText；start默认0、stop默认-1 |

`wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：45个Lua文件，valid=true，无诊断。其他客户端使用相同基本框体交互及防空元数据调用；没有取得对应客户端原生运行验收，不能从正式服证据推出全客户端视觉兼容结论。

## 交付

文档、发布清单与git diff检查通过后提交；提交后按五包188文件清单覆盖同步并逐项比对SHA-256，保留目标旧文件。提交hash及实际同步结果写入 analyze/about-social/sync.json。源码PNG/SVG、工具、SDK和验收材料不复制到游戏。

新增SocialLinks模块并调整TOC加载列表，安装后须重启客户端。仍待实机确认浮窗位置/缩放、Esc原生分发、遮罩命中、最终码图扫码及战斗安全日志。
