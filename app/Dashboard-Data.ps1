param([string]$Action='Refresh',[string]$TargetKey)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Switcher.ps1" -Library -TargetKey $TargetKey
$cache=Join-Path $script:Root 'dashboard.json'
if($Action -in @('Add','Reconnect')){
    . "$PSScriptRoot\Account-Login.ps1"
    if($Action -eq 'Reconnect' -and !$TargetKey){throw 'Choose an account to reconnect.'}
    Invoke-IsolatedLogin $TargetKey
    exit
}
if($Action -eq 'Switch'){
    try{$script:Mode='Switch';Invoke-Switcher *> (Join-Path $script:Root 'dashboard-switch.log');Write-Atomic (Join-Path $script:Root 'dashboard-action.json') '{"ok":true}'}catch{Write-Atomic (Join-Path $script:Root 'dashboard-action.json') (@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json)}
    exit
}
$lock=$null;$rows=@();$runId=[guid]::NewGuid().ToString('N')
try{
    $lock=[IO.File]::Open((Join-Path $script:Root 'switch.lock'),'OpenOrCreate','ReadWrite','None')
    $errorCache=Join-Path $script:Root 'dashboard-error.json'
    if(Test-Path -LiteralPath $errorCache){Remove-Item -LiteralPath $errorCache -Force}
    $current=if(Test-Path -LiteralPath $script:Active){Read-Auth $script:Active}else{$null}
    $pkg=Get-AppxPackage OpenAI.Codex|Select-Object -First 1
    foreach($profile in @(Get-Profiles)){
        $isActive=$profile.Key -eq $current.Key
        $row=[ordered]@{key=$profile.Key;name=$profile.Name;active=$isActive;status='Loading';email='';plan='Unknown';limits=$null;billing=$null;billingStatus='Not exposed by Codex';checked=[DateTime]::UtcNow.ToString('o')}
        $p=$null
        try{
            $auth=if($isActive){Read-Auth $script:Active}else{Read-Auth $profile.Path}
            $a=$auth.Raw|ConvertFrom-Json
            $s=$a.tokens.id_token.Split('.')[1].Replace('-','+').Replace('_','/');$s=$s.PadRight($s.Length+((4-$s.Length%4)%4),'=')
            $claims=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))|ConvertFrom-Json
            $row.email=$claims.email
            $authClaims=$claims.'https://api.openai.com/auth'
            $row.plan=$authClaims.chatgpt_plan_type
            if($authClaims.chatgpt_subscription_active_until){$row.billing=$authClaims.chatgpt_subscription_active_until;$row.billingStatus='Subscription active until (session claim)'}
            $invalid=Join-Path (Split-Path $profile.Path -Parent) 'invalid-session.json'
            if(!$isActive -and (Test-Path -LiteralPath $invalid)){$row.status='Sign-in required';continue}
            $profileHome=Split-Path $profile.Path -Parent
            if($isActive){$profileHome=Join-Path $script:Root 'dashboard-active';[IO.Directory]::CreateDirectory($profileHome)|Out-Null;Protect-Path $profileHome;$oldCopy=Join-Path $profileHome 'auth.json';if(Test-Path -LiteralPath $oldCopy){Remove-Item -LiteralPath $oldCopy -Force}}
            $start=New-Object Diagnostics.ProcessStartInfo
            $start.FileName=Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
            $start.Arguments='-c cli_auth_credentials_store="file" -c analytics.enabled=false app-server --stdio'
            if($isActive){$start.Arguments='-c cli_auth_credentials_store="ephemeral" -c analytics.enabled=false app-server --stdio'}
            $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
            $start.EnvironmentVariables['CODEX_HOME']=$profileHome
            foreach($n in @('OPENAI_API_KEY','CODEX_API_KEY','CODEX_ACCESS_TOKEN')){$start.EnvironmentVariables.Remove($n)}
            $p=New-Object Diagnostics.Process;$p.StartInfo=$start;$null=$p.Start();$stderr=$p.StandardError.ReadToEndAsync()
            $null=Native-Request $p 1 'initialize' @{clientInfo=@{name='codex_account_dashboard';version='1.1';title='Codex Accounts'};capabilities=@{experimentalApi=$true}}
            $p.StandardInput.WriteLine('{"method":"initialized"}');$p.StandardInput.Flush()
            if($isActive){$null=Native-Request $p 9 'account/login/start' @{type='chatgptAuthTokens';accessToken=$a.tokens.access_token;chatgptAccountId=$a.tokens.account_id;chatgptPlanType=$row.plan}}
            $acct=Native-Request $p 2 'account/read' @{refreshToken=$false}
            $usage=Native-Request $p 3 'account/rateLimits/read' @{}
            $row.email=$acct.account.email;$row.plan=$acct.account.planType;$row.limits=$usage;$row.status='Connected'
            $row['usageChecked']=[DateTime]::UtcNow.ToString('o')
            $freshAuth=if($isActive){Read-Auth $script:Active}else{Read-Auth $profile.Path}
            if($freshAuth.Key -ne $profile.Key){throw 'unexpected_identity'}
            $row['profileIdentityVerified']=$true
            $freshTokens=($freshAuth.Raw|ConvertFrom-Json).tokens
            $payload=$freshTokens.id_token.Split('.')[1].Replace('-','+').Replace('_','/')
            $payload=$payload.PadRight($payload.Length+((4-$payload.Length%4)%4),'=')
            $freshClaims=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))|ConvertFrom-Json
            $until=$freshClaims.'https://api.openai.com/auth'.chatgpt_subscription_active_until
            if($until){$row.billing=$until;$row.billingStatus='Subscription active until (session claim)'}
            try {
                $fresh=if($isActive){$a.tokens}else{([IO.File]::ReadAllText((Join-Path $profileHome 'auth.json'))|ConvertFrom-Json).tokens}
                $headers=@{Authorization=('Bearer '+$fresh.access_token);'ChatGPT-Account-Id'=$fresh.account_id;originator='Codex Desktop';'OAI-Product-Sku'='CODEX'}
                $subscription=Invoke-RestMethod -Method Get -Uri ('https://chatgpt.com/backend-api/subscriptions?account_id='+[Uri]::EscapeDataString($fresh.account_id)) -Headers $headers -TimeoutSec 12
                $row['billingSource']='Live subscription service'
                if($subscription.active_until){$row.billing=$subscription.active_until;$row.billingStatus=if($subscription.will_renew -eq $true){'Next renewal'}else{'Subscription ends'}}
                else{$row['billingSource']='Session claim; service did not expose a date'}
            } catch {$row['billingSource']='Session claim; billing service unavailable'}
        }catch{$row.status=if($_.Exception.Message -eq 'saved_session_rejected'){'Sign-in required'}else{'Could not refresh'}; if(!$isActive -and $_.Exception.Message -eq 'saved_session_rejected'){Write-Atomic (Join-Path (Split-Path $profile.Path -Parent) 'invalid-session.json') (@{reason='rejected';authError=$script:LastNativeAuthReason;checked=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json)}; $row['diagnostic']=($_.Exception.GetType().Name+':'+$_.InvocationInfo.ScriptLineNumber); if($_.Exception.Message -match '^[a-z_]+$'){$row['diagnostic']=$_.Exception.Message}}
        finally{if($p){if(!$p.HasExited){$p.StandardInput.Close();if(!$p.WaitForExit(2000)){$p.Kill()}};$p.Dispose()};$rows+=[pscustomobject]$row}
    }
    Write-Atomic $cache (@{accounts=$rows;loading=$false;runId=$runId;updated=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 15)
}catch{Write-Atomic (Join-Path $script:Root 'dashboard-error.json') '{"error":"Account store is busy or unavailable. Retry shortly."}'}finally{if($lock){$lock.Dispose()}}
