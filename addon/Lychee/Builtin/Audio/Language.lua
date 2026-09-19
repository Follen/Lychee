local I=_G.LycheeInternal
-- Input vocabulary is independent of UI translations. All supported spellings
-- remain available in every locale; only the result title follows the UI locale.
local language={
    targets={
        {id="master",zh={"主音量","总音量","總音量","全局音量","游戏音量","遊戲音量","游戏声音","遊戲聲音","声音大小","聲音大小","声音","聲音","音量"},en={"master volume","master audio","game volume","overall volume","sound volume","sound","master","volume","audio"}},
        {id="music",zh={"音乐音量","音樂音量","背景音乐音量","背景音樂音量","背景音乐","背景音樂","音乐","音樂"},en={"background music volume","background music","music volume","bgm volume","music","bgm"}},
        {id="sfx",zh={"音效音量","效果音量","技能音效","音效"},en={"sound effects volume","sound effect volume","sound effects","effects volume","effects","sfx volume","sfx"}},
        {id="ambience",zh={"环境音量","環境音量","环境音效","環境音效","环境声音","環境聲音","环境音","環境音"},en={"ambient sound volume","ambient sounds","ambience volume","ambience","ambient volume","ambient"}},
        {id="dialog",zh={"对话音量","對話音量","对白音量","對白音量","人物语音","人物語音","角色语音","角色語音","剧情语音","劇情語音","对白","對白","对话","對話"},en={"character voice volume","character voices","dialogue volume","dialogue","dialog volume","dialog"}},
    },
    generic={ ["音量"]=true,["声音"]=true,["聲音"]=true,volume=true,audio=true,sound=true },
    zh={
        polite={"请帮我","請幫我","帮我","幫我","请","請"},
        verb={"设置","設置","設定","设定","调整","調整","调","調"},
        subject={"把","将","將"},
        connector={"",":","为","為","到","成","至","设置为","设置到","设置成","設置為","設置到","設置成","设为","设成","设到","设定为","设定到","設定為","設定到","設為","設成","設到","调整为","调整到","调整至","調整為","調整到","調整至","调为","调到","调成","调至","調為","調到","調成","調至"},
        valuePrefix="百分之",units={"","%","百分比"},suffix={"谢谢","謝謝","吧"},
    },
    en={
        polite={"please"},verb={"set","change","adjust","turn"},subject={"the"},
        connector={"","to","at",":"},units={"","%","percent","per cent"},suffix={"please"},
    },
    words={},
}
-- Native setting aliases and command target names share one vocabulary.
for _,target in ipairs(language.targets) do
    local words={};language.words[target.id]=words
    for _,key in ipairs({"zh","en"}) do
        for _,word in ipairs(target[key]) do words[#words+1]=word end
    end
end
I.Builtin.AudioLanguage=language
