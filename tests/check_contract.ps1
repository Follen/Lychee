$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$toc = Join-Path $root 'package/Lychee/Lychee.toc'
$tocLines = Get-Content $toc | Where-Object { $_ -and $_ -notmatch '^##' }
foreach ($line in $tocLines) {
    if (-not (Test-Path (Join-Path (Join-Path $root 'package/Lychee') $line))) { throw "TOC file missing: $line" }
}
$legacy = rg -n 'OptionalDeps:\s*LycheeSDK|_G\.LycheeSDK' (Join-Path $root 'package') (Join-Path $root 'lychee-sdk') 2>$null
if ($LASTEXITCODE -eq 0) { throw "Legacy SDK facade marker found: $legacy" }
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
$paletteSource = Get-Content (Join-Path $root 'package/Lychee/UI/Palette.lua') -Raw
if ($paletteSource -match 'Lychee\.UI\.PaletteController\s*=\s*self') { throw 'Palette controller must remain Host-private' }
if ($paletteSource -notmatch 'ACTION_REQUIRES_HARDWARE_CLICK') { throw 'Secure scripted-click guard missing' }
if ($paletteSource -notmatch 'DRAG_UNSUPPORTED|COMBAT_LOCKED') { throw 'Drag/combat guards missing' }
$scheduler = Get-Content (Join-Path $root 'package/Lychee/Core/Scheduler.lua') -Raw
if ($scheduler -notmatch 'driver|swap-remove|Hide') { throw 'Shared scheduler lifecycle markers missing' }
$fixtureToc = Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.toc'
if ((Get-Content $fixtureToc -Raw) -notmatch 'OptionalDeps:\s*Lychee') { throw 'Third-party fixture OptionalDeps missing' }
$fixture = Get-Content (Join-Path $root 'lychee-sdk/examples/ThirdPartyFixture/ThirdPartyFixture.lua') -Raw
foreach ($marker in @('RegisterExtension','RegisterCapabilityProvider','RegisterPanelFactory','RegisterIntentHandler','RegisterCommand','Commit','ADDON_LOADED','state.committed')) {
    if ($fixture -notmatch [regex]::Escape($marker)) { throw "Third-party fixture marker missing: $marker" }
}
$lua = Get-Command lua -ErrorAction SilentlyContinue
if (-not $lua) { throw 'Lua runtime is required for interaction smoke' }
Push-Location $root
try {
    & $lua.Source 'tests/interaction_smoke.lua'
    if ($LASTEXITCODE -ne 0) { throw "Interaction smoke failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Output 'Lychee contract checks PASS'
