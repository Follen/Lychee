local addonName,I=...
assert(I.SDK.WhenSavedVariablesReady(addonName,function()
    I.savedVariablesReady=true
    if I.Store and I.Store.Initialize then I.Store:Initialize() end
    I:Initialize()
end))
