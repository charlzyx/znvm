# Isolated cmd parser/call-stack experiment: no download, Zig, or user config.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Native Windows required' }
$root = Join-Path ([IO.Path]::GetTempPath()) ('znvm-chain-' + [guid]::NewGuid())
$cases = @(
    @{ Name = 'direct-no-delete'; Mode = 'direct'; Delete = $false },
    @{ Name = 'direct-delete'; Mode = 'direct'; Delete = $true },
    @{ Name = 'for-no-delete'; Mode = 'for'; Delete = $false },
    @{ Name = 'for-delete'; Mode = 'for'; Delete = $true },
    @{ Name = 'for-oneline-no-delete'; Mode = 'for-oneline'; Delete = $false },
    @{ Name = 'for-oneline-delete'; Mode = 'for-oneline'; Delete = $true },
    @{ Name = 'inline-no-delete'; Mode = 'inline'; Delete = $false },
    @{ Name = 'inline-delete'; Mode = 'inline'; Delete = $true },
    @{ Name = 'persistent-cleanup-success'; Mode = 'inline'; Cleanup = $true; Status = 0 },
    @{ Name = 'persistent-cleanup-failure'; Mode = 'inline'; Cleanup = $true; Status = 1 }
)
$results = @()
try {
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($name in @('ascii', "数据 %PATH% ! ^ & (fixture)")) {
        foreach ($case in $cases) {
            $dir = Join-Path $root ($name + '-' + $case.Name)
            New-Item -ItemType Directory -Path $dir | Out-Null
            $tail = if ($case.Delete) { '@del "%~f0" >nul 2>&1 & exit /b 0' } else { '@exit /b 0' }
            if ($case.Cleanup) { $tail = '@"%~1" "%~f0" ' + $case.Status }
            @'
@echo chain-stage: cleanup-entered
@del "%~1" >nul 2>&1
@if exist "%~1" exit /b 57
@if "%~2"=="0" exit /b 0
@exit /b 1
'@ | Set-Content -LiteralPath (Join-Path $dir 'finish.cmd') -Encoding ascii
            $payload = "@echo chain-stage: payload-entered`r`n@set ZNVM_CHAIN_RESULT=applied`r`n@set PATH=C:\znvm-chain-marker`r`n$tail`r`n"
            [IO.File]::WriteAllText((Join-Path $dir 'payload.cmd'), $payload, [Text.Encoding]::ASCII)
            $chain = switch ($case.Mode) {
                direct { '@"%ZNVM_CHAIN_TARGET%"' }
                'for-oneline' { '@for %%F in ("%ZNVM_CHAIN_TARGET%") do @endlocal & "%%~fF"' }
                inline { '@endlocal & "%ZNVM_CHAIN_TARGET%" "%ZNVM_CHAIN_FINISH%"' }
                for { "@for %%F in (`"%ZNVM_CHAIN_TARGET%`") do (`r`n@endlocal`r`n@`"%%~fF`"`r`n)" }
            }
            $prefix = if ($case.Mode -eq 'direct') { '' } else { "@setlocal DisableDelayedExpansion`r`n" }
            [IO.File]::WriteAllText((Join-Path $root 'wrapper.cmd'), "$prefix$chain`r`n@exit /b 77`r`n", [Text.Encoding]::ASCII)
            @'
@echo off
set ZNVM_CHAIN_RESULT=
call wrapper.cmd
set ZNVM_CHAIN_STATUS=%errorlevel%
echo chain-stage: caller-resumed status=%ZNVM_CHAIN_STATUS%
if not "%ZNVM_CHAIN_STATUS%"=="%ZNVM_CHAIN_EXPECTED%" exit /b 81
if not "%ZNVM_CHAIN_RESULT%"=="applied" exit /b 82
if not "%PATH%"=="C:\znvm-chain-marker" exit /b 83
if exist INJECTED exit /b 84
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $root 'caller.cmd') -Encoding ascii
            $info = [Diagnostics.ProcessStartInfo]::new()
            $info.FileName = Join-Path $env:SystemRoot 'System32/cmd.exe'
            $info.UseShellExecute = $false
            $info.WorkingDirectory = $root
            foreach ($arg in @('/d', '/e:on', '/v:off', '/c', 'caller.cmd')) { $info.ArgumentList.Add($arg) }
            $info.Environment['ZNVM_CHAIN_TARGET'] = Join-Path $dir 'payload.cmd'
            $info.Environment['ZNVM_CHAIN_FINISH'] = Join-Path $dir 'finish.cmd'
            $info.Environment['ZNVM_CHAIN_EXPECTED'] = if ($case.Cleanup) { [string]$case.Status } else { '0' }
            $info.Environment.Remove('ERRORLEVEL') | Out-Null
            Write-Host "chain diagnostic: $name / $($case.Name)"
            $process = [Diagnostics.Process]::Start($info)
            $process.WaitForExit()
            $results += [pscustomobject]@{ PathKind = $name; Case = $case.Name; ExitCode = $process.ExitCode; PayloadDeleted = -not (Test-Path -LiteralPath (Join-Path $dir 'payload.cmd')) }
        }
    }
    $results | Format-Table -AutoSize | Out-Host
    # This is causal evidence, not a support check: preserve every result even
    # if some alternatives fail. windows-cmd-smoke.ps1 remains the release gate.
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
