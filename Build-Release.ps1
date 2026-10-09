[CmdletBinding()]
param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if (!$OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot 'dist' }
. (Join-Path $PSScriptRoot 'Package-Files.ps1')
$version = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(-[a-z0-9.]+)?$') { throw 'Invalid VERSION.' }
foreach ($file in $script:ReleaseFiles) {
    if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) { throw "Required release file missing: $file" }
}
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$stage = Join-Path ([IO.Path]::GetTempPath()) ('codex-manager-release-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
try {
    foreach ($file in $script:ReleaseFiles) {
        $target = Join-Path $stage $file
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $target
    }
    $zip = Join-Path $OutputDirectory "CodexManager-$version-windows.zip"
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($zip + '.sha256', ($hash + '  ' + [IO.Path]::GetFileName($zip) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    Write-Output $zip
    Write-Output ($zip + '.sha256')
} finally {
    if ([IO.Directory]::GetParent($stage).FullName -ne [IO.Path]::GetTempPath().TrimEnd('\') -or [IO.Path]::GetFileName($stage) -notlike 'codex-manager-release-*') { throw 'Unsafe staging cleanup path.' }
    Remove-Item -LiteralPath $stage -Recurse -Force
}
