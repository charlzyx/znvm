# Native Windows/PowerShell integration test. Never writes real profile or PATH.
[CmdletBinding()]
param([string]$Binary = (Join-Path $PSScriptRoot '../zig-out/bin/znvm.exe'))
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'This test requires native Windows and PowerShell 7.' }
$Binary = (Resolve-Path $Binary).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ("znvm smoke ' " + [guid]::NewGuid())
$keys = @('HOME', 'USERPROFILE', 'NVM_DIR', 'ZNVM_DIR', 'ZNVM_NPM_PREFIX', 'ZNVM_CURRENT', 'NVM_BIN', 'NVM_INC', 'NPM_CONFIG_PREFIX', 'NVM_NODEJS_ORG_MIRROR', 'ZNVM_NODE_MIRROR', 'NVM_LANG', 'NVM_NONINTERACTIVE', 'PATH')
$saved = @{}
foreach ($key in $keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Assert-Exit([string]$operation) { Assert ($global:LASTEXITCODE -eq 0) "$operation exited $global:LASTEXITCODE" }
try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $env:HOME = Join-Path $root 'home'
    $env:USERPROFILE = $env:HOME
    $env:NVM_DIR = Join-Path $root "node data ' quoted"
    New-Item -ItemType Directory -Path $env:HOME, $env:NVM_DIR | Out-Null
    foreach ($key in @('ZNVM_DIR', 'ZNVM_NPM_PREFIX', 'ZNVM_CURRENT', 'NVM_BIN', 'NVM_INC', 'NPM_CONFIG_PREFIX', 'ZNVM_NODE_MIRROR')) {
        [Environment]::SetEnvironmentVariable($key, $null, 'Process')
    }
    $env:NVM_NODEJS_ORG_MIRROR = 'https://nodejs.org/dist'
    $env:NVM_LANG = 'en'
    $env:NVM_NONINTERACTIVE = '1'
    # Exclude preinstalled Node and npm while keeping Windows curl.exe/tar.exe.
    $env:PATH = "$env:SystemRoot\System32;$PSHOME"
    $initialPath = $env:PATH

    # Use a copied executable in a quoted path to exercise env script quoting.
    $exe = Join-Path $root "nvm binary ' test.exe"
    Copy-Item $Binary $exe
    $setup = & $exe env
    Assert-Exit 'env'
    Invoke-Expression ($setup -join "`n")
    Assert ($global:__znvm_exe -eq $exe) 'env lost executable path quoting'
    $again = & $exe env
    Assert-Exit 'second env'
    Invoke-Expression ($again -join "`n")
    Assert ($env:PATH -eq $initialPath) 'env duplicated or changed PATH'

    $empty = nvm ls --json | ConvertFrom-Json
    Assert-Exit 'empty ls'
    Assert ($empty.versions.Count -eq 0) 'isolated root unexpectedly contains Node'
    nvm install 22
    Assert-Exit 'install 22'
    $version = (node.exe --version).Trim()
    Assert-Exit 'node --version'
    Assert ($version -match '^v22\.') "unexpected version: $version"
    $activePath = $env:PATH
    nvm use 22
    Assert-Exit 'use 22'
    Assert ($env:PATH -eq $activePath) 'repeated use duplicated PATH'
    Assert ((nvm current).Trim() -eq $version) 'current mismatch'
    Assert-Exit 'current'
    $which = nvm which 22 --json | ConvertFrom-Json
    Assert-Exit 'which'
    Assert ($which.version -eq $version) 'which version mismatch'
    Assert ($which.path -like '*node.exe') 'which does not identify node.exe'
    Assert (Test-Path -LiteralPath $which.path) 'which path does not exist'
    $listing = nvm ls --json | ConvertFrom-Json
    Assert-Exit 'ls'
    Assert ($listing.current -eq $version) 'ls current mismatch'
    Assert ($listing.versions.Count -eq 1) 'ls install count mismatch'
    Assert ((nvm run 22 --version).Trim() -eq $version) 'run mismatch'
    Assert-Exit 'run'
    Assert ((nvm exec 22 node.exe --version).Trim() -eq $version) 'exec mismatch'
    Assert-Exit 'exec'
    $npmVersion = (nvm exec 22 npm --version).Trim()
    Assert-Exit 'exec npm'
    Assert ($npmVersion -match '^\d+\.') 'npm version missing'
    $npxVersion = (nvm exec 22 npx --version).Trim()
    Assert-Exit 'exec npx'
    Assert ($npxVersion -eq $npmVersion) 'npx version mismatch'
    nvm alias work 22
    Assert-Exit 'alias'
    nvm use work
    Assert-Exit 'use alias'
    Assert ((nvm current).Trim() -eq $version) 'alias selection mismatch'

    # A failing switch must not apply partial output or change the caller's PATH.
    $beforeFailure = $env:PATH
    nvm use 999.999.999 2>$null
    Assert ($global:LASTEXITCODE -ne 0) 'missing version unexpectedly succeeded'
    Assert ($env:PATH -eq $beforeFailure) 'failed use changed PATH'
    nvm exec 22 node.exe -e 'process.exit(7)'
    Assert ($global:LASTEXITCODE -eq 7) 'exec did not preserve child exit code'

    $nrm = Join-Path $root 'nrm.exe'
    Copy-Item $Binary $nrm
    $registries = & $nrm ls --json | ConvertFrom-Json
    Assert-Exit 'nrm ls'
    Assert ($null -ne $registries) 'nrm did not emit JSON'

    nvm deactivate
    Assert-Exit 'deactivate'
    Assert ($env:PATH -eq $initialPath) 'deactivate failed to restore PATH'
    Assert ([string]::IsNullOrEmpty($env:NVM_BIN)) 'deactivate left NVM_BIN'
    nvm uninstall 22
    Assert-Exit 'uninstall'
    $final = nvm ls --json | ConvertFrom-Json
    Assert-Exit 'final ls'
    Assert ($final.versions.Count -eq 0) 'uninstall left installed version'
    Write-Host "PASS: native Windows install/use/current/which/list/run/exec/alias/deactivate/uninstall ($version)"
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
    Remove-Item Function:\nvm -ErrorAction SilentlyContinue
    Remove-Variable __znvm_exe -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
