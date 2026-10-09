[CmdletBinding()]
param([string]$InstallDirectory,[string]$ShortcutDirectory,[switch]$NoLaunch,[switch]$SkipCodexCheck)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Setup-Common.ps1')
if ($env:OS -ne 'Windows_NT') { throw 'Codex Manager requires Windows.' }
if (!$SkipCodexCheck -and !(Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1)) {
    throw 'Install the official Codex Windows desktop app first, sign in once, then run Install.cmd again. See https://developers.openai.com/codex/app/ . Codex Manager has not been installed.'
}
if ($SkipCodexCheck -and (!$InstallDirectory -or !$NoLaunch)) { throw '-SkipCodexCheck is only for isolated tests with -InstallDirectory and -NoLaunch.' }
$installRoot = Resolve-ManagerRoot $InstallDirectory
if (!$ShortcutDirectory) { $ShortcutDirectory = [Environment]::GetFolderPath('Desktop') }
$ShortcutDirectory = [IO.Path]::GetFullPath($ShortcutDirectory)
Assert-NoLinkedPath $ShortcutDirectory
Assert-DashboardClosed $installRoot
Assert-NoLinkedPath (Join-Path $installRoot '.codex-manager-install')
foreach ($name in $script:AppFiles) {
    if (!(Test-Path -LiteralPath (Join-Path (Join-Path $PSScriptRoot 'app') $name) -PathType Leaf)) { throw "Incomplete download: app/$name is missing. Extract the entire release ZIP and try again." }
    Assert-NoLinkedPath (Join-Path $installRoot $name)
}
# Loading the library provides its ACL implementation without running setup or changing authentication.
$previousRoot = $env:CODEX_MANAGER_ROOT
try {
    $env:CODEX_MANAGER_ROOT = $installRoot
    . (Join-Path $PSScriptRoot 'app\Switcher.ps1') -Library
} finally { $env:CODEX_MANAGER_ROOT = $previousRoot }
foreach ($directory in @($installRoot,(Join-Path $installRoot 'profiles'),(Join-Path $installRoot 'accounts'))) {
    Assert-NoLinkedPath $directory
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    Protect-Path $directory
}
foreach ($name in $script:AppFiles) {
    Copy-Item -LiteralPath (Join-Path (Join-Path $PSScriptRoot 'app') $name) -Destination (Join-Path $installRoot $name) -Force
    Protect-Path (Join-Path $installRoot $name)
}
[IO.File]::WriteAllText((Join-Path $installRoot '.codex-manager-install'), 'Codex Manager installed', [Text.Encoding]::ASCII)
Protect-Path (Join-Path $installRoot '.codex-manager-install')
[IO.Directory]::CreateDirectory($ShortcutDirectory) | Out-Null
$shortcutPath = Join-Path $ShortcutDirectory 'Codex Manager.lnk'
Assert-NoLinkedPath $shortcutPath
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Get-ManagerPowerShell
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $installRoot 'Dashboard.ps1') + '"'
$shortcut.WorkingDirectory = $installRoot
$shortcut.IconLocation = (Join-Path $installRoot 'CodexManager.ico') + ',0'
$shortcut.Description = 'Codex Manager - local account manager'
$shortcut.WindowStyle = 7
$shortcut.Save()
Write-Host "Codex Manager installed in $installRoot. Saved accounts and settings are preserved during updates."
if (!$NoLaunch) { Start-Process -FilePath (Get-ManagerPowerShell) -ArgumentList $shortcut.Arguments -WindowStyle Hidden }
