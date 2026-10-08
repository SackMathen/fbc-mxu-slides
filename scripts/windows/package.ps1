# Builds a release of MxU Slides for Windows and assembles a folder that runs
# on a machine without the toolchain:
#
#   dist\MxU Slides\            MxU Slides.exe, web\, the Swift runtime and
#                               C++ runtime DLLs it imports, licenses, a README
#   dist\MxU-Slides-<version>-windows-x64.zip
#
# The WebView2 runtime is part of Windows 11 and Edge; the README says where to
# get it otherwise.
param(
    [string]$Version = '0.1.0'
)
$ErrorActionPreference = 'Stop'
if (-not $script:MxUWindowsEnvReady) {
    . (Join-Path $PSScriptRoot 'dev-env.ps1')
}

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$package = Join-Path $repo 'apps\windows'
$ffi = Join-Path $repo 'apps\mac\Packages\automerge-swift'
if (-not (Test-Path (Join-Path $ffi 'Libraries\windows-x86_64\uniffi_automerge.lib'))) {
    & (Join-Path $PSScriptRoot 'build-automerge-ffi.ps1')
}
if (-not (Test-Path (Join-Path $package 'Vendor\WebView2\include\WebView2.h'))) {
    & (Join-Path $PSScriptRoot 'fetch-webview2.ps1')
}
& (Join-Path $PSScriptRoot 'build-resources.ps1')

Push-Location $package
try {
    Write-Host 'Building the release configuration...'
    & swift build -c release --force-resolved-versions
    if ($LASTEXITCODE -ne 0) { throw "swift build failed with exit code $LASTEXITCODE" }
    $binary = (& swift build -c release --force-resolved-versions --show-bin-path).Trim()
} finally {
    Pop-Location
}
$exe = Join-Path $binary 'mxu-slides.exe'
if (-not (Test-Path $exe)) { throw "The build did not produce $exe" }

$dist = Join-Path $repo 'dist\MxU Slides'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item $exe (Join-Path $dist 'MxU Slides.exe')
Copy-Item (Join-Path $package 'web') (Join-Path $dist 'web') -Recurse

# The Swift runtime the exe imports, by closure over dumpbin /dependents.
$runtime = Get-ChildItem "$env:LOCALAPPDATA\Programs\Swift\Runtimes\*\usr\bin", "$env:ProgramFiles\Swift\Runtimes\*\usr\bin" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $runtime) { throw 'The Swift runtime folder (Swift\Runtimes\<version>\usr\bin) was not found.' }
$available = @{}
foreach ($dll in Get-ChildItem $runtime.FullName -Filter '*.dll') { $available[$dll.Name.ToLowerInvariant()] = $dll.FullName }
$queue = New-Object System.Collections.Queue
$queue.Enqueue((Join-Path $dist 'MxU Slides.exe'))
$copied = @{}
while ($queue.Count -gt 0) {
    $file = $queue.Dequeue()
    $lines = & dumpbin /nologo /dependents $file 2>$null
    foreach ($line in $lines) {
        $name = $line.Trim()
        if ($name -notmatch '^[\w.\-]+\.dll$') { continue }
        $key = $name.ToLowerInvariant()
        if ($copied.ContainsKey($key) -or -not $available.ContainsKey($key)) { continue }
        $target = Join-Path $dist $name
        Copy-Item $available[$key] $target
        $copied[$key] = $true
        $queue.Enqueue($target)
    }
}
Write-Host "Copied $($copied.Count) runtime DLLs from $($runtime.FullName)"

# Licenses and notices.
Copy-Item (Join-Path $repo 'LICENSE.md') (Join-Path $dist 'LICENSE.md')
$notices = Join-Path $dist 'THIRD-PARTY-NOTICES.md'
$text = @()
$text += '# Third-party notices'
$text += ''
$text += 'MxU Slides for Windows ships with these components:'
$text += ''
$text += '- FlyingFox and FlyingSocks (MIT) — https://github.com/swhitty/FlyingFox'
$text += '- Automerge (MIT) and the Rust crates its native library is built from — https://github.com/automerge'
$text += '- SQLite (public domain) — https://sqlite.org'
$text += '- Microsoft Edge WebView2 SDK loader (Microsoft, see WebView2-LICENSE.txt) — https://developer.microsoft.com/microsoft-edge/webview2/'
$text += '- The Swift runtime and Foundation (Apache 2.0 with Runtime Library Exception) — https://swift.org'
$text += '- Microsoft Visual C++ runtime DLLs, redistributable with the application'
$text += ''
$flyingFox = Get-ChildItem (Join-Path $package '.build\checkouts\FlyingFox\LICENSE*') -ErrorAction SilentlyContinue | Select-Object -First 1
if ($flyingFox) { $text += '## FlyingFox'; $text += ''; $text += (Get-Content $flyingFox.FullName); $text += '' }
$automergeLicense = Get-ChildItem (Join-Path $ffi 'LICENSE*') -ErrorAction SilentlyContinue | Select-Object -First 1
if ($automergeLicense) { $text += '## Automerge'; $text += ''; $text += (Get-Content $automergeLicense.FullName); $text += '' }
Set-Content -Path $notices -Value ($text -join "`r`n") -Encoding utf8
$webView2License = Join-Path $package 'Vendor\WebView2\LICENSE.txt'
if (Test-Path $webView2License) { Copy-Item $webView2License (Join-Path $dist 'WebView2-LICENSE.txt') }

$readme = @"
MxU Slides for Windows $Version
===============================

Run "MxU Slides.exe". The app opens in its own window; closing it quits.

Your library lives in %LOCALAPPDATA%\MxU Slides\Library. The first run adds
the Getting Started service and the starter themes, as the Mac app does.
Start the exe with --demo once to add four public-domain hymns and a sample
service.

Logs go to %LOCALAPPDATA%\MxU Slides\logs\mxu-slides.log. The Local API for
remotes listens on port 6980; its default key is shown in Service Controls >
Outputs.

Needs Windows 10 (1809) or later with the Microsoft Edge WebView2 runtime,
which ships with Windows 11 and Edge. Without it, get it from
https://developer.microsoft.com/microsoft-edge/webview2/ (Evergreen
Bootstrapper).

Command-line options:
  --library <path>  use another library folder
  --demo            add the sample hymns and service if missing
  --browser         open the UI in Microsoft Edge instead of the app window
  --port / --api-port
  --verbose         log every HTTP request
"@
Set-Content -Path (Join-Path $dist 'README.txt') -Value $readme -Encoding utf8

$zip = Join-Path $repo "dist\MxU-Slides-$Version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dist -DestinationPath $zip
Write-Host "Packaged: $dist"
Write-Host "Zip:      $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
