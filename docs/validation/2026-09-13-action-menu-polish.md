# 右键菜单标题与尺寸校正

- 依据用户实机截图：旧“菜单”标题11号、图标20方形，图标抢眼且标题偏弱。改为“操作菜单 / Actions”，14号暖白标题配14方形现有图标；顶距14→12，首项起点44→36。
- 操作保持12号、30行高；内容最小宽168→144，三个短操作的外框184×142→160×134逻辑单位。标题图标与操作文字左侧起点均为20。长文案测量增宽、296最大宽、18操作上限和小视口缩放不变。
- DESIGN.md 新增独立“右键菜单”小节及标题/图标/操作规格表；更新旧摘要中的最小宽度及自有浮层说明。
- 仅修改文案、主题角色和几何常量；无新增Frame、文本区域、纹理文件、timer、事件或每帧工作。沿用原菜单首次创建/重复复用/关闭释放动作的生命周期及全部性能门槛。标题私有字段统一为已存在的title命名，不新增字段字符串。
- 冷加载初版1474.0049 KiB触及严格1474 KiB上限，原始失败保留于 analyze/tests/action-menu-polish.json；最终同路径测量1473.9893 KiB、24 ms，门槛未调整。余量很小，不宣称性能改善。
- `python tests/run.py --report analyze/tests/action-menu-polish-final.json`：93/93通过，包含Lua/XML/Python解析、四客户端TOC、SDK、交互、本地化、发布清单和原性能门禁；菜单重复打开与动作身份检查通过。未新增仅复述尺寸常量的测试。
- `wowdoc validate --path addon/Lychee --source wow-ui-source --product retail --ref 12.1.0`：44个Lua文件，valid=true，无诊断。文档与差异检查通过。

版本证据：source list/check后固定 `sourceId=wow-ui-source`、`product=retail`、`requestedRef=12.1.0`、`matchedTag=12.1.0`、`resolvedCommit=8ea15b61e45c0ed4eba01439c90757f86eb78d34`。`Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua:500` 的 `SetFont` 参数为 `fontFile:FontAsset`、`fontHeight:uiFontHeight`、可选flags，并返回success；通过现有Theme字体接口改变角色，不修改共享字体。行内图标机制沿用[前次取证](2026-09-13-tooltip-menu.md)。

新外观尚未实机截图验收；需 `/reload` 检查字体、纹理比例、中英文及不同UI缩放。没有新增模块或TOC，本轮不要求重启。提交成功后按五包发布清单覆盖同步并核对SHA-256，保留旧文件；实际hash及同步清单记录于 analyze/tests/action-menu-polish-sync.json。
