# Native Windows nvm.exe integration through the installed Git Bash distribution.
[CmdletBinding()]
param(
    [string]$Binary = (Join-Path $PSScriptRoot '../zig-out/bin/nvm.exe'),
    [ValidateSet('x64', 'arm64')][string]$ExpectedArch = 'x64'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'This test requires Windows and Git Bash.' }
$Binary = (Resolve-Path $Binary).Path
function Read-Machine([string]$Path) {
    $pe = [IO.File]::ReadAllBytes($Path)
    return [BitConverter]::ToUInt16($pe, [BitConverter]::ToInt32($pe, 0x3c) + 4)
}
$osArch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
if ($osArch -ne $ExpectedArch) { throw "Expected native $ExpectedArch OS, found $osArch" }
$expectedMachine = if ($ExpectedArch -eq 'arm64') { 0xaa64 } else { 0x8664 }
if ((Read-Machine $Binary) -ne $expectedMachine) { throw 'nvm.exe architecture does not match the native OS' }
$candidates = @("$env:ProgramFiles/Git/bin/bash.exe", "${env:ProgramFiles(x86)}/Git/bin/bash.exe")
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($git) { $candidates = @((Join-Path (Split-Path (Split-Path $git.Source)) 'bin/bash.exe')) + $candidates }
$bash = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bash) { throw 'Git Bash is not installed on this runner; native Git Bash verification was not run.' }
# Git's bin/bash.exe can be a native launcher for a different-architecture
# usr/bin/bash.exe. Do not mistake launcher architecture for runtime evidence.
$launcherMachine = Read-Machine $bash
$runtimePathOutput = & $bash --noprofile --norc -c 'cygpath --windows /usr/bin/bash.exe'
if ($LASTEXITCODE -ne 0 -or -not $runtimePathOutput) { throw 'Could not identify the Git Bash runtime executable.' }
$runtimeBash = ($runtimePathOutput | Select-Object -Last 1).Trim()
if (-not (Test-Path -LiteralPath $runtimeBash)) { throw "Git Bash runtime executable does not exist: $runtimeBash" }
$runtimeMachine = Read-Machine $runtimeBash
$runtimeMode = if ($runtimeMachine -eq $expectedMachine) {
    'runtime executable matches native OS architecture'
} elseif ($ExpectedArch -eq 'arm64' -and $runtimeMachine -eq 0x8664) {
    'x64 Bash runtime under Windows ARM64 emulation; NOT native ARM64 Bash'
} else {
    'runtime executable differs from OS architecture; native Bash execution not established'
}
Write-Host "Git Bash verification: OS=$osArch nvm PE=$('{0:x}' -f $expectedMachine)"
Write-Host "Git Bash launcher: PE=$('{0:x}' -f $launcherMachine), path=$bash"
Write-Host "Git Bash runtime: PE=$('{0:x}' -f $runtimeMachine), path=$runtimeBash ($runtimeMode)"
$root = Join-Path ([IO.Path]::GetTempPath()) ("znvm Git 数据 ' ’ % ! & (test) " + [guid]::NewGuid())
$keys = @('NVM_TEST_BINARY', 'NVM_TEST_HOME', 'NVM_TEST_ROOT', 'NVM_TEST_ARCH', 'NVM_TEST_SYSTEMROOT')
$saved = @{}
foreach ($key in $keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $package = Join-Path $root "package 数据 ' ’ % ! & (bin)"
    New-Item -ItemType Directory -Path $package | Out-Null
    $exe = Join-Path $package 'nvm.exe'
    Copy-Item $Binary $exe
    $env:NVM_TEST_BINARY = $exe
    $env:NVM_TEST_HOME = Join-Path $root 'home'
    $env:NVM_TEST_ROOT = Join-Path $root "versions 数据 ' ’ % ! & (root)"
    $env:NVM_TEST_ARCH = $ExpectedArch
    $env:NVM_TEST_SYSTEMROOT = $env:SystemRoot
    $script = Join-Path $root 'git-bash-smoke.sh'
    $body = @'
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
printf 'Git Bash runtime: '; uname -sm
exe=$(cygpath --unix "$NVM_TEST_BINARY")
export HOME=$(cygpath --unix "$NVM_TEST_HOME")
export USERPROFILE=$NVM_TEST_HOME NVM_DIR=$NVM_TEST_ROOT
unset ZNVM_DIR ZNVM_NPM_PREFIX ZNVM_CURRENT NVM_BIN NVM_INC NPM_CONFIG_PREFIX ZNVM_NODE_MIRROR
export NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist NVM_LANG=en NVM_NONINTERACTIVE=1
mkdir -p "$HOME" "$(cygpath --unix "$NVM_DIR")"
export PATH="/usr/bin:/bin:$(cygpath --unix "$NVM_TEST_SYSTEMROOT")/System32"
# Normalize once; the native executable receives a Windows PATH and emits it back.
initial_path=$(cygpath --path --unix "$(cygpath --path --windows "$PATH")")
export PATH=$initial_path
setup=$(MSYS2_ARG_CONV_EXCL='*' "$exe" env --shell bash)
eval "$setup"
[[ -n $__znvm_exe && -f $__znvm_exe ]] || fail 'initializer lost executable quoting'
eval "$setup"
[[ $PATH == "$initial_path" ]] || fail 'initializer changed PATH'

# The mutation protocol must print arbitrary stdout, never execute it.
real_exe=$__znvm_exe
mock="$HOME/mock-output"
cat > "$mock" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' 'touch "$HOME/injected"' 'ZNVM_ENV|NOT_ALLOWED|eA=='
MOCK
chmod +x "$mock"
__znvm_exe=$mock
nvm install 22 > "$HOME/mock-result"
plain=$(cat "$HOME/mock-result")
[[ $plain == *'touch '* && $plain == *'NOT_ALLOWED'* ]] || fail 'unknown output discarded'
[[ ! -e $HOME/injected && ! ${NOT_ALLOWED+x} ]] || fail 'unknown stdout evaluated'
__znvm_exe=$real_exe

help=$(nvm use --help)
[[ -n $help ]] || fail 'help was not printed'
skill=$(nvm install --llm)
[[ $skill == *'# znvm'* ]] || fail 'skill was not printed'
nvm --yes install 22
version=$(node.exe --version)
[[ $version == v22.* ]] || fail 'wrong installed version'
[[ $(node.exe -p process.arch) == "$NVM_TEST_ARCH" ]] || fail 'Node architecture is not native'
[[ $(nvm current) == "$version" ]] || fail 'current mismatch'
active_path=$PATH
nvm --yes use 22
[[ $PATH == "$active_path" ]] || fail 'repeated use duplicated PATH'
nvm ls --json | node.exe -e 'let s="";process.stdin.on("data",x=>s+=x).on("end",()=>{let j=JSON.parse(s);if(j.versions.length!==1||!j.current)process.exit(1)})'
[[ $(nvm run 22 --version) == "$version" ]] || fail 'run mismatch'
[[ $(nvm exec 22 npm --version) =~ ^[0-9]+\. ]] || fail 'npm exec failed'
# Only a real first Node script operand is converted from POSIX to Windows.
# Trailing script arguments and -e/-p source remain byte-for-byte literal.
fixture="$HOME/script 数据 ' ’ % ! & (case).js"
cat > "$fixture" <<'JS'
if (process.argv.length !== 3 || process.argv[2] !== "/literal/not/a/file") {
    console.error(process.argv);
    process.exit(1);
}
console.log("fixture-ok");
JS
[[ $(nvm run 22 "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'run POSIX script failed'
[[ $(nvm exec 22 node "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'exec node POSIX script failed'
[[ $(nvm exec 22 node.exe "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'exec node.exe POSIX script failed'
[[ $(nvm run 22 -- "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'run -- POSIX script failed'
[[ $(nvm exec 22 node.exe -- "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'exec node -- POSIX script failed'
nvm alias script-test 22
[[ $(nvm run script-test "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'alias run POSIX script failed'
pushd "$HOME" >/dev/null
printf '22\n' > .nvmrc
[[ $(nvm run "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'implicit .nvmrc run POSIX script failed'
[[ $(nvm exec node.exe "$fixture" '/literal/not/a/file') == fixture-ok ]] || fail 'implicit .nvmrc exec POSIX script failed'
popd >/dev/null
[[ $(nvm run 22 -p '"/literal/not/a/file"') == /literal/not/a/file ]] || fail '-p source was rewritten'
[[ $(nvm exec 22 node.exe -e 'console.log("/literal/not/a/file")') == /literal/not/a/file ]] || fail '-e source was rewritten'
# MSYS must not reinterpret paths, shell metacharacters, Unicode, or empty args.
nvm exec 22 node.exe -e 'const expected=["space separated","double \"quote\"","amp & dollar $ ; backtick `","smart ’ 中文","100% ! (paren)","/literal/path",""];if(JSON.stringify(process.argv.slice(1))!==JSON.stringify(expected)){console.error(process.argv);process.exit(1)}' -- 'space separated' 'double "quote"' 'amp & dollar $ ; backtick `' 'smart ’ 中文' '100% ! (paren)' '/literal/path' ''
if nvm use 999.999.999; then fail 'missing version succeeded'; fi
[[ $PATH == "$active_path" ]] || fail 'failed use changed PATH'
if nvm install -s 22; then fail 'unsupported install succeeded'; fi
[[ $PATH == "$active_path" ]] || fail 'failed install changed PATH'
if nvm uninstall system; then fail 'uninstall system succeeded'; fi
[[ $PATH == "$active_path" ]] || fail 'failed uninstall changed PATH'
status=0
nvm exec 22 node.exe -e 'process.exit(7)' || status=$?
[[ $status == 7 ]] || fail 'child exit code lost'
nvm deactivate
[[ $PATH == "$initial_path" && ! ${NVM_BIN+x} ]] || fail 'deactivate failed'
[[ $(nvm exec 22 node --version) == "$version" ]] || fail 'deactivated exec node failed'
[[ $(nvm exec 22 node.exe --version) == "$version" ]] || fail 'deactivated exec node.exe failed'
[[ $PATH == "$initial_path" ]] || fail 'exec activated caller'
nvm --yes use 22
nvm uninstall 22
[[ $PATH == "$initial_path" && ! ${NVM_BIN+x} ]] || fail 'active uninstall did not deactivate'
printf 'PASS: Git Bash on native Windows %s; native Node %s; isolated metacharacter roots\n' "$NVM_TEST_ARCH" "$version"
'@
    [IO.File]::WriteAllText($script, $body.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
    & $bash --noprofile --norc -c 'source "$(cygpath --unix "$1")"' -- $script
    if ($LASTEXITCODE -ne 0) { throw "Git Bash smoke exited $LASTEXITCODE" }
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
