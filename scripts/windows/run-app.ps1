# Builds the Windows host and runs it. Arguments go straight to mxu-slides.exe:
#
#   .\scripts\windows\run-app.ps1 --demo
#   .\scripts\windows\run-app.ps1 --library D:\Church\Library --no-browser
#
$ErrorActionPreference = 'Stop'

if (-not $script:MxUWindowsEnvReady) {
    . (Join-Path $PSScriptRoot 'dev-env.ps1')
}

$package = Resolve-Path (Join-Path $PSScriptRoot '..\..\apps\windows')
$ffi = Resolve-Path (Join-Path $PSScriptRoot '..\..\apps\mac\Packages\automerge-swift')
if (-not (Test-Path (Join-Path $ffi 'Libraries\windows-x86_64\uniffi_automerge.lib'))) {
    Write-Host 'Building the Automerge native library first (one time)...'
    & (Join-Path $PSScriptRoot 'build-automerge-ffi.ps1')
}
if (-not (Test-Path (Join-Path $package 'Vendor\WebView2\include\WebView2.h'))) {
    & (Join-Path $PSScriptRoot 'fetch-webview2.ps1')
}
if (-not (Test-Path (Join-Path $package 'Resources\build\app.res'))) {
    & (Join-Path $PSScriptRoot 'build-resources.ps1')
}

Push-Location $package
try {
    & swift build --force-resolved-versions
    if ($LASTEXITCODE -ne 0) { throw "swift build failed with exit code $LASTEXITCODE" }
    $binary = & swift build --force-resolved-versions --show-bin-path
    $exe = Join-Path $binary.Trim() 'mxu-slides.exe'
    & $exe --web (Join-Path $package 'web') @args
} finally {
    Pop-Location
}
