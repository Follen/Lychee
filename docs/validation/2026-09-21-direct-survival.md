# 首段生存计算 0.3.20

用户明确只计算首段，删除DOT、持续跳数、累计伤害与所有手动伤害/类型/范围编辑。UI只有生命、直接承伤、是否致死三项结果，保留层数及效果勾选。纯DOT返回noDirect，不能被识别的说明不返回安全结论。

圣化护甲读取当前天赋等级：基础范围减伤每级3%，神圣每级1.5%。最终生命/护甲取自身面板，不重复叠加耐力/护甲。物理经过护甲，魔法/流血不经过护甲；范围减伤独立乘算。

萨拉斯抗性合剂按用户截图物品241320模拟165全能等级，增益1235057；已有增益已反映在面板，不重复相加。按当前全能等级前后分别调用GetCombatRatingBonusForCombatRatingValue计算新增收益，调用仅发生在进入/刷新快照时。

## 成本及验证

基线c62cdbf模块439.7 KiB；本轮422.8 KiB。移除3个EditBox和附属控件、旧文案，新增合剂1条固定规则/快照标量。固定10行复用不增加池容量，无SV、无计时器/OnUpdate。离线50轮开关保留-1.03 KiB，无新增控件；1000次计算7ms、0 KiB分配。全部属于单包Lychee测试环境，非游戏全包总堆或纹理内存。

新增/修订回归：物理范围、魔法范围、非范围、流血、天赋等级、纯DOT、类型未知、忽略后续DOT、合剂增量及已有增益不重复。完整契约和实机结果在完成后补录。

## 证据

wowdata local cn/wow zhCN 12.1.0.69875：SpellName 1230875/1235057 萨拉斯抗性合剂，SpellEffect 1235057 aura189；402964 effect1 aura229、学校掩码127。实际当前专精数值以用户提供的2/2天赋说明及客户端读取验证；护甲提高不是同值减伤。

wowdoc sourceId=wow-ui-source/product=retail/requestedRef=12.1.0/resolvedCommit=4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59。Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua:316–330，GetCombatRatingBonusForCombatRatingValue(ratingIndex,value)，返回number可空。相同文件:300–314 GetCombatRatingBonus返回当前等级收益，受属性secret限制。读取统一通过既有number/call检查。

实机计划：自动魔法范围识别、读取自身天赋、三项结果、合剂前后差异、致死/可承受、返回/关闭/重开；当前正式服中文。其他职业、语言及硬件操作仍待验收。

## 验收结果

提交47e81aa已同步到正式服，199文件SHA-256一致，保留73个旧文件。完整契约、运行Lua语法、wowdoc validate(valid=true)、diff检查通过。

Ticket `LYCHEE-20260921-003354-0078`，完整payload本机 `C:/Users/follen/AppData/Local/LycheeDev/automation/received/LYCHEE-20260921-003354-0078/content.json`。Retail 12.1.0.69875 zhCN 灵止光—死亡之翼。task=ldt-direct-live/request=ldt-direct-20260921-a/revision=1，complete=true/status=succeeded，9项断言全部通过。ACK确认/清理、临时任务移除完成。

实际魔法范围技能270292首段101261.7277、生命827280；读取圣化护甲rank=2。合剂165全能换算增加全能3.055555%、全能减伤1.527778%，勾选后首段99626.8760。高层数致死、自动数据、无编辑控件、合剂行、返回怪物、关闭重开清选项、返回搜索、清理均通过。截图analyze/survival/ui-direct-9.png核对三个结果及合剂勾选布局，无控件重叠。

100次真实计算合计1.5168ms。控件事件由脚本触发，不冒充真实硬件点击或实际服用合剂；不消耗物品。物理/魔法/范围/非范围及合剂已生效去重由离线数值回归验证；当前实机只覆盖神圣圣骑士与魔法范围技能。全包堆/纹理、其他职业、英文排版及战斗未实测。
