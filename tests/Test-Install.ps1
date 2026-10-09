$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('codex-manager-install-test-' + [guid]::NewGuid().ToString('N'))
$installation = Join-Path $fixture 'CodexManager'
$desktop = Join-Path $fixture 'Desktop'
$previousRoot = $env:CODEX_MANAGER_ROOT
function Assert-Install($Condition,[string]$Message) { if (!$Condition) { throw $Message }; Write-Host ('PASS ' + $Message) }
try {
    $env:CODEX_MANAGER_ROOT = $installation
    & (Join-Path $repository 'Install.ps1') -InstallDirectory $installation -ShortcutDirectory $desktop -NoLaunch -SkipCodexCheck
    Assert-Install (Test-Path -LiteralPath (Join-Path $installation 'Dashboard.ps1')) 'first install copies dashboard'
    Assert-Install (Test-Path -LiteralPath (Join-Path $installation 'profiles') -PathType Container) 'first install creates source profiles'
    Assert-Install (Test-Path -LiteralPath (Join-Path $installation 'accounts') -PathType Container) 'first install creates canonical accounts'
    Assert-Install ([IO.File]::ReadAllText((Join-Path $installation '.codex-manager-install')) -ceq 'Codex Manager installed') 'first install creates verified installation marker'
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $desktop 'Codex Manager.lnk'))
    Assert-Install ($link.Arguments -eq ('-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $installation 'Dashboard.ps1') + '"')) 'shortcut has hidden STA dashboard arguments'
    Assert-Install ($link.IconLocation -eq ((Join-Path $installation 'CodexManager.ico') + ',0')) 'shortcut uses installed icon'
    Assert-Install ($link.TargetPath -like '*WindowsPowerShell\v1.0\powershell.exe') 'shortcut uses Windows PowerShell'
    $dummyPaths = @((Join-Path $installation 'profiles\dummy.json'),(Join-Path $installation 'accounts\dummy\auth.json'),(Join-Path $installation 'state.json'),(Join-Path $fixture '.codex\auth.json'))
    foreach ($path in $dummyPaths) { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null; [IO.File]::WriteAllText($path,'dummy-local-test-data') }
    [IO.File]::WriteAllText((Join-Path $installation 'Dashboard.ps1'),'outdated app fixture')
    & (Join-Path $repository 'Install.ps1') -InstallDirectory $installation -ShortcutDirectory $desktop -NoLaunch -SkipCodexCheck
    Assert-Install ((Get-FileHash (Join-Path $installation 'Dashboard.ps1')).Hash -eq (Get-FileHash (Join-Path $repository 'app\Dashboard.ps1')).Hash) 'update replaces app code'
    foreach ($path in $dummyPaths) { Assert-Install ([IO.File]::ReadAllText($path) -eq 'dummy-local-test-data') ('update preserves ' + [IO.Path]::GetFileName($path)) }
    & (Join-Path $repository 'Uninstall.ps1') -InstallDirectory $installation -ShortcutDirectory $desktop
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $installation 'Dashboard.ps1'))) 'uninstall removes app code'
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $desktop 'Codex Manager.lnk'))) 'uninstall removes matching shortcut'
    foreach ($path in $dummyPaths) { Assert-Install ([IO.File]::ReadAllText($path) -eq 'dummy-local-test-data') ('uninstall preserves ' + [IO.Path]::GetFileName($path)) }
    Assert-Install (Test-Path -LiteralPath (Join-Path $installation '.codex-manager-install')) 'uninstall retains marker for subsequent explicit data removal'
    function Read-Host { return 'cancel' }
    try { & (Join-Path $repository 'Uninstall.ps1') -InstallDirectory $installation -ShortcutDirectory $desktop -RemoveData; throw 'Expected deletion cancellation' } catch { if ($_.Exception.Message -ne 'Data deletion cancelled. No files were removed.') { throw } }
    Assert-Install (Test-Path -LiteralPath $dummyPaths[0]) 'cancelled data removal preserves credentials'
    function Read-Host { return 'DELETE' }
    [IO.File]::WriteAllText((Join-Path $installation 'previous-auth.json'),'dummy-backup-credential')
    [IO.Directory]::CreateDirectory((Join-Path $installation ('login-' + ('a' * 32)))) | Out-Null
    & (Join-Path $repository 'Uninstall.ps1') -InstallDirectory $installation -ShortcutDirectory $desktop -RemoveData
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $installation 'profiles'))) 'confirmed data removal deletes source profiles'
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $installation 'accounts'))) 'confirmed data removal deletes canonical accounts'
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $installation 'previous-auth.json'))) 'confirmed data removal deletes previous credential backup'
    Assert-Install (!(Test-Path -LiteralPath (Join-Path $installation ('login-' + ('a' * 32))))) 'confirmed data removal deletes leftover isolated login folder'
    Assert-Install ([IO.File]::ReadAllText($dummyPaths[3]) -eq 'dummy-local-test-data') 'confirmed data removal preserves external auth'
    Assert-Install (Test-Path -LiteralPath $fixture -PathType Container) 'confirmed data removal preserves outer folder'
} finally {
    $env:CODEX_MANAGER_ROOT = $previousRoot
    if ([IO.Directory]::GetParent($fixture).FullName -ne [IO.Path]::GetTempPath().TrimEnd('\') -or [IO.Path]::GetFileName($fixture) -notlike 'codex-manager-install-test-*') { throw 'Unsafe test cleanup path.' }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
