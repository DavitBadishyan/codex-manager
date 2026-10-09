$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\app\Switcher.ps1" -Library
$script:TestBase=Join-Path $PSScriptRoot ('dummy-'+[guid]::NewGuid().ToString('N'))
$script:Root=Join-Path $script:TestBase 'store'
$script:Source=Join-Path $script:TestBase 'input'
$script:AuthHome=Join-Path $script:TestBase 'home'
$script:Active=Join-Path $script:AuthHome 'auth.json'
foreach($p in @($script:Source,$script:AuthHome,$script:Root)){[IO.Directory]::CreateDirectory($p)|Out-Null;Protect-Path $p}
function Get-DesktopApp {return [pscustomobject]@{Directory='dummy';Aumid='dummy'}}
function Close-Desktop($App) {$script:Closes++}
function Open-Desktop($App) {$script:Opens++}
function Get-AppProcesses($App) {return @()}
function Test-NativeSession($Profile) {return 'usable'}
function Dummy($N,$Refresh='dummy-refresh') {
    $claims=@{sub="dummy-user-$N";'https://api.openai.com/auth'=@{chatgpt_account_id="dummy-account-$N"}}|ConvertTo-Json -Compress
    $payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)).TrimEnd('=').Replace('+','-').Replace('/','_')
    return (@{auth_mode='chatgpt';tokens=@{account_id="dummy-account-$N";id_token="dummy.$payload.dummy";access_token='dummy-access';refresh_token=$Refresh}}|ConvertTo-Json -Depth 4)
}
function Assert($Condition,$Label){if(!$Condition){throw "FAIL: $Label"};Write-Host "PASS: $Label"}
function Expect-Error($Block,$Pattern,$Label){$caught=$false;try{& $Block}catch{if($_.Exception.Message -notmatch $Pattern){throw};$caught=$true};Assert $caught $Label}
$script:Closes=0;$script:Opens=0
Write-Atomic (Join-Path $script:Source '01.txt') (Dummy 1)
Write-Atomic (Join-Path $script:Source '02.json') (Dummy 2)
Write-Atomic $script:Active (Dummy 1)
$script:Mode='Setup';Invoke-Switcher
Assert ($script:Closes -eq 0) 'setup leaves app running'
$script:Mode='Switch';Invoke-Switcher
$key2=(Read-Auth (Join-Path $script:Source '02.json')).Key
Assert ((Read-Auth $script:Active).Key -eq $key2) 'two-account forward transition'
Invoke-Switcher
$key1=(Read-Auth (Join-Path $script:Source '01.txt')).Key
Assert ((Read-Auth $script:Active).Key -eq $key1) 'two-account wraparound'
Write-Atomic (Join-Path $script:Source '03.txt') (Dummy 3)
Invoke-Switcher;Invoke-Switcher
Assert ((Read-Auth $script:Active).Key -eq (Read-Auth (Join-Path $script:Source '03.txt')).Key) 'new txt file extends rotation'
Invoke-Switcher
Assert ((Read-Auth $script:Active).Key -eq $key1) 'three-account wraparound'
Write-Atomic $script:Active (Dummy 1 'dummy-refreshed')
Invoke-Switcher
$saved=Join-Path $script:Root "accounts\$key1\auth.json"
Assert (([IO.File]::ReadAllText($saved)|ConvertFrom-Json).tokens.refresh_token -eq 'dummy-refreshed') 'latest refreshed tokens saved to correct identity'
for($i=4;$i -le 12;$i++){Write-Atomic (Join-Path $script:Source ('{0:d2}.txt' -f $i)) (Dummy $i)}
Assert (@(Get-Profiles).Count -eq 12) 'arbitrary profile count discovered'
Write-Atomic (Join-Path $script:Source 'duplicate.txt') (Dummy 1)
Expect-Error {Invoke-Switcher} 'Duplicate' 'duplicates fail safely'
Remove-Item -LiteralPath (Join-Path $script:Source 'duplicate.txt')
Write-Atomic (Join-Path $script:Source 'broken.txt') 'not JSON'
Expect-Error {Invoke-Switcher} 'Invalid or unreadable' 'corrupt file rejected without credential output'
Remove-Item -LiteralPath (Join-Path $script:Source 'broken.txt')
Save-State $key1
Expect-Error {Invoke-Switcher} 'differs' 'unexpected active identity blocked'
Save-State $key2
$lock=[IO.File]::Open((Join-Path $script:Root 'switch.lock'),'OpenOrCreate','ReadWrite','None')
try{Expect-Error {Invoke-Switcher} 'already running' 'concurrent execution blocked'}finally{$lock.Dispose()}
$originalSave=${function:Save-State}
function Save-State($Key){if($script:FailOnce){$script:FailOnce=$false;throw 'dummy injected state failure'};& $originalSave $Key}
$script:FailOnce=$true
Expect-Error {Invoke-Switcher} 'dummy injected' 'state failure triggers rollback'
Assert ((Read-Auth $script:Active).Key -eq $key2) 'rollback restores previous active identity'
Assert (([IO.File]::ReadAllText((Join-Path $script:Root 'state.json'))|ConvertFrom-Json).active -eq $key2) 'rollback restores previous state'
Write-Atomic (Join-Path $script:Root 'pending.json') (@{from=$key1;to=$key2}|ConvertTo-Json)
Invoke-Switcher
Assert (!(Test-Path -LiteralPath (Join-Path $script:Root 'pending.json'))) 'interrupted transaction reconciled by actual identity'
Write-Atomic (Join-Path $script:AuthHome 'config.toml') 'cli_auth_credentials_store = "keyring"'
Expect-Error {Invoke-Switcher} 'file authentication' 'keyring mode rejected'
Remove-Item -LiteralPath (Join-Path $script:AuthHome 'config.toml')
function Read-Host($Prompt){return 'SAVE'}
Write-Atomic $script:Active (Dummy 13)
$script:Mode='Register';Invoke-Switcher
Assert (@(Get-Profiles).Count -eq 13) 'registration adds a signed-in account without manual copying'
Write-Atomic $script:Active (Dummy 13 'dummy-reauthenticated')
Invoke-Switcher
$key13=(Read-Auth $script:Active).Key
$saved13=Join-Path $script:Root "accounts\$key13\auth.json"
Assert (([IO.File]::ReadAllText($saved13)|ConvertFrom-Json).tokens.refresh_token -eq 'dummy-reauthenticated') 'confirmed reauthentication updates existing account'
Assert (Test-Path -LiteralPath ($saved13+'.previous')) 'registration preserves backup before overwrite'
$script:Mode='Capture'
Write-Atomic $script:Active (Dummy 14)
$beforeCloses=$script:Closes
Invoke-Switcher
Assert (@(Get-Profiles).Count -eq 14 -and $script:Closes -eq $beforeCloses) 'capture saves new current login without closing app'
Expect-Error {Invoke-Switcher} 'already saved' 'capture preserves existing profile'
$script:Mode='Switch'
$list=@(Get-Profiles)
$activeKey=(Read-Auth $script:Active).Key
$idx=0;for($i=0;$i -lt $list.Count;$i++){if($list[$i].Key -eq $activeKey){$idx=$i}}
$targetProfile=$list[($idx+1)%$list.Count]
Write-Atomic (Join-Path (Split-Path $targetProfile.Path -Parent) 'invalid-session.json') '{"reason":"revoked"}'
Invoke-Switcher
Assert ((Read-Auth $script:Active).Key -ne $targetProfile.Key) 'known revoked target skipped without loading its credentials'
foreach($p in @(Get-Profiles)){
    if($p.Key -ne (Read-Auth $script:Active).Key){Write-Atomic (Join-Path (Split-Path $p.Path -Parent) 'invalid-session.json') '{"reason":"revoked"}'}
}
$beforeCloses=$script:Closes
Expect-Error {Invoke-Switcher} 'No other usable' 'all revoked alternatives stop safely'
Assert ($script:Closes -eq $beforeCloses) 'no usable alternative leaves current app running'
foreach($p in @(Get-Profiles)){$marker=Join-Path (Split-Path $p.Path -Parent) 'invalid-session.json';if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}}
$chosen=@(Get-Profiles|Where-Object {$_.Key -eq $key13})[0]
$script:TargetKey=$chosen.Key
Invoke-Switcher
Assert ((Read-Auth $script:Active).Key -eq $chosen.Key) 'dashboard selection switches directly to the chosen account'
$beforeCloses=$script:Closes
Invoke-Switcher
Assert ($script:Closes -eq $beforeCloses) 'selecting active account does not restart Codex'
$script:TargetKey='missing-key'
Expect-Error {Invoke-Switcher} 'no longer registered' 'unknown dashboard account rejected before shutdown'
$script:TargetKey=$null
Write-Host 'All dummy-only tests passed. No real authentication or processes touched.'
