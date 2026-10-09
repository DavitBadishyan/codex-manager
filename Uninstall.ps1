[CmdletBinding()]
param([string]$InstallDirectory,[string]$ShortcutDirectory,[switch]$RemoveData)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Setup-Common.ps1')
$root = Resolve-ManagerRoot $InstallDirectory
Assert-DashboardClosed $root
$marker = Join-Path $root '.codex-manager-install'
Assert-NoLinkedPath $marker
if (!(Test-Path -LiteralPath $marker -PathType Leaf) -or [IO.File]::ReadAllText($marker) -cne 'Codex Manager installed') { throw 'This directory is not a verified Codex Manager installation. No files were removed.' }
if ($RemoveData) {
    $answer = Read-Host "Delete saved Codex Manager credentials and settings in $root? Type DELETE to confirm"
    if ($answer -cne 'DELETE') { throw 'Data deletion cancelled. No files were removed.' }
}
if (!$ShortcutDirectory) { $ShortcutDirectory = [Environment]::GetFolderPath('Desktop') }
$shortcutPath = Join-Path ([IO.Path]::GetFullPath($ShortcutDirectory)) 'Codex Manager.lnk'
Assert-NoLinkedPath $shortcutPath
if (Test-Path -LiteralPath $shortcutPath) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ($shortcut.Arguments.IndexOf((Join-Path $root 'Dashboard.ps1'), [StringComparison]::OrdinalIgnoreCase) -ge 0) { Remove-Item -LiteralPath $shortcutPath -Force }
}
foreach ($name in $script:AppFiles) {
    $path = Join-Path $root $name
    Assert-NoLinkedPath $path
    if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
}
if ($RemoveData) {
    # Never recursively delete the installation root: remove only known data locations.
    $dataDirectories = @('profiles','accounts','dashboard-active')
    if (Test-Path -LiteralPath $root -PathType Container) {
        $dataDirectories += @(Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object { $_.Name -match '^login-[a-f0-9]{32}$' } | ForEach-Object { $_.Name })
    }
    foreach ($name in $dataDirectories) {
        $path = [IO.Path]::GetFullPath((Join-Path $root $name))
        if ([IO.Directory]::GetParent($path).FullName -ne $root) { throw 'Unsafe data deletion path.' }
        Assert-NoLinkedPath $path
        # Reject linked descendants before a recursive operation.
        if (Test-Path -LiteralPath $path) {
            if (@(Get-ChildItem -LiteralPath $path -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Linked credential data cannot be deleted by setup.' }
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
    foreach ($name in @('state.json','dashboard.json','audit.jsonl','switch.lock','shutdown-diagnostic.json','previous-auth.json','pending.json','dashboard-action.json','dashboard-error.json','dashboard-switch.log','login-cancel')) {
        $path = Join-Path $root $name
        Assert-NoLinkedPath $path
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
    Remove-Item -LiteralPath $marker -Force
    Write-Host 'Codex Manager app files and selected local data removed. Your .codex folder remains untouched.'
} else { Write-Host "Codex Manager app files removed. Credentials and settings remain in $root. Use -RemoveData only if you also want to erase them." }
