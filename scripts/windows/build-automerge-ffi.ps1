# Builds the Automerge Rust FFI (the native half of the vendored automerge-swift
# package) as a Windows static library and places it where
# apps/mac/Packages/automerge-swift/Package.swift expects it:
#
#   apps/mac/Packages/automerge-swift/Libraries/windows-x86_64/uniffi_automerge.lib
#
#   .\scripts\windows\build-automerge-ffi.ps1 [-Configuration release|debug]
#
# Requires Rust (winget install Rustlang.Rustup) and the Visual Studio C++ build
# tools. The crate is pinned by its Cargo.lock; the Swift bindings in
# AutomergeUniffi/automerge.swift were generated from this exact crate
# (uniffi 0.28.2), so the two must be updated together.
param(
    [ValidateSet('release', 'debug')]
    [string]$Configuration = 'release'
)

$ErrorActionPreference = 'Stop'

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$package = Join-Path $repo 'apps\mac\Packages\automerge-swift'
$manifest = Join-Path $package 'rust\Cargo.toml'
$target = 'x86_64-pc-windows-msvc'

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'cargo was not found on PATH. Install Rust with: winget install Rustlang.Rustup'
}

$cargoArguments = @('build', '--locked', '--target', $target, '--manifest-path', $manifest)
if ($Configuration -eq 'release') { $cargoArguments += '--release' }

& cargo @cargoArguments
if ($LASTEXITCODE -ne 0) {
    throw "cargo build failed with exit code $LASTEXITCODE"
}

$built = Join-Path $package "rust\target\$target\$Configuration\uniffi_automerge.lib"
$destination = Join-Path $package 'Libraries\windows-x86_64'
New-Item -ItemType Directory -Force $destination | Out-Null
Copy-Item $built (Join-Path $destination 'uniffi_automerge.lib') -Force

Write-Host "Automerge FFI library: $(Join-Path $destination 'uniffi_automerge.lib')"
