local I=_G.LycheeInternal
I.BuiltinLocaleData=I.BuiltinLocaleData or {}
I.BuiltinLocaleData["builtin.ldt"]={
    enUS={ ["荔枝大米助手"]="LDT",["怪物资料"]="Creature reference",["查看资料"]="View details",["首领"]="Boss",["小怪"]="Enemy",
        ["技能"]="Abilities",["技能资料暂未加载"]="Ability data not loaded",["资料暂不可用"]="Details unavailable",
        ["请先脱离战斗"]="Leave combat first",["返回搜索"]="Back to search",["上一页"]="Previous",["下一页"]="Next",
        ["暂无技能资料"]="No abilities recorded",["模型暂不可用"]="Model unavailable",["基础生命"]="Base health",
        ["基础进度"]="Base forces",["等级"]="Level",["类型"]="Type",["可打断"]="Interruptible",
        ["魔法"]="Magic",["诅咒"]="Curse",["中毒"]="Poison",["疾病"]="Disease",["激怒"]="Enrage",["流血"]="Bleed",
        ["左转"]="Turn left",["右转"]="Turn right",["重置"]="Reset",["基础资料，随难度和变体变化"]="Base values vary with difficulty and variants",
        ["人型生物"]="Humanoid",["野兽"]="Beast",["亡灵"]="Undead",["恶魔"]="Demon",["龙类"]="Dragonkin",
        ["元素生物"]="Elemental",["机械"]="Mechanical",["巨人"]="Giant",["畸变怪"]="Aberration",
        ["隐形"]="Stealthed",["侦测隐形"]="Detects stealth",["可受控制"]="Affected by",
        ["昏迷"]="Stun",["恐惧"]="Fear",["瘫痪"]="Incapacitate",["迷惑"]="Disorient",["减速"]="Slow",["定身"]="Root",
        ["查看特性"]="View traits",["未记录"]="Not recorded",["放逐"]="Banish",["拉拽"]="Grip",["休眠"]="Hibernate",
        ["禁锢"]="Imprison",["击退"]="Knock",["精神控制"]="Mind control",["安抚心灵"]="Mind soothe",["变形"]="Polymorph",
        ["忏悔"]="Repentance",["闷棍"]="Sap",["恐吓野兽"]="Scare beast",["束缚亡灵"]="Shackle undead",["沉默"]="Silence",["梦游"]="Sleep walk",["嘲讽"]="Taunt",
        ["重置视角"]="Reset view",["特性"]="Traits",["复位"]="Reset",["拖动旋转 · 滚轮缩放"]="Drag to rotate · Scroll to zoom",
        ["Shift + 左键：贴入聊天框"]="Shift + click: link in chat",["链接暂不可用，请稍后重试"]="Link unavailable. Try again shortly",
    },zhCN={}}
for key in pairs(I.BuiltinLocaleData["builtin.ldt"].enUS) do I.BuiltinLocaleData["builtin.ldt"].zhCN[key]=key end
