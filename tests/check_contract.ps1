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
Write-Output 'Lychee contract checks PASS'
