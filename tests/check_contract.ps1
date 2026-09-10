$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$toc = Join-Path $root 'package/Lychee/Lychee.toc'
$tocLines = Get-Content $toc | Where-Object { $_ -and $_ -notmatch '^##' }
foreach ($line in $tocLines) {
    if (-not (Test-Path (Join-Path (Join-Path $root 'package/Lychee') $line))) { throw "TOC file missing: $line" }
}
$legacy = rg -n 'OptionalDeps:\s*LycheeSDK|_G\.LycheeSDK' (Join-Path $root 'package') (Join-Path $root 'lychee-sdk') 2>$null
if ($LASTEXITCODE -eq 0) { throw "Legacy SDK facade marker found: $legacy" }
$architectureDocs = @(
    (Join-Path $root 'docs/comet/specs'),
    (Join-Path $root 'docs/ARCHITECTURE.md'),
    (Join-Path $root 'docs/SDK.md'),
    (Join-Path $root 'lychee-sdk')
)
$legacyArchitecture = rg -n '用户输入只匹配 Command|必须注册引用该 Provider|新增数据源时注册 Provider|Provider\s*->\s*Command|可搜索入口是两份显式声明|ambient.*Command 负责直接命中名称' @architectureDocs 2>$null
if ($LASTEXITCODE -eq 0) { throw "Legacy search architecture marker found: $legacyArchitecture" }
if ($LASTEXITCODE -ne 1) { throw "Architecture marker scan failed with exit code $LASTEXITCODE" }
$palette = Get-Content (Join-Path $root 'package/Lychee/UI/Palette.lua') -Raw
if ($palette -match 'OnUpdate') { throw 'Palette must not contain a resident OnUpdate loop' }
$tocSource = Get-Content (Join-Path $root 'package/Lychee/Lychee.toc') -Raw
if ($tocSource -notmatch '(?m)^## Bindings:\s*Bindings\.xml\s*$') { throw 'TOC must declare Bindings.xml with ## Bindings metadata' }
if ($tocSource -match '(?m)^Bindings\.xml\s*$') { throw 'Bindings.xml must not be listed as a normal TOC file' }
$bindings = Get-Content (Join-Path $root 'package/Lychee/Bindings.xml') -Raw
if ($bindings -notmatch '<Binding\s+name="TOGGLELYCHEE"\s+category="BINDING_HEADER_LYCHEE"') { throw 'Lychee binding declaration missing' }
$playerSpells = Get-Content (Join-Path $root 'package/Lychee/Builtin/PlayerSpells/Init.lua') -Raw
if ($playerSpells -match 'LEARNED_SPELL_IN_TAB') { throw 'Legacy spell learned event must not be registered' }
if ($playerSpells -notmatch 'LEARNED_SPELL_IN_SKILL_LINE') { throw 'Retail spell learned event missing' }
if ($playerSpells -match 'Registry:Begin|RegisterSearchSource|RegisterCommand|RegisterCapabilityProvider|RegisterIntentHandler|RegisterPanelFactory') { throw 'PlayerSpells must use the public Provider facade' }
if ($playerSpells -notmatch 'RegisterProvider') { throw 'Built-in public Provider registration missing' }
$paletteSource = Get-Content (Join-Path $root 'package/Lychee/UI/Palette.lua') -Raw
if ($paletteSource -match 'Lychee\.UI\.PaletteController\s*=\s*self') { throw 'Palette controller must remain Host-private' }
$executorSource = Get-Content (Join-Path $root 'package/Lychee/Core/ResultActionExecutor.lua') -Raw
if ($paletteSource -match 'action\.kind\s*==|Router:Execute|PickupSpell|C_Spell\.PickupSpell') { throw 'Palette must delegate action routing to ResultActionExecutor' }
if ($executorSource -notmatch 'ACTION_REQUIRES_HARDWARE_CLICK') { throw 'Secure scripted-click guard missing' }
if ($executorSource -notmatch 'DRAG_UNSUPPORTED|COMBAT_LOCKED') { throw 'Drag/combat guards missing' }
$bootstrapSource = Get-Content (Join-Path $root 'package/Lychee/Bootstrap.lua') -Raw
if ($bootstrapSource -match 'palette\.(session|generation)') { throw 'Bootstrap must not access Palette session/generation internals' }
$querySource = Get-Content (Join-Path $root 'package/Lychee/Search/QueryOrchestrator.lua') -Raw
if ($querySource -match 'Catalog\.commands') { throw 'QueryOrchestrator must use the CommandCatalog public view' }
if ($querySource -match 'self\.generation|local\s+Q\s*=\s*\{[^\r\n]*generation\s*=|_BeginGeneration|function\s+Q:Invalidate') { throw 'SearchSession must be the only query generation owner' }
$playerSpellRuntime = (Get-Content (Join-Path $root 'package/Lychee/Builtin/PlayerSpells/Init.lua') -Raw) + (Get-Content (Join-Path $root 'package/Lychee/Builtin/PlayerSpells/Provider.lua') -Raw)
if ($playerSpellRuntime -match 'StaticIndex|searchSourceID|sourceGeneration') { throw 'PlayerSpells must update through its committed SearchSource handle' }
$scheduler = Get-Content (Join-Path $root 'package/Lychee/Core/Scheduler.lua') -Raw
if ($scheduler -notmatch 'driver|swap-remove|Hide') { throw 'Shared scheduler lifecycle markers missing' }
$fixtureToc = Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.toc'
if ((Get-Content $fixtureToc -Raw) -notmatch 'OptionalDeps:\s*Lychee') { throw 'Third-party fixture OptionalDeps missing' }
$fixture = Get-Content (Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua') -Raw
foreach ($marker in @('RegisterProvider','actions=','views=','drags=','ADDON_LOADED','state.committed')) {
    if ($fixture -notmatch [regex]::Escape($marker)) { throw "Third-party fixture marker missing: $marker" }
}
if ($fixture -match 'match\s*=\s*\{\s*type\s*=\s*"ambient"') { throw 'Stable fixture entities must not duplicate SearchSource through ambient Command' }
if ($fixture -match 'LycheeInternal|RegisterExtension') { throw 'Fixture must depend only on API 2' }
$provider = Get-Content (Join-Path $root 'package/Lychee/Core/ProviderRuntime.lua') -Raw
if ($provider -match 'OnUpdate') { throw 'Provider runtime must not add idle OnUpdate work' }
$sdk = Get-Content (Join-Path $root 'package/Lychee/PublicAPI/SDK.lua') -Raw
if ($sdk -match 'function facade:RegisterExtension|function facade:RegisterSearchSource') { throw 'Old public registration must not be exposed' }
$lua = Get-Command lua -ErrorAction SilentlyContinue
if (-not $lua) { throw 'Lua runtime is required for interaction smoke' }
Push-Location $root
try {
    & $lua.Source 'tests/provider_sdk_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Provider SDK smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/framework_sdk_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Registry boundary smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Built-in/SDK integration smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/builtin_providers_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Built-in providers smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/mounts_vault_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Mounts/vault smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/default_binding_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Default binding smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/interaction_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Interaction smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/result_list_ui_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Result list UI smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/search_platform_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Search platform smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/search_session_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Search session smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/command_catalog_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Command catalog smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/capability_broker_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Capability broker smoke failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/search_memory_regression.lua'
    if ($LASTEXITCODE -ne 0) { throw "Search memory regression failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/performance_memory.lua' '--check'
    if ($LASTEXITCODE -ne 0) { throw "Memory budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/performance_search.lua'
    if ($LASTEXITCODE -ne 0) { throw "Search lifecycle budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/performance_ui.lua' '--check'
    if ($LASTEXITCODE -ne 0) { throw "UI pool budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/performance_core.lua'
    if ($LASTEXITCODE -ne 0) { throw "Core lifecycle budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/perf_core_provider.lua'
    if ($LASTEXITCODE -ne 0) { throw "Provider workload budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/performance_builtin_secure.lua'
    if ($LASTEXITCODE -ne 0) { throw "Built-in lifecycle budget failed with exit code $LASTEXITCODE" }
    & $lua.Source 'tests/perf_builtin_secure_events.lua'
    if ($LASTEXITCODE -ne 0) { throw "Secure event lifecycle failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Output 'Lychee contract checks PASS'
