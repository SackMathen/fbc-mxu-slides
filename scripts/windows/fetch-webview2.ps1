# Downloads the Microsoft Edge WebView2 SDK (headers and the static loader) that
# the native window host in apps/windows compiles against, into
# apps/windows/Vendor/WebView2 (not checked in; run-app.ps1 calls this when
# the folder is missing).
#
# The SDK's license (BSD-style, see Vendor/WebView2/LICENSE.txt) allows
# redistributing the loader with the app. The WebView2 runtime itself ships
# with Windows 11 and Edge; https://developer.microsoft.com/microsoft-edge/webview2/
# has the installer for machines without it.
param(
    [string]$Version = '1.0.4258.31'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$vendor = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\apps\windows')) 'Vendor\WebView2'
if (Test-Path (Join-Path $vendor "include\WebView2.h")) {
    if ((Get-Content (Join-Path $vendor 'VERSION') -ErrorAction SilentlyContinue) -eq $Version) {
        Write-Host "WebView2 SDK $Version already in $vendor"
        return
    }
}

# A .nupkg is a zip; Expand-Archive only accepts the .zip extension.
$package = Join-Path $env:TEMP "microsoft.web.webview2.$Version.zip"
$extracted = Join-Path $env:TEMP "microsoft.web.webview2.$Version"
Write-Host "Downloading WebView2 SDK $Version..."
Invoke-WebRequest -Uri "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$Version/microsoft.web.webview2.$Version.nupkg" -OutFile $package -UseBasicParsing
if (Test-Path $extracted) { Remove-Item $extracted -Recurse -Force }
Expand-Archive -Path $package -DestinationPath $extracted -Force

New-Item -ItemType Directory -Force (Join-Path $vendor 'include') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $vendor 'x64') | Out-Null
Copy-Item (Join-Path $extracted 'build\native\include\*.h') (Join-Path $vendor 'include') -Force
Copy-Item (Join-Path $extracted 'build\native\x64\WebView2LoaderStatic.lib') (Join-Path $vendor 'x64') -Force
Copy-Item (Join-Path $extracted 'build\native\x64\WebView2Loader.dll') (Join-Path $vendor 'x64') -Force
Copy-Item (Join-Path $extracted 'build\native\x64\WebView2Loader.dll.lib') (Join-Path $vendor 'x64') -Force
$license = Get-ChildItem $extracted -Filter 'LICENSE*' -Recurse | Select-Object -First 1
if ($license) { Copy-Item $license.FullName (Join-Path $vendor 'LICENSE.txt') -Force }
Set-Content -Path (Join-Path $vendor 'VERSION') -Value $Version -Encoding ascii
Remove-Item $package -Force
Remove-Item $extracted -Recurse -Force
Write-Host "WebView2 SDK $Version in $vendor"
