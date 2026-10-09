. (Join-Path $PSScriptRoot 'Package-Files.ps1')
function Resolve-ManagerRoot([string]$Directory) {
    if (!$Directory) { $Directory = if ($env:CODEX_MANAGER_ROOT) { $env:CODEX_MANAGER_ROOT } else { Join-Path $env:LOCALAPPDATA 'CodexManager' } }
    $resolved = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    if ($resolved -eq [IO.Path]::GetPathRoot($resolved).TrimEnd('\') -or $resolved -eq $env:USERPROFILE -or $resolved -eq $env:LOCALAPPDATA) { throw 'Choose a dedicated CodexManager installation directory.' }
    Assert-NoLinkedPath $resolved
    return $resolved
}
function Assert-NoLinkedPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked installation or data paths are not supported.' }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        $cursor = if ($parent) { $parent.FullName } else { $null }
    }
}
function Assert-DashboardClosed([string]$Root) {
    $paths = @('Dashboard.ps1','Dashboard-Data.ps1','Switcher.ps1','Account-Login.ps1') | ForEach-Object { Join-Path $Root $_ }
    $running = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" | Where-Object {
        if ($_.ProcessId -eq $PID -or !$_.CommandLine) { return $false }
        $command = $_.CommandLine
        return @($paths | Where-Object { $command.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
    })
    if ($running.Count) { throw 'Close the Codex Manager dashboard and wait for its account operation to finish, then run setup again.' }
}
function Get-ManagerPowerShell { return (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') }
