function Save-IsolatedLogin($Login, [string]$ExpectedKey) {
    $profiles=@(Get-Profiles)
    $current=if(Test-Path -LiteralPath $script:Active){Read-Auth $script:Active}else{$null}
    if($Login.Key -eq $current.Key){throw 'This account is active in Codex. Select another account in the browser; its current login has been preserved.'}
    if($ExpectedKey -and $Login.Key -ne $ExpectedKey){throw 'You signed into a different account. No saved account was replaced. Reconnect again and select the correct account.'}
    $match=@($profiles|Where-Object Key -eq $Login.Key)
    if($match.Count){
        $saved=$match[0]
        Write-Atomic ($saved.Path+'.before-independent-login') ([IO.File]::ReadAllText($saved.Path))
        Write-Atomic $saved.Path $Login.Raw
        $source=@(Get-ChildItem -LiteralPath $script:Source -File|Where-Object {$_.Extension -in '.txt','.json'}|Where-Object {(Read-Auth $_.FullName).Key -eq $Login.Key})[0]
        Write-Atomic ($source.FullName+'.before-independent-login') ([IO.File]::ReadAllText($source.FullName))
        Write-Atomic $source.FullName $Login.Raw
        $invalid=Join-Path (Split-Path $saved.Path -Parent) 'invalid-session.json'
        if(Test-Path -LiteralPath $invalid){Remove-Item -LiteralPath $invalid -Force}
    }else{
        Write-Atomic (Join-Path $script:Source ('Account-'+$Login.Key.Substring(0,12)+'.txt')) $Login.Raw
        $null=@(Get-Profiles)
    }
}
function Invoke-IsolatedLogin([string]$ExpectedKey) {
    $lock=$null;$p=$null;$loginHome=$null
    try {
        $lock=[IO.File]::Open((Join-Path $script:Root 'switch.lock'),'OpenOrCreate','ReadWrite','None')
        $cancelPath=Join-Path $script:Root 'login-cancel'
        if(Test-Path -LiteralPath $cancelPath){Remove-Item -LiteralPath $cancelPath -Force}
        $profiles=@(Get-Profiles)
        if($ExpectedKey -and !@($profiles|Where-Object Key -eq $ExpectedKey).Count){throw 'Selected account is no longer registered.'}
        $activeBefore=if(Test-Path -LiteralPath $script:Active){Read-Auth $script:Active}else{$null}
        if($ExpectedKey -and $activeBefore -and $ExpectedKey -eq $activeBefore.Key){throw 'This account is already active. Its login is preserved.'}
        $loginHome=Join-Path $script:Root ('login-'+[guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($loginHome)|Out-Null;Protect-Path $loginHome
        $pkg=Get-AppxPackage OpenAI.Codex|Select-Object -First 1
        $start=New-Object Diagnostics.ProcessStartInfo
        $start.FileName=Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
        $start.Arguments='-c cli_auth_credentials_store="file" -c analytics.enabled=false app-server --stdio'
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $start.EnvironmentVariables['CODEX_HOME']=$loginHome
        foreach($n in @('OPENAI_API_KEY','CODEX_API_KEY','CODEX_ACCESS_TOKEN')){$start.EnvironmentVariables.Remove($n)}
        $p=New-Object Diagnostics.Process;$p.StartInfo=$start;$null=$p.Start();$stderr=$p.StandardError.ReadToEndAsync()
        $null=Native-Request $p 1 'initialize' @{clientInfo=@{name='codex_account_login';title='Codex Accounts';version='1.0'}}
        $p.StandardInput.WriteLine('{"method":"initialized"}');$p.StandardInput.Flush()
        $login=Native-Request $p 2 'account/login/start' @{type='chatgpt'}
        $uri=[Uri]$login.authUrl
        if($uri.Scheme -ne 'https' -or $uri.Host -notin @('auth.openai.com','chatgpt.com')){throw 'The login service returned an unexpected address.'}
        Start-Process -FilePath $uri.AbsoluteUri
        $deadline=[DateTime]::UtcNow.AddMinutes(10)
        $success=$false
        while([DateTime]::UtcNow -lt $deadline){
            $task=$p.StandardOutput.ReadLineAsync()
            while(!$task.Wait(1000)){
                if(Test-Path -LiteralPath $cancelPath){throw 'Sign-in cancelled. No saved account was changed.'}
                if([DateTime]::UtcNow -ge $deadline){throw 'Sign-in timed out. No saved account was changed.'}
            }
            if($null -eq $task.Result){throw 'The login service closed. Retry Add account or Reconnect.'}
            try{$msg=$task.Result|ConvertFrom-Json}catch{continue}
            if($msg.method -eq 'account/login/completed' -and $msg.params.loginId -eq $login.loginId){
                if(!$msg.params.success){throw 'Sign-in did not finish successfully. No saved account was changed.'}
                $success=$true;break
            }
        }
        if(!$success){throw 'Sign-in timed out. No saved account was changed.'}
        $null=Native-Request $p 3 'account/read' @{refreshToken=$false}
        $null=Native-Request $p 4 'account/rateLimits/read' @{}
        $fresh=Read-Auth (Join-Path $loginHome 'auth.json')
        $activeNow=if(Test-Path -LiteralPath $script:Active){Read-Auth $script:Active}else{$null}
        if($activeNow.Key -ne $activeBefore.Key){throw 'The Codex account changed while adding this login. Retry to keep account identities safe.'}
        Save-IsolatedLogin $fresh $ExpectedKey
        Write-Atomic (Join-Path $script:Root 'dashboard-action.json') '{"ok":true}'
    }catch{
        # All displayed errors originate locally; no OAuth responses or credentials are logged.
        $safe=if($_.Exception.Message -match '^(This account|You signed|Selected account|The login service|Sign-in|The Codex account)'){$_.Exception.Message}else{'Could not complete account sign-in. Check your connection and retry. Existing logins were preserved.'}
        Write-Atomic (Join-Path $script:Root 'dashboard-action.json') (@{ok=$false;error=$safe}|ConvertTo-Json)
    }finally{
        if($p){try{if(!$p.HasExited){$p.StandardInput.Close();if(!$p.WaitForExit(2000)){$p.Kill();$p.WaitForExit()}}}finally{$p.Dispose()}}
        if($loginHome){
            $resolved=[IO.Path]::GetFullPath($loginHome)
            $allowed=[IO.Path]::GetFullPath($script:Root).TrimEnd('\')+'\login-'
            if($resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){
                for($attempt=0;$attempt -lt 4;$attempt++){
                    if(!(Test-Path -LiteralPath $resolved)){break}
                    try{Remove-Item -LiteralPath $resolved -Recurse -Force;break}catch{Start-Sleep -Milliseconds 500}
                }
            }
        }
        if($lock){$lock.Dispose()}
    }
}
