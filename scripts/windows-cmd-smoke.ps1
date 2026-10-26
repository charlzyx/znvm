# Runs real cmd.exe against a temporary package and temporary Node installation.
[CmdletBinding()]
param(
    [string]$Binary = (Join-Path $PSScriptRoot '../zig-out/bin/nvm.exe'),
    [ValidateSet('x64', 'arm64')][string]$ExpectedArch = 'x64',
    [string]$PackageRoot = ''
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Native Windows and PowerShell 7 are required.' }
$Binary = (Resolve-Path $Binary).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('znvm-cmd-' + [guid]::NewGuid())
$originalCodePageText = & "$env:SystemRoot/System32/chcp.com"
if ($LASTEXITCODE -ne 0 -or $originalCodePageText -notmatch '(\d+)\s*$') { throw 'Cannot read original console codepage' }
$originalCodePage = $Matches[1]
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Run-Cmd([string]$Script, [string]$Delayed = 'off', [string]$ExtraPath = '', [string]$FixturePackage = '', [string]$FixtureTemp = '') {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $env:SystemRoot 'System32/cmd.exe'
    $info.UseShellExecute = $false
    foreach ($arg in @('/d', '/e:on', "/v:$Delayed", '/c', $Script)) { $info.ArgumentList.Add($arg) }
    $info.WorkingDirectory = $root
    foreach ($key in @('ZNVM_DIR', 'ZNVM_NPM_PREFIX', 'ZNVM_CURRENT', 'NVM_BIN', 'NVM_INC', 'NPM_CONFIG_PREFIX', 'ZNVM_NODE_MIRROR', 'ZNVM_CMD_ENV_FILE', 'ZNVM_SHELL')) { $info.Environment.Remove($key) | Out-Null }
    $info.Environment['HOME'] = Join-Path $root 'home'
    $info.Environment['USERPROFILE'] = $info.Environment['HOME']
    $info.Environment['NVM_DIR'] = Join-Path $root "node 数据 ' ’ %PATH% !bang! ^ & (node)"
    $info.Environment['TEMP'] = Join-Path $root "temp 数据 ' %PATH% !bang! ^ & (temp)"
    if ($FixtureTemp) { $info.Environment['TEMP'] = $FixtureTemp }
    $info.Environment['ZNVM_CMD_DIAGNOSTICS'] = '1'
    $info.Environment['TMP'] = $info.Environment['TEMP']
    $info.Environment['NVM_NODEJS_ORG_MIRROR'] = 'https://nodejs.org/dist'
    $info.Environment['NVM_LANG'] = 'en'
    $info.Environment['NVM_NONINTERACTIVE'] = '1'
    $info.Environment['PATH'] = "$env:SystemRoot\System32;$PSHOME$ExtraPath"
    $info.Environment['ZNVM_TEST_EXTRA_PATH'] = $ExtraPath
    $info.Environment['ZNVM_TEST_PACKAGE'] = if ($FixturePackage) { $FixturePackage } else { $package }
    $info.Environment['ZNVM_TEST_ROOT'] = $root
    $info.Environment['ZNVM_TEST_ARCH'] = $ExpectedArch
    foreach ($dir in @($info.Environment['HOME'], $info.Environment['NVM_DIR'], $info.Environment['TEMP'])) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $process = [Diagnostics.Process]::Start($info)
    $process.WaitForExit()
    return $process.ExitCode
}
try {
    Assert ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant() -eq $ExpectedArch) 'runner OS architecture mismatch'
    Assert ([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant() -eq $ExpectedArch) 'test host is emulated'
    $pe = [IO.File]::ReadAllBytes($Binary)
    $machine = [BitConverter]::ToUInt16($pe, [BitConverter]::ToInt32($pe, 0x3c) + 4)
    Assert ($machine -eq $(if ($ExpectedArch -eq 'arm64') { 0xaa64 } else { 0x8664 })) 'nvm executable is not native'
    New-Item -ItemType Directory -Path $root | Out-Null
    $package = Join-Path $root "package 数据 ' ’ %PATH% !bang! ^ & (pkg)"
    New-Item -ItemType Directory -Path (Join-Path $package 'bin'), (Join-Path $package 'cmd') | Out-Null
    Copy-Item -LiteralPath $Binary -Destination (Join-Path $package 'bin/nvm.exe')
    $shimRoot = if ($PackageRoot) { Join-Path $PackageRoot 'cmd' } else { Join-Path $PSScriptRoot 'cmd' }
    Copy-Item -LiteralPath (Join-Path $shimRoot 'nvm.cmd'), (Join-Path $shimRoot 'init.cmd') -Destination (Join-Path $package 'cmd')
    # Diagnostic isolation only: the full adversarial scenario below remains
    # mandatory. Probe every case before reporting failure to distinguish batch
    # filename reopening, percent reparsing, and response-file cleanup failures.
    @'
@echo off
call initialize.cmd
if errorlevel 1 exit /b 41
echo znvm-cmd-stage: initialization-returned
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $root 'probe.cmd') -Encoding ascii
    @'
@echo znvm-cmd-stage: fixture-trampoline-entered 1>&2
@"%ZNVM_TEST_PACKAGE%\cmd\init.cmd"
'@ | Set-Content -LiteralPath (Join-Path $root 'initialize.cmd') -Encoding ascii
    $probeResults = @()
    $probesPassed = $true
    $probeCases = @(
        @{ Name = 'ascii-cp437'; Package = 'probe-ascii'; Temp = 'temp-ascii'; CP = '437' },
        @{ Name = 'unicode-package-cp437'; Package = 'probe-数据'; Temp = 'temp-ascii'; CP = '437' },
        @{ Name = 'percent-package-cp437'; Package = 'probe-%PATH%'; Temp = 'temp-ascii'; CP = '437' },
        @{ Name = 'unicode-temp-cp437'; Package = 'probe-ascii'; Temp = 'temp-数据'; CP = '437' },
        @{ Name = 'percent-temp-cp437'; Package = 'probe-ascii'; Temp = 'temp-%PATH%'; CP = '437' },
        @{ Name = 'unicode-package-cp65001'; Package = 'probe-数据'; Temp = 'temp-ascii'; CP = '65001' }
    )
    foreach ($case in $probeCases) {
        $probePackage = Join-Path $root $case.Package
        New-Item -ItemType Directory -Force -Path (Join-Path $probePackage 'bin'), (Join-Path $probePackage 'cmd') | Out-Null
        Copy-Item -LiteralPath $Binary -Destination (Join-Path $probePackage 'bin/nvm.exe') -Force
        Copy-Item -LiteralPath (Join-Path $shimRoot 'nvm.cmd'), (Join-Path $shimRoot 'init.cmd') -Destination (Join-Path $probePackage 'cmd') -Force
        & "$env:SystemRoot/System32/chcp.com" $case.CP | Out-Null
        Write-Host "cmd initialization probe: $($case.Name)"
        $result = Run-Cmd (Join-Path $root 'probe.cmd') 'off' '' $probePackage (Join-Path $root $case.Temp)
        $probeResults += "$($case.Name)=$result"
        if ($result -ne 0) { $probesPassed = $false }
    }
    Write-Host ('cmd initialization probes: ' + ($probeResults -join ', '))
    # Node reads literal inherited environment and argv, never reparses them as code.
    @'
const fs = require('fs');
const assert = require('assert/strict');
const path = require('path');
assert.equal(process.arch, process.env.ZNVM_TEST_ARCH);
assert.equal(process.platform, 'win32');
const root = process.env.ZNVM_TEST_ROOT;
const state = path.join(root, 'state.json');
const mode = process.argv[2];
if (mode === 'save') {
  fs.copyFileSync(process.execPath, path.join(root, 'fixture-node.exe'));
  fs.writeFileSync(state, JSON.stringify({ active: process.env.PATH, bin: process.env.NVM_BIN, baseline: process.env.ZNVM_TEST_BASELINE }));
  assert.equal(process.env.ZNVM_TEST_BASELINE.split(';').filter(p => p.toLowerCase() === path.join(process.env.ZNVM_TEST_PACKAGE, 'cmd').toLowerCase()).length, 1);
  assert.ok(process.env.NVM_BIN.includes("数据 ' ’ %PATH% !bang! ^ & (node)"));
} else if (mode === 'active') {
  const before = JSON.parse(fs.readFileSync(state));
  assert.equal(process.env.PATH, before.active);
  assert.equal(process.env.NVM_BIN, before.bin);
} else if (mode === 'inactive') {
  assert.equal(process.env.PATH, JSON.parse(fs.readFileSync(state)).baseline);
  assert.ok(!process.env.NVM_BIN);
} else if (mode === 'protocol') {
  assert.ok(process.env.PATH.endsWith(process.env.ZNVM_TEST_EXTRA_PATH));
} else if (mode === 'argv') {
  assert.deepEqual(process.argv.slice(3), ['space value', 'amp&value', 'bang!value', 'caret^value', 'paren(value)', 'percent%value']);
} else throw new Error(mode);
assert.ok(!fs.existsSync(path.join(root, 'INJECTED')));
'@ | Set-Content -LiteralPath (Join-Path $root 'verify.js') -Encoding utf8NoBOM
    # init is directly chained through a small trampoline: no CALL expansion of
    # the adversarial package path. CALL targets a constant safe filename only.
    @'
@echo znvm-cmd-stage: fixture-trampoline-entered 1>&2
@"%ZNVM_TEST_PACKAGE%\cmd\init.cmd"
'@ | Set-Content -LiteralPath (Join-Path $root 'initialize.cmd') -Encoding ascii
    @'
@echo off
chcp 437 >nul
chcp > codepage-before.txt
call initialize.cmd
if errorlevel 1 exit /b 10
call initialize.cmd
if errorlevel 1 exit /b 10
set "ZNVM_TEST_BASELINE=%PATH%"
where nvm
call nvm install 22
if errorlevel 1 exit /b 11
node "%ZNVM_TEST_ROOT%\verify.js" save
if errorlevel 1 exit /b 12
call nvm use 22
if errorlevel 1 exit /b 13
node "%ZNVM_TEST_ROOT%\verify.js" active
if errorlevel 1 exit /b 14
call nvm --help
if errorlevel 1 exit /b 15
node "%ZNVM_TEST_ROOT%\verify.js" active
if errorlevel 1 exit /b 16
call nvm use 0.0.0
if not errorlevel 1 exit /b 17
node "%ZNVM_TEST_ROOT%\verify.js" active
if errorlevel 1 exit /b 18
call nvm install 0.0.0
if not errorlevel 1 exit /b 19
node "%ZNVM_TEST_ROOT%\verify.js" active
if errorlevel 1 exit /b 20
call argv.cmd
if errorlevel 1 exit /b 21
call nvm deactivate
if errorlevel 1 exit /b 22
call nvm exec 22 node "%ZNVM_TEST_ROOT%\verify.js" inactive
if errorlevel 1 exit /b 23
call nvm use 22
if errorlevel 1 exit /b 24
call nvm uninstall 22
if errorlevel 1 exit /b 25
if defined NVM_BIN exit /b 26
if not "%PATH%"=="%ZNVM_TEST_BASELINE%" exit /b 27
chcp > codepage-after.txt
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $root 'scenario.cmd') -Encoding ascii
    @'
