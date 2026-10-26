# Emitted by `znvm.exe env`. Only the current process environment is changed.
# __znvm_exe and NVM_DIR are single-quoted by the native binary before this text.
function global:nvm {
    $command = if ($args.Count) { [string]$args[0] } else { '' }
    if ($command -in @('use', 'install', 'uninstall', 'rm', 'deactivate')) {
        $result = & $global:__znvm_exe @args
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            if ($result) { Invoke-Expression ($result -join "`n") }
        } elseif ($result) {
            [Console]::Error.WriteLine(($result -join "`n"))
        }
        $global:LASTEXITCODE = $code
        return
    }
    & $global:__znvm_exe @args
    $global:LASTEXITCODE = $LASTEXITCODE
}
