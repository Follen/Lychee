-- A test AddOn using the shipped package adapter and the real API 1.0.0 boundary.
-- It does not replace Lychee:RegisterProvider or implement Host behavior.
local Fixture={}
function Fixture:Register(definition)
    if self.host~=Lychee then
        self.host=Lychee;self.namespace={}
        assert(loadfile("addon/Lychee_Player/Bootstrap.lua"))("Fixture",self.namespace)
        self.namespace.Modules.Definitions={}
        self.namespace.Modules.Presentation={}
    end
    local ns=self.namespace
    ns.Modules.Presentation[definition.id]={source=definition.source or {id="Fixture",title="Test addon"},
        description=definition.description,icon=definition.icon,order=definition.order,prefixes={}}
    definition.scope=definition.scope or {products={"retail","classic","titan","anniversary"}}
    definition.i18n=definition.i18n or {enUS={}}
    return ns.Modules.Support:Register(definition)
end
return Fixture
