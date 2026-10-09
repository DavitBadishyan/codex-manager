function Native-Request($Process,$Id,$Method,$Params) {
    $Process.StandardInput.WriteLine((@{id=$Id;method=$Method;params=$Params}|ConvertTo-Json -Depth 8 -Compress))
    $Process.StandardInput.Flush()
    $deadline=[DateTime]::UtcNow.AddSeconds(35)
    while([DateTime]::UtcNow -lt $deadline){
        $task=$Process.StandardOutput.ReadLineAsync()
        $ms=[Math]::Max(1,[int]($deadline-[DateTime]::UtcNow).TotalMilliseconds)
        if(!$task.Wait($ms)){throw 'native_request_timeout'}
        $line=$task.Result
        if($null -eq $line){throw 'native_server_exited'}
        try{$response=$line|ConvertFrom-Json}catch{continue}
        if($response.method -eq 'account/chatgptAuthTokens/refresh'){
            $Process.StandardInput.WriteLine((@{id=$response.id;error=@{code=-32000;message='Refresh is owned by the running Codex desktop session.'}}|ConvertTo-Json -Compress))
            $Process.StandardInput.Flush()
            throw 'active_access_needs_refresh'
        }
        if($response.id -eq $Id){
            if($response.error){
                $msg=[string]$response.error.message
                $script:LastNativeAuthReason='unknown'
                foreach($reason in @('refresh_token_reused','refresh_token_expired','refresh_token_invalidated','invalid_grant','revoked','invalidated')){if($msg -match [regex]::Escape($reason)){$script:LastNativeAuthReason=$reason;throw 'saved_session_rejected'}}
                if($msg -match 'refresh.token.*(expired|reused)'){$script:LastNativeAuthReason='refresh_token_rejected';throw 'saved_session_rejected'}
                throw 'native_auth_check_failed'
            }
            return $response.result
        }
    }
    throw 'native_request_timeout'
}
function Test-NativeSession($Profile) {
    $process=$null
    try{
        $before=Read-Auth $Profile.Path
        Write-Atomic ($Profile.Path+'.before-check') $before.Raw
        $pkg=Get-AppxPackage OpenAI.Codex|Select-Object -First 1
        $start=New-Object Diagnostics.ProcessStartInfo
        $start.FileName=Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
        $start.Arguments='-c cli_auth_credentials_store="file" -c analytics.enabled=false app-server --stdio'
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $start.EnvironmentVariables['CODEX_HOME']=Split-Path $Profile.Path -Parent
        foreach($name in @('OPENAI_API_KEY','CODEX_API_KEY','CODEX_ACCESS_TOKEN')){$start.EnvironmentVariables.Remove($name)}
        $process=New-Object Diagnostics.Process
        $process.StartInfo=$start;$null=$process.Start()
        $stderr=$process.StandardError.ReadToEndAsync()
        $null=Native-Request $process 1 'initialize' @{clientInfo=@{name='codex_account_switcher';title='Local account switcher';version='1.1'}}
        $process.StandardInput.WriteLine('{"method":"initialized"}');$process.StandardInput.Flush()
        $account=Native-Request $process 2 'account/read' @{refreshToken=$true}
        if($account.account.type -ne 'chatgpt'){throw 'no_chatgpt_session'}
        $null=Native-Request $process 3 'account/rateLimits/read' @{}
        $after=Read-Auth $Profile.Path
        if($after.Key -ne $before.Key){throw 'unexpected_identity'}
        return 'usable'
    }catch{
        if($_.Exception.Message -eq 'saved_session_rejected'){return 'rejected'}
        throw 'Codex could not verify the next saved session. Check your connection and retry. Current login was not changed.'
    }finally{
        if($process){try{if(!$process.HasExited){$process.StandardInput.Close();if(!$process.WaitForExit(3000)){$process.Kill();$process.WaitForExit()}}}finally{$process.Dispose()}}
    }
}
