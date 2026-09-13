$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$toc = Join-Path $root 'addon/Lychee/Lychee.toc'
$tocLines = Get-Content $toc | Where-Object { $_ -and $_ -notmatch '^##' }
foreach ($line in $tocLines) {
    if (-not (Test-Path (Join-Path (Join-Path $root 'addon/Lychee') $line))) { throw "TOC file missing: $line" }
}
$legacy = rg -n 'OptionalDeps:\s*LycheeSDK|_G\.LycheeSDK' (Join-Path $root 'addon') (Join-Path $root 'lychee-sdk') 2>$null
if ($LASTEXITCODE -eq 0) { throw "Legacy SDK facade marker found: $legacy" }
$childPrivate = rg -n 'LycheeInternal' (Join-Path $root 'addon/Lychee_Player') (Join-Path $root 'addon/Lychee_Encounters') (Join-Path $root 'addon/Lychee_Integrations') (Join-Path $root 'addon/Lychee_Inspector') 2>$null
if ($LASTEXITCODE -eq 0) { throw "Child package uses Host-private state: $childPrivate" }
if ($LASTEXITCODE -ne 1) { throw 'Child package boundary scan failed' }
$architectureDocs = @(
    (Join-Path $root 'docs/comet/specs'),
    (Join-Path $root 'docs/ARCHITECTURE.md'),
    (Join-Path $root 'lychee-sdk/docs/GETTING_STARTED.md'),
    (Join-Path $root 'lychee-sdk')
)
$legacyArchitecture = rg -n '用户输入只匹配 Command|必须注册引用该 Provider|新增数据源时注册 Provider|Provider\s*->\s*Command|可搜索入口是两份显式声明|ambient.*Command 负责直接命中名称' @architectureDocs 2>$null
if ($LASTEXITCODE -eq 0) { throw "Legacy search architecture marker found: $legacyArchitecture" }
if ($LASTEXITCODE -ne 1) { throw "Architecture marker scan failed with exit code $LASTEXITCODE" }
$palette = Get-Content (Join-Path $root 'addon/Lychee/UI/Palette.lua') -Raw
if ($palette -match 'OnUpdate') { throw 'Palette must not contain a resident OnUpdate loop' }
$tocSource = Get-Content (Join-Path $root 'addon/Lychee/Lychee.toc') -Raw
if ($tocSource -notmatch '(?m)^## Bindings:\s*Bindings\.xml\s*$') { throw 'TOC must declare Bindings.xml with ## Bindings metadata' }
if ($tocSource -match '(?m)^Bindings\.xml\s*$') { throw 'Bindings.xml must not be listed as a normal TOC file' }
$bindings = Get-Content (Join-Path $root 'addon/Lychee/Bindings.xml') -Raw
if ($bindings -notmatch '<Binding\s+name="TOGGLELYCHEE"\s+category="BINDING_HEADER_LYCHEE"') { throw 'Lychee binding declaration missing' }
$playerSpells = Get-Content (Join-Path $root 'addon/Lychee_Player/PlayerSpells/Init.lua') -Raw
if ($playerSpells -match 'LEARNED_SPELL_IN_TAB') { throw 'Legacy spell learned event must not be registered' }
if ($playerSpells -notmatch 'LEARNED_SPELL_IN_SKILL_LINE') { throw 'Retail spell learned event missing' }
if ($playerSpells -match 'Registry:Begin|RegisterSearchSource|RegisterCommand|RegisterCapabilityProvider|RegisterIntentHandler|RegisterPanelFactory') { throw 'PlayerSpells must use the public Provider facade' }
if ($playerSpells -notmatch 'Support:Register') { throw 'Player package Provider registration missing' }
$paletteSource = Get-Content (Join-Path $root 'addon/Lychee/UI/Palette.lua') -Raw
if ($paletteSource -match 'homeView\.(tiles|sections|content)\b|self\.homeDirty\b') { throw 'HomeView must own home content, bindings and dirty state' }
$sessionSource = Get-Content (Join-Path $root 'addon/Lychee/Search/SearchSession.lua') -Raw
if ($sessionSource -match 'HasPendingQuery|palette\.(session|generation|searchPending)\s*=') { throw 'SearchSession must publish identity/results/progress through one presentation interface' }
if ($paletteSource -match 'Lychee\.UI\.PaletteController\s*=\s*self') { throw 'Palette controller must remain Host-private' }
$executorSource = Get-Content (Join-Path $root 'addon/Lychee/Core/ResultActionExecutor.lua') -Raw
if ($paletteSource -match 'action\.kind\s*==|Router:Execute|PickupSpell|C_Spell\.PickupSpell') { throw 'Palette must delegate action routing to ResultActionExecutor' }
if ($executorSource -notmatch 'ACTION_REQUIRES_HARDWARE_CLICK') { throw 'Secure scripted-click guard missing' }
if ($executorSource -notmatch 'DRAG_UNSUPPORTED|COMBAT_LOCKED') { throw 'Drag/combat guards missing' }
$bootstrapSource = Get-Content (Join-Path $root 'addon/Lychee/Bootstrap.lua') -Raw
if ($bootstrapSource -match 'palette\.(session|generation)') { throw 'Bootstrap must not access Palette session/generation internals' }
$querySource = Get-Content (Join-Path $root 'addon/Lychee/Search/QueryOrchestrator.lua') -Raw
if ($querySource -match 'I\.(Catalog|Broker|Router)') { throw 'QueryOrchestrator must use Provider results only' }
if ($querySource -match 'self\.generation|local\s+Q\s*=\s*\{[^\r\n]*generation\s*=|_BeginGeneration|function\s+Q:Invalidate') { throw 'SearchSession must be the only query generation owner' }
$playerSpellRuntime = (Get-Content (Join-Path $root 'addon/Lychee_Player/PlayerSpells/Init.lua') -Raw) + (Get-Content (Join-Path $root 'addon/Lychee_Player/PlayerSpells/Provider.lua') -Raw)
if ($playerSpellRuntime -match 'StaticIndex|searchSourceID|sourceGeneration') { throw 'PlayerSpells must update through its committed SearchSource handle' }
$scheduler = Get-Content (Join-Path $root 'addon/Lychee/Core/Scheduler.lua') -Raw
if ($scheduler -notmatch 'driver|swap-remove|Hide') { throw 'Shared scheduler lifecycle markers missing' }
$fixtureToc = Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.toc'
if ((Get-Content $fixtureToc -Raw) -notmatch 'OptionalDeps:\s*Lychee') { throw 'Third-party fixture OptionalDeps missing' }
$fixture = Get-Content (Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua') -Raw
foreach ($marker in @('RegisterProvider','actions=','views=','drags=','ADDON_LOADED','state.committed')) {
    if ($fixture -notmatch [regex]::Escape($marker)) { throw "Third-party fixture marker missing: $marker" }
}
if ($fixture -match 'match\s*=\s*\{\s*type\s*=\s*"ambient"') { throw 'Stable fixture entities must not duplicate SearchSource through ambient Command' }
if ($fixture -match 'LycheeInternal|RegisterExtension') { throw 'Fixture must depend only on API 1.0.0' }
$provider = Get-Content (Join-Path $root 'addon/Lychee/Core/ProviderRuntime.lua') -Raw
if ($provider -match 'OnUpdate') { throw 'Provider runtime must not add idle OnUpdate work' }
$sdk = Get-Content (Join-Path $root 'addon/Lychee/PublicAPI/SDK.lua') -Raw
if ($sdk -match 'function facade:RegisterExtension|function facade:RegisterSearchSource') { throw 'Old public registration must not be exposed' }
Write-Output 'Architecture contracts PASS'
