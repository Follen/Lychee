local I = _G.LycheeInternal
function I.Builtin:Init()
    if self._initialized then return end
    self._initialized = true
    local product = I.Search.RuntimeIdentity:Current().product
    for _, definition in ipairs(self.Definitions) do
        local module = self[definition.module]
        if module and type(module.Init) == "function" and self.Support:Available(definition, product) then
            module:Init()
        end
    end
end
