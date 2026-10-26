# Deterministic product ZIP shared by PR CI and both release workflows.
# Only the six explicit product files below are included; no fixture directories.
[CmdletBinding()]
param(
    [string]$Binary = (Join-Path $PSScriptRoot '../zig-out/bin/nvm.exe'),
    [Parameter(Mandatory = $true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$binaryPath = (Resolve-Path -LiteralPath $Binary).Path
$destinationPath = [IO.Path]::GetFullPath($Destination)
if ((Test-Path -LiteralPath $destinationPath) -or (Test-Path -LiteralPath "$destinationPath.sha256")) { throw "Destination or checksum already exists: $destinationPath" }
$files = [ordered]@{
    'bin/nvm.exe' = $binaryPath
    'bin/nrm.exe' = $binaryPath
    'cmd/nvm.cmd' = (Join-Path $repo 'scripts/cmd/nvm.cmd')
    'cmd/init.cmd' = (Join-Path $repo 'scripts/cmd/init.cmd')
    'cmd/finish.cmd' = (Join-Path $repo 'scripts/cmd/finish.cmd')
    'WINDOWS.md' = (Join-Path $repo 'WINDOWS.md')
}
foreach ($source in $files.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing package source: $source" }
}
Add-Type -AssemblyName System.IO.Compression
# Build alongside destination, then move without overwrite. On failure remove only
# this invocation's partial ZIP, never an existing product asset.
$partial = $destinationPath + '.' + [guid]::NewGuid().ToString('N') + '.partial'
try {
    $archive = [IO.Compression.ZipFile]::Open($partial, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $files.Keys) {
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $inputStream = [IO.File]::OpenRead($files[$name])
            try {
                $outputStream = $entry.Open()
                try { $inputStream.CopyTo($outputStream) }
                finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }
    # Reopen the actual ZIP and validate its exact allowlist and bytes before
    # promoting it. Entry count also rejects duplicates and directory fixtures.
    $check = [IO.Compression.ZipFile]::OpenRead($partial)
    try {
        if ($check.Entries.Count -ne $files.Count) { throw 'ZIP entry count differs from product allowlist' }
        $seen = @{}
        $hashes = @{}
        foreach ($entry in $check.Entries) {
            $name = $entry.FullName
            if (@($files.Keys) -cnotcontains $name) { throw "Unexpected ZIP entry: $name" }
            if ($seen.ContainsKey($name)) { throw "Duplicate ZIP entry: $name" }
            $seen[$name] = $true
            if ($entry.LastWriteTime.DateTime -ne [DateTime]::new(2000, 1, 1, 0, 0, 0)) { throw "Non-deterministic timestamp: $name" }
            $stream = $entry.Open()
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $hashes[$name] = [Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant() }
            finally { $hasher.Dispose(); $stream.Dispose() }
            $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $files[$name]).Hash.ToLowerInvariant()
            if ($hashes[$name] -cne $sourceHash) { throw "ZIP bytes differ from product source: $name" }
            if ($name.EndsWith('.cmd', [StringComparison]::Ordinal)) {
                $stream = $entry.Open()
                $memory = [IO.MemoryStream]::new()
                try {
                    $stream.CopyTo($memory)
                    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
                    $null = $strictUtf8.GetString($memory.ToArray())
                } finally { $memory.Dispose(); $stream.Dispose() }
            }
        }
        if ($hashes['bin/nvm.exe'] -cne $hashes['bin/nrm.exe']) { throw 'Packaged native binaries differ' }
    } finally { $check.Dispose() }
    [IO.File]::Move($partial, $destinationPath)
} finally {
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
}
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash.ToLowerInvariant()
$asset = [IO.Path]::GetFileName($destinationPath)
[IO.File]::WriteAllText("$destinationPath.sha256", "$hash  $asset`n", [Text.Encoding]::ASCII)
Write-Host "Packaged and verified six product files: $destinationPath"
Write-Host "SHA256: $hash"
