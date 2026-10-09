$ErrorActionPreference='Stop'
. "$PSScriptRoot\Test-Switcher.ps1"
. "$PSScriptRoot\..\app\Account-Login.ps1"
$activeBefore=[IO.File]::ReadAllText($script:Active)
$profiles=@(Get-Profiles)
$target=@($profiles|Where-Object {$_.Key -ne (Read-Auth $script:Active).Key})[0]
$other=@($profiles|Where-Object {$_.Key -ne $target.Key})|ForEach-Object {[pscustomobject]@{Path=$_.Path;Raw=[IO.File]::ReadAllText($_.Path)}}
$tokens=(Read-Auth $target.Path).Raw|ConvertFrom-Json
$tokens.tokens.refresh_token='dummy-independent-login'
$file=Join-Path $script:TestBase 'fresh.json'
Write-Atomic $file ($tokens|ConvertTo-Json -Depth 6)
Write-Atomic (Join-Path (Split-Path $target.Path -Parent) 'invalid-session.json') '{"reason":"revoked"}'
Save-IsolatedLogin (Read-Auth $file) $target.Key
Assert (([IO.File]::ReadAllText($target.Path)|ConvertFrom-Json).tokens.refresh_token -eq 'dummy-independent-login') 'reconnect replaces only selected credentials'
Assert (!(Test-Path (Join-Path (Split-Path $target.Path -Parent) 'invalid-session.json'))) 'reconnect clears rejection marker'
foreach($p in $other){Assert ([IO.File]::ReadAllText($p.Path) -ceq $p.Raw) 'other account credentials preserved'}
Assert ([IO.File]::ReadAllText($script:Active) -ceq $activeBefore) 'isolated reconnect does not change active Codex login'
Expect-Error {Save-IsolatedLogin (Read-Auth $script:Active) $target.Key} 'active in Codex' 'wrong active browser account cannot replace target'
Write-Atomic $file (Dummy 99)
Expect-Error {Save-IsolatedLogin (Read-Auth $file) $target.Key} 'different account' 'wrong browser identity rejected'
$beforeCount=@(Get-Profiles).Count
Save-IsolatedLogin (Read-Auth $file) ''
Assert (@(Get-Profiles).Count -eq ($beforeCount+1)) 'add independent account extends arbitrary account count'
Assert ([IO.File]::ReadAllText($script:Active) -ceq $activeBefore) 'adding account preserves active Codex login'
Write-Host 'All isolated login persistence tests passed.'
