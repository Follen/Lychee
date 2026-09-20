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
