$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$root=Join-Path ([IO.Path]::GetTempPath()) ('codex-manager-demo-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root)|Out-Null
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$rows=@();$i=0
foreach($name in @('Personal','Work','Research')){
 $i++
 $limits=@{rateLimits=@{primary=@{usedPercent=(10*$i);windowDurationMins=300;resetsAt=($now+7200)};secondary=@{usedPercent=(15*$i);windowDurationMins=10080;resetsAt=($now+345600)}};rateLimitResetCredits=@{availableCount=1}}
 $rows+=@{key=('demo-'+$i);name=$name;email=($name.ToLowerInvariant()+'@example.com');active=($i -eq 1);status='Connected';plan='plus';limits=$limits;billing=[DateTime]::UtcNow.AddDays(20).ToString('o');billingStatus='Subscription active until (demo)';checked=[DateTime]::UtcNow.ToString('o')}
}
@{accounts=$rows;loading=$false;updated=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $root 'dashboard.json') -Encoding UTF8
$previous=$env:CODEX_MANAGER_ROOT
try{
 $env:CODEX_MANAGER_ROOT=$root
 & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $repo 'app\Dashboard.ps1') -SmokeTest
 if($LASTEXITCODE -ne 0){throw 'Demo renderer failed'}
 Copy-Item (Join-Path $root 'outputs\dashboard-smoke.png') (Join-Path $repo 'docs\screenshot.png') -Force
}finally{
 $env:CODEX_MANAGER_ROOT=$previous
 $resolved=[IO.Path]::GetFullPath($root);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if($resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^codex-manager-demo-[a-f0-9]{32}$'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
