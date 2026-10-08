# Compiles apps/windows/Resources/app.rc (icon + version block) into
# apps/windows/Resources/build/app.res, which Package.swift links into the
# executable when it exists. Needs the Visual Studio environment (dev-env.ps1)
# for rc.exe and windows.h.
$ErrorActionPreference = 'Stop'
if (-not $script:MxUWindowsEnvReady) {
    . (Join-Path $PSScriptRoot 'dev-env.ps1')
}

$resources = Resolve-Path (Join-Path $PSScriptRoot '..\..\apps\windows\Resources')
$icon = Join-Path $resources 'app.ico'
if (-not (Test-Path $icon)) {
    & (Join-Path $PSScriptRoot 'make-icon.ps1') -Out $icon
}
$build = Join-Path $resources 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$res = Join-Path $build 'app.res'

$rc = Get-Command rc.exe -ErrorAction SilentlyContinue
if (-not $rc) {
    $candidates = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\rc.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
    if ($candidates) { $rc = $candidates[0] } else { throw 'rc.exe (Windows SDK) was not found; install the Windows 10/11 SDK with the Build Tools.' }
}
Push-Location $resources
try {
    & $rc.Source /nologo /fo $res app.rc
    if ($LASTEXITCODE -ne 0) { throw "rc.exe failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "Resources compiled to $res"
