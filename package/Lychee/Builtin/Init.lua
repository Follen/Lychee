local I = _G.LycheeInternal
I.Builtin = I.Builtin or {}
local function registerCatalogSource(self)
    if self._catalogRegistered or not I.Registry then return end
    local d = I.Registry:Begin({ id = "builtin.catalog", apiVersion = 1, minApiRevision = 1, title = "内置目录" })
    if not d then return end
    d:RegisterSearchSource({
        id = "records",
        version = 1,
        revision = 1,
        priority = 30,
        scope = { product = "retail" },
        records = {
            {
                id = "achievement:fixture-m1",
                kind = "achievement",
                category = { id = "achievements", title = { default = "Achievements", zhCN = "成就" }, order = 20 },
                title = { default = "First Boss", zhCN = "首领初战" },
                aliases = { { text = "M1成就", locale = "zhCN" }, { text = "first boss", locale = "enUS" } },
                description = { { text = "内置成就索引示例。", locale = "zhCN" } },
            },
            {
                id = "quest:fixture-ruby",
                kind = "quest",
                category = { id = "quests", title = { default = "Quests", zhCN = "任务" }, order = 30 },
                title = { default = "Ruby Entrance", zhCN = "红玉入口任务" },
                aliases = { { text = "红玉任务", locale = "zhCN" }, { text = "ruby quest", locale = "enUS" } },
                description = { { text = "内置任务索引示例。", locale = "zhCN" } },
            },
            {
                id = "extension:mrt:fixture",
                kind = "extension",
                category = { id = "extensions", title = { default = "Extensions", zhCN = "插件" }, order = 50 },
                title = { default = "MRT", zhCN = "MRT" },
                aliases = { { text = "MRT小怪技能", locale = "zhCN" }, { text = "mrt", locale = "enUS" } },
                description = { { text = "MRT 接入点索引。", locale = "zhCN" } },
            },
        },
    })
    local handle = d:Commit()
    if handle then self._catalogRegistered = true end
end
function I.Builtin:Init()
    if self._initialized then return end
    self._initialized=true
    if self.PlayerSpells and self.PlayerSpells.Init then self.PlayerSpells:Init() end
    if self.DungeonGuide and self.DungeonGuide.Init then self.DungeonGuide:Init() end
    registerCatalogSource(self)
end
