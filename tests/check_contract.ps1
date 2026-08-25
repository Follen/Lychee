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
if ((Get-Content (Join-Path $root 'package/Lychee/Lychee.toc') -Raw) -notmatch 'Bindings\.xml') { throw 'TOC must load Bindings.xml' }
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
Write-Output 'Lychee contract checks PASS'
