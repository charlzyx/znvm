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
$bashMachine = Read-Machine $bash
$bashMode = if ($bashMachine -eq $expectedMachine) { 'native' } else { 'emulated; not a native Bash process' }
Write-Host "Git Bash verification: OS=$osArch nvm PE=$('{0:x}' -f $expectedMachine) Bash PE=$('{0:x}' -f $bashMachine) ($bashMode), path=$bash"
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
