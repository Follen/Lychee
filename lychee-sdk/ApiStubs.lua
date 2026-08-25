-- Contract/type stubs for editors and offline tests. Development package only.
-- The real implementation is the facade exposed by _G.Lychee.
return {
    Facade = {
        Supports = "function(apiVersion: integer, minRevision: integer?): boolean",
        RegisterReady = "function(callback: function(hostInfo)): token",
        RegisterExtension = "function(descriptor: ExtensionDescriptor): ExtensionDraft, Error?",
    },
    ExtensionDraft = {
        RegisterCommand = "function(descriptor: CommandDescriptor): DeclarationToken, Error?",
        RegisterCapabilityProvider = "function(descriptor: ProviderDescriptor): DeclarationToken, Error?",
        RegisterIntentHandler = "function(descriptor: IntentDescriptor): DeclarationToken, Error?",
        RegisterPanelFactory = "function(descriptor: PanelDescriptor): DeclarationToken, Error?",
        Commit = "function(): ExtensionHandle, Error?",
        Abort = "function(): boolean",
    },
    ExtensionHandle = {
        GetState = "function(): StateSnapshot",
        SetEnabled = "function(enabled: boolean): boolean, Error?",
        Invalidate = "function(key: string): boolean, Error?",
        QueryCapability = "function(request: PlainData, context: ContextSnapshot): PlainData, Error?, ProviderInfo?",
        Unregister = "function(): boolean, Error?",
    },
    LocaleAlias = {
        text = "string",
        locale = "string|default",
    },
    Interaction = {
        primaryActionID = "string",
        actions = "ActionDescriptor[] (max 4)",
        drag = "{ type = 'spell', spellID = integer }?",
    },
    ActionDescriptor = {
        id = "stable string",
        title = "string|locale table",
        kind = "intent|secure-spell",
    },
    Lifecycle = {
        onHostAttached = "function(hostInfo)",
        onHostDetached = "function(reason)",
        onEnabled = "function()",
        onDisabled = "function(reason)",
    },
    ErrorCodes = {
        "SDK_UNAVAILABLE", "UNSUPPORTED_API", "INCOMPATIBLE_HOST",
        "INVALID_SCHEMA", "INVALID_INTERACTION", "REGISTRATION_CLOSED",
        "CALLBACK_ERROR", "COMBAT_LOCKED", "ACTION_UNAVAILABLE", "DRAG_UNSUPPORTED",
    },
}
