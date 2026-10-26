# Emitted by `znvm.exe env`. Only the current process environment is changed.
# __znvm_exe and NVM_DIR use ASCII-only UTF-8 Base64 expressions in the setup.
function global:nvm {
    $previousShell = [Environment]::GetEnvironmentVariable('ZNVM_SHELL', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('ZNVM_SHELL', 'powershell', 'Process')
        # Preserve native exit status even when the caller opts into native errors.
        $PSNativeCommandUseErrorActionPreference = $false
        # Match the native global-flag pass, including flags before the command.
        # Help/skill/JSON output is data, never executable environment code.
        $command = ''
        $locked = $false
        $printOnly = $false
        foreach ($argument in $args) {
            $token = [string]$argument
            if (-not $locked) {
                if ($token -ceq '--') { $locked = $true }
                if ($token -cin @('--llm', '--json', '--help', '-h')) { $printOnly = $true }
                if ($token -cin @('--yes', '--json', '--llm')) { continue }
            }
            if (-not $command) { $command = $token }
        }
        if (-not $printOnly -and $command -cin @('use', 'install', 'uninstall', 'rm', 'deactivate')) {
            $result = & $global:__znvm_exe @args
            $code = $LASTEXITCODE
            if ($code -eq 0) {
                # Native commands can relay package-manager stdout. Treat it as data:
                # accept only the fixed, allowlisted environment protocol, never code.
                $assign = '^\$env:(PATH|ZNVM_CURRENT|NVM_BIN|NVM_INC|NPM_CONFIG_PREFIX)=\(\[Text\.Encoding\]::UTF8\.GetString\(\[Convert\]::FromBase64String\(''([A-Za-z0-9+/]*={0,2})''\)\)\)$'
                $remove = '^Remove-Item Env:(ZNVM_CURRENT|NVM_BIN|NVM_INC|NPM_CONFIG_PREFIX) -ErrorAction SilentlyContinue$'
                foreach ($line in $result) {
                    if ($line -cmatch $assign) {
                        $key = $Matches[1]
                        try {
                            $value = [Text.UTF8Encoding]::new($false, $true).GetString([Convert]::FromBase64String($Matches[2]))
                        } catch {
                            Write-Output $line
                            continue
                        }
                        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
                    } elseif ($line -cmatch $remove) {
                        Remove-Item -LiteralPath "Env:$($Matches[1])" -ErrorAction SilentlyContinue
                    } else {
                        Write-Output $line
                    }
                }
            } elseif ($result) {
                [Console]::Error.WriteLine(($result -join "`n"))
            }
            $global:LASTEXITCODE = $code
            return
        }
        & $global:__znvm_exe @args
        $global:LASTEXITCODE = $LASTEXITCODE
    } finally {
        if ($null -eq $previousShell) {
            Remove-Item -LiteralPath Env:ZNVM_SHELL -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable('ZNVM_SHELL', $previousShell, 'Process')
        }
    }
}
