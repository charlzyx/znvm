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
    $env:NVM_DIR = Join-Path $root "node 数据 ' quoted ’ smart"
    New-Item -ItemType Directory -Path $env:HOME, $env:NVM_DIR | Out-Null
    foreach ($key in @('ZNVM_DIR', 'ZNVM_NPM_PREFIX', 'ZNVM_CURRENT', 'NVM_BIN', 'NVM_INC', 'NPM_CONFIG_PREFIX', 'ZNVM_NODE_MIRROR')) {
        Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue
    }
    $env:NVM_NODEJS_ORG_MIRROR = 'https://nodejs.org/dist'
    $env:NVM_LANG = 'en'
    $env:NVM_NONINTERACTIVE = '1'
    # Exclude preinstalled Node and npm while keeping Windows curl.exe.
    $env:PATH = "$env:SystemRoot\System32;$PSHOME"
    $initialPath = $env:PATH
    # Verify native prerequisite discovery independently of znvm process spawning.
    & curl.exe --version
    Assert-Exit 'native curl prerequisite'


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

    # Package-manager output must never be interpreted as PowerShell code.
    function global:__znvm_smoke_output {
        '$global:__znvm_smoke_injected = $true'
        '$env:UNRELATED_VARIABLE=([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(''eA=='')))'
        $global:LASTEXITCODE = 0
    }
    $realExe = $global:__znvm_exe
    try {
        $global:__znvm_exe = '__znvm_smoke_output'
        $plainOutput = nvm install 22
        Assert ($plainOutput.Count -eq 2) 'unknown output was not preserved as text'
        Assert (-not (Get-Variable __znvm_smoke_injected -Scope Global -ErrorAction SilentlyContinue)) 'stdout was evaluated'
        Assert ($null -eq $env:UNRELATED_VARIABLE) 'unallowlisted environment assignment was applied'
    } finally {
        $global:__znvm_exe = $realExe
        Remove-Item Function:\__znvm_smoke_output
    }

    # Successful documentation commands must print text, not evaluate it.
    $helpText = nvm use --help
    Assert-Exit 'use --help'
    Assert (($helpText -join "`n").Length -gt 0) 'missing help output'
    $skillText = nvm install --llm
    Assert-Exit 'install --llm'
    Assert (($skillText -join "`n") -match '# znvm') 'missing skill output'
    Assert ($env:PATH -eq $initialPath) 'documentation command changed PATH'
    $empty = nvm ls --json | ConvertFrom-Json
    Assert-Exit 'empty ls'
    Assert ($empty.versions.Count -eq 0) 'isolated root unexpectedly contains Node'
    nvm debug
    Assert-Exit 'debug configuration'
    nvm install 22
    Assert-Exit 'install 22'
    $version = (node.exe --version).Trim()
    Assert-Exit 'node --version'
    Assert ($version -match '^v22\.') "unexpected version: $version"
    $activePath = $env:PATH
    nvm --yes use 22
    Assert-Exit '--yes use 22'
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
    $payload = @('space separated', 'double "quote"', 'amp & dollar $ ; backtick `', ('smart ' + [char]0x2019 + ' 中文'), '')
    $roundtrip = nvm exec 22 node.exe -e 'console.log(JSON.stringify(process.argv.slice(1)))' -- @payload | ConvertFrom-Json
    Assert-Exit 'exec argument roundtrip'
    Assert ($roundtrip.Count -eq $payload.Count) 'exec changed argument count'
    for ($i = 0; $i -lt $payload.Count; $i++) { Assert ($roundtrip[$i] -ceq $payload[$i]) "exec changed argument $i" }
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
    nvm uninstall system 2>$null
    Assert ($global:LASTEXITCODE -ne 0) 'uninstall system unexpectedly succeeded'
    Assert ($env:PATH -eq $beforeFailure) 'failed uninstall changed PATH'
    # Source builds fail before network requests or archive writes.
    nvm install -s 22 2>$null
    Assert ($global:LASTEXITCODE -ne 0) 'unsupported source install unexpectedly succeeded'
    Assert ($env:PATH -eq $beforeFailure) 'failed install changed PATH'
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
    Assert ((nvm exec 22 node --version).Trim() -eq $version) 'deactivated exec node mismatch'
    Assert-Exit 'deactivated exec node'
    Assert ((nvm exec 22 node.exe --version).Trim() -eq $version) 'deactivated exec node.exe mismatch'
    Assert-Exit 'deactivated exec node.exe'
    Assert ($env:PATH -eq $initialPath) 'exec changed deactivated caller PATH'
    Assert ([string]::IsNullOrEmpty($env:NVM_BIN)) 'exec activated the caller'
    nvm --yes use 22
    Assert-Exit 'leading flag use after deactivate'
    Assert ((nvm current).Trim() -eq $version) 'leading flag failed to apply switching'
    # Removing the active version follows Unix behavior: remove then deactivate.
    nvm uninstall 22
    Assert-Exit 'uninstall'
    Assert ($env:PATH -eq $initialPath) 'active uninstall failed to restore PATH'
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