@"%ZNVM_TEST_PACKAGE%\cmd\nvm.cmd" exec 22 node "%ZNVM_TEST_ROOT%\verify.js" argv "space value" "amp&value" "bang!value" "caret^value" "paren(value)" "percent%%value"
'@ | Set-Content -LiteralPath (Join-Path $root 'argv.cmd') -Encoding ascii
    $code = Run-Cmd (Join-Path $root 'scenario.cmd')
    Assert ($code -eq 0) "cmd install/use/exec/deactivate/uninstall failed at code $code"
    Assert $probesPassed ('isolated initialization failed: ' + ($probeResults -join ', '))
    Assert ((Get-Content -Raw -LiteralPath (Join-Path $root 'codepage-before.txt')) -eq (Get-Content -Raw -LiteralPath (Join-Path $root 'codepage-after.txt'))) 'cmd did not restore original codepage'
    # Values inherited through CreateProcess are data, not cmd source. Exercise
    # quotes and operators that Windows filenames cannot contain as PATH data.
    @'
@echo off
chcp 437 >nul
chcp > protocol-before.txt
call initialize.cmd
if errorlevel 1 exit /b 31
"%ZNVM_TEST_ROOT%\fixture-node.exe" "%ZNVM_TEST_ROOT%\verify.js" protocol
if errorlevel 1 exit /b 32
chcp > protocol-after.txt
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $root 'protocol.cmd') -Encoding ascii
    $hostilePath = ';literal" & echo INJECTED>INJECTED & rem "|<>^()%PATH%!bang! 数据'
    $code = Run-Cmd (Join-Path $root 'protocol.cmd') 'off' $hostilePath
    Assert ($code -eq 0) "cmd environment protocol failed (code $code)"
    Assert ((Get-Content -Raw -LiteralPath (Join-Path $root 'protocol-before.txt')) -eq (Get-Content -Raw -LiteralPath (Join-Path $root 'protocol-after.txt'))) 'protocol did not restore codepage'
    # The refusal must happen before paths containing ! can be expanded.
    @'
@"%ZNVM_TEST_PACKAGE%\cmd\nvm.cmd" use 22
'@ | Set-Content -LiteralPath (Join-Path $root 'delayed.cmd') -Encoding ascii
    # Invoke an ASCII-path copy for the ON guard, since caller expansion itself
    # would corrupt ! in the adversarial package path before entering the shim.
    Copy-Item -LiteralPath (Join-Path $shimRoot 'nvm.cmd') -Destination (Join-Path $root 'delayed.cmd') -Force
    $code = Run-Cmd (Join-Path $root 'delayed.cmd') 'on'
    Assert ($code -eq 55) "delayed expansion was not rejected (code $code)"
    Assert (-not (Test-Path -LiteralPath (Join-Path $root 'INJECTED'))) 'cmd executed fixture data'
    Write-Host "PASS: native cmd install/use/exec/deactivate/uninstall and delayed-expansion refusal ($ExpectedArch)"
} finally {
    & "$env:SystemRoot/System32/chcp.com" $originalCodePage | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot restore smoke-test console codepage' }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
