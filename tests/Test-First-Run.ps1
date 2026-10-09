$ErrorActionPreference='Stop'
. "$PSScriptRoot\Test-Switcher.ps1"
. "$PSScriptRoot\..\app\Account-Login.ps1"
$emptySource=Join-Path $script:TestBase 'first-run-profiles'
$script:Source=$emptySource
$script:Active=Join-Path $script:TestBase 'first-run-home\auth.json'
[IO.Directory]::CreateDirectory((Split-Path $script:Active -Parent))|Out-Null
Assert (@(Get-Profiles).Count -eq 0) 'empty first launch accepts no current Codex login'
$fake=Join-Path $script:TestBase 'independent-first.json'
Write-Atomic $fake (Dummy 100)
Save-IsolatedLogin (Read-Auth $fake) ''
Assert (@(Get-Profiles).Count -eq 1) 'first account can be added without a current desktop login'
$script:Mode='Switch';$script:TargetKey=(Read-Auth $fake).Key
Invoke-Switcher
Assert ((Read-Auth $script:Active).Key -eq $script:TargetKey) 'first saved account can be activated without previous auth.json'
$script:Source=Join-Path $script:TestBase 'import-current-profiles'
Write-Atomic $script:Active (Dummy 101)
$imported=@(Get-Profiles)
Assert ($imported.Count -eq 1 -and $imported[0].Key -eq (Read-Auth $script:Active).Key) 'first launch safely imports an existing current session'
Write-Host 'PASS first-run onboarding'
