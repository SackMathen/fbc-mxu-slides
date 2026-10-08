# Prepares the current PowerShell session for building the Swift packages on Windows.
#
#   . .\scripts\windows\dev-env.ps1
#
# Swift on Windows compiles and links through the Visual Studio toolset, so a
# plain shell needs two things before `swift build` works:
#
# 1. The toolchain's own variables (PATH entries, SDKROOT, ...) which the
#    installer writes to the registry; a shell opened before the install does
#    not have them yet.
# 2. The Visual Studio x64 developer environment (link.exe, INCLUDE, LIB),
#    which is what Developer PowerShell does behind the scenes.
#
# Prerequisites (all available through winget):
#   winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
#   winget install Swift.Toolchain
#   winget install Rustlang.Rustup        # for the Automerge FFI library, see build-automerge-ffi.ps1
#   winget install OpenJS.NodeJS.LTS      # for the schema codegen and drive scripts

$ErrorActionPreference = 'Stop'

function Import-RegistryEnvironment {
    foreach ($scope in 'Machine', 'User') {
        $variables = [Environment]::GetEnvironmentVariables($scope)
        foreach ($name in $variables.Keys) {
            if ($name -ieq 'Path') { continue }
            if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
                [Environment]::SetEnvironmentVariable($name, $variables[$name], 'Process')
            }
        }
    }
    $entries = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        $env:Path
    ) -join ';'
    $env:Path = ($entries.Split(';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Import-VisualStudioEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) {
        throw 'Visual Studio Build Tools were not found. Install Microsoft.VisualStudio.2022.BuildTools with the C++ (VCTools) workload.'
    }
    $installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $installation) {
        throw 'No Visual Studio installation with the C++ build tools (Microsoft.VisualStudio.Component.VC.Tools.x86.x64) was found.'
    }
    $devCmd = Join-Path $installation 'Common7\Tools\VsDevCmd.bat'
    # VsDevCmd shells out to vswhere.exe by name, so its directory must be on PATH.
    $env:Path = (Split-Path $vswhere) + ';' + $env:Path
    $lines = cmd /c "`"$devCmd`" -arch=x64 -host_arch=x64 -no_logo && set"
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
}

Import-RegistryEnvironment
Import-VisualStudioEnvironment

$swift = Get-Command swift -ErrorAction SilentlyContinue
if (-not $swift) {
    throw 'swift was not found on PATH. Install it with: winget install Swift.Toolchain'
}
if (-not (Get-Command link -ErrorAction SilentlyContinue)) {
    throw 'link.exe was not found after importing the Visual Studio environment.'
}

$script:MxUWindowsEnvReady = $true
Write-Host "Windows Swift environment ready: $($swift.Source)"
