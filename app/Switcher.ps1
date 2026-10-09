param([ValidateSet('Switch','Setup','Register','Capture','Check')][string]$Mode='Switch', [switch]$Library,[string]$TargetKey)
$ErrorActionPreference='Stop'
$script:Root=if($env:CODEX_MANAGER_ROOT){[IO.Path]::GetFullPath($env:CODEX_MANAGER_ROOT)}elseif(Test-Path -LiteralPath (Join-Path $PSScriptRoot '.codex-manager-install')){$PSScriptRoot}else{Join-Path $env:LOCALAPPDATA 'CodexManager'}
$script:Source=Join-Path $script:Root 'profiles'
$script:AuthHome=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
$script:Active=Join-Path $script:AuthHome 'auth.json'
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Native-Session.ps1')){. (Join-Path $PSScriptRoot 'Native-Session.ps1')}
function Protect-Path($Path) {
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $isDirectory=Test-Path -LiteralPath $Path -PathType Container
    $acl=if($isDirectory){[IO.Directory]::GetAccessControl($Path,[Security.AccessControl.AccessControlSections]::Access)}else{[IO.File]::GetAccessControl($Path,[Security.AccessControl.AccessControlSections]::Access)}
    $acl.SetAccessRuleProtection($true,$false)
    foreach($existing in @($acl.Access)){$acl.RemoveAccessRuleSpecific($existing)}
    foreach($id in @($sid.Value,'S-1-5-18','S-1-5-32-544')) {
        $inherit=if(Test-Path -LiteralPath $Path -PathType Container){'ContainerInherit, ObjectInherit'}else{'None'}
        $identity=New-Object Security.Principal.SecurityIdentifier($id)
        $rule=New-Object Security.AccessControl.FileSystemAccessRule($identity,'FullControl',$inherit,'None','Allow')
        $acl.AddAccessRule($rule)
    }
    if($isDirectory){[IO.Directory]::SetAccessControl($Path,$acl)}else{[IO.File]::SetAccessControl($Path,$acl)}
}
function Read-Auth($Path) {
    try {
        $raw=[IO.File]::ReadAllText($Path); $a=$raw | ConvertFrom-Json
        if($a.auth_mode -ne 'chatgpt' -or !$a.tokens.account_id -or !$a.tokens.refresh_token -or !$a.tokens.access_token){throw 'invalid'}
        $parts=$a.tokens.id_token.Split('.')
        if($parts.Count -ne 3){throw 'invalid'}
        $s=$parts[1].Replace('-','+').Replace('_','/'); $s=$s.PadRight($s.Length+((4-$s.Length%4)%4),'=')
        $claims=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) | ConvertFrom-Json
        if(!$claims.sub -or $claims.'https://api.openai.com/auth'.chatgpt_account_id -ne $a.tokens.account_id){throw 'invalid'}
        $bytes=[Text.Encoding]::UTF8.GetBytes($a.tokens.account_id+'|'+$claims.sub)
        $sha=[Security.Cryptography.SHA256]::Create()
        try{$key=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
        return [pscustomobject]@{Raw=$raw; Key=$key}
    } catch { throw "Invalid or unreadable ChatGPT auth file: $([IO.Path]::GetFileName($Path)). Expected complete auth.json contents; sign in again if needed." }
}
function Write-Atomic($Path,[string]$Text) {
    $tmp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllText($tmp,$Text,(New-Object Text.UTF8Encoding($false))); Protect-Path $tmp
        if(Test-Path -LiteralPath $Path){
            Protect-Path $Path
            $backup=$Path+'.atomic-backup'
            [IO.File]::Replace($tmp,$Path,$backup)
            Remove-Item -LiteralPath $backup -Force
        }else{[IO.File]::Move($tmp,$Path)}
    } finally {if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Force}}
}
function Save-State($Key) { Write-Atomic (Join-Path $script:Root 'state.json') (@{active=$Key;updated=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json) }
function Get-Profiles {
    foreach($directory in @($script:Root,$script:Source)){[IO.Directory]::CreateDirectory($directory)|Out-Null;Protect-Path $directory}
    # First launch can retain an already signed-in ChatGPT session without logging out.
    if(!@(Get-ChildItem -LiteralPath $script:Source -File|Where-Object {$_.Extension -in '.txt','.json'}).Count -and (Test-Path -LiteralPath $script:Active)){
        try{$existing=Read-Auth $script:Active}catch{$existing=$null}
        if($existing){Write-Atomic (Join-Path $script:Source ('Account-'+$existing.Key.Substring(0,12)+'.txt')) $existing.Raw}
    }
    if((Get-Item -LiteralPath $script:Source).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked credential folders are not supported.'}
    Protect-Path $script:Source
    $files=@(Get-ChildItem -LiteralPath $script:Source -File | Where-Object {$_.Extension -in '.txt','.json'} | Sort-Object Name)
    $seen=@{}; $result=@()
    foreach($f in $files) {
        if($f.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked credential files are not supported.'}
        $a=Read-Auth $f.FullName
        if($seen.ContainsKey($a.Key)){throw 'Duplicate account profiles found. Keep one file per account in the local profiles folder.'}
        $seen[$a.Key]=$true
        Protect-Path $f.FullName
        $dir=Join-Path (Join-Path $script:Root 'accounts') $a.Key
        [IO.Directory]::CreateDirectory($dir) | Out-Null; Protect-Path $dir
        $path=Join-Path $dir 'auth.json'
        if(!(Test-Path -LiteralPath $path)){Write-Atomic $path $a.Raw}
        $saved=Read-Auth $path
        if($saved.Key -ne $a.Key){throw 'Saved profile identity mismatch. No switch performed.'}
        $result+= [pscustomobject]@{Key=$a.Key;Name=$f.BaseName;Path=$path}
    }
    return $result
}
function Get-DesktopApp {
    $pkg=Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
    if(!$pkg){throw 'OpenAI.Codex desktop package not found.'}
    $app=(Get-AppxPackageManifest $pkg).Package.Applications.Application | Where-Object {$_.Id -eq 'App'} | Select-Object -First 1
    if(!$app -or !(Test-Path -LiteralPath (Join-Path $pkg.InstallLocation $app.Executable))){throw 'Desktop application entry point not found.'}
    return [pscustomobject]@{Directory=$pkg.InstallLocation;Aumid=$pkg.PackageFamilyName+'!'+$app.Id}
}
function Get-AppProcesses($App) {
    $local=Join-Path $env:LOCALAPPDATA 'OpenAI\Codex'
    $plugin=Join-Path $script:AuthHome 'plugins\.plugin-appserver'
    @(Get-Process | Where-Object {
        $p=$_.Path
        $_.ProcessName -in 'ChatGPT','codex' -and $p -and ($p.StartsWith($App.Directory+'\',[StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($local+'\',[StringComparison]::OrdinalIgnoreCase) -or $p.StartsWith($plugin+'\',[StringComparison]::OrdinalIgnoreCase))
    })
}
function Close-Desktop($App) {
    $known=@(Get-AppProcesses $App | ForEach-Object {$_.Id})
    if(@(Get-Process codex -ErrorAction SilentlyContinue | Where-Object {$_.Id -notin $known}).Count){throw 'Another Codex CLI process is running. Close it before switching.'}
    foreach($p in @(Get-AppProcesses $App)){if($p.MainWindowHandle -ne 0){$null=$p.CloseMainWindow()}}
    $deadline=[DateTime]::UtcNow.AddSeconds(12)
    while(@(Get-AppProcesses $App).Count -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 250}
    $stopErrors=@()
    foreach($p in @(Get-AppProcesses $App)){
        try{Stop-Process -Id $p.Id -Force -ErrorAction Stop}catch{
            if(Get-Process -Id $p.Id -ErrorAction SilentlyContinue){$stopErrors+=@{id=$p.Id;name=$p.ProcessName;error=$_.Exception.Message}}
        }
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    while(@(Get-AppProcesses $App).Count -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 250}
    $remaining=@(Get-AppProcesses $App)
    if($remaining.Count){
        Write-Atomic (Join-Path $script:Root 'shutdown-diagnostic.json') (@{remaining=@($remaining|Select-Object Id,ProcessName,Path);stopErrors=$stopErrors}|ConvertTo-Json -Depth 4)
        throw ('Codex authentication processes did not exit: '+(($remaining.ProcessName|Select-Object -Unique)-join ', ')+'. Authentication was not changed. Details are in shutdown-diagnostic.json.')
    }
    # Independent CLI clients may also refresh this shared auth file. Do not kill them.
    if(@(Get-Process codex -ErrorAction SilentlyContinue).Count){throw 'Another Codex CLI process is running. Close it before switching.'}
}
function Open-Desktop($App) {
    Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList ('shell:AppsFolder\'+$App.Aumid) -WindowStyle Hidden
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while([DateTime]::UtcNow -lt $deadline){if(@(Get-AppProcesses $App).Count){return};Start-Sleep -Milliseconds 300}
    throw 'Authentication was switched, but the desktop app did not start. Open Codex from Start.'
}
function Assert-FileStore {
    foreach($file in @('config.toml','requirements.toml','managed_config.toml')) {
        $path=Join-Path $script:AuthHome $file
        if(Test-Path -LiteralPath $path){
            $text=[IO.File]::ReadAllText($path)
            if($text -match '(?m)^\s*cli_auth_credentials_store\s*=\s*["''](keyring|auto|ephemeral)["'']'){throw 'This configuration does not explicitly use file authentication. Set up file storage before switching.'}
        }
    }
}
function Invoke-Switcher {
    [IO.Directory]::CreateDirectory($script:Root) | Out-Null; Protect-Path $script:Root
    $lock=$null
    try {
        try {$lock=[IO.File]::Open((Join-Path $script:Root 'switch.lock'),'OpenOrCreate','ReadWrite','None')}catch{throw 'Another switcher or setup is already running.'}
        Assert-FileStore
        $app=Get-DesktopApp
        $current=if(Test-Path -LiteralPath $script:Active){Read-Auth $script:Active}else{$null}
        if(!$current -and $Mode -in @('Capture','Register')){throw 'Sign into Codex first, or use Add account in Codex Manager.'}
        if($Mode -eq 'Capture') {
            $profiles=@(Get-Profiles)
            $known=@($profiles | Where-Object {$_.Key -eq $current.Key})
            if($known.Count){throw 'This account is already saved. Use Register to confirm updating its credentials with a backup.'}
            $again=Read-Auth $script:Active
            if($again.Key -ne $current.Key -or $again.Raw -cne $current.Raw){throw 'Authentication changed while capturing. Run Capture again.'}
            Write-Atomic (Join-Path $script:Source ('Account-'+$current.Key.Substring(0,12)+'.txt')) $current.Raw
            $null=@(Get-Profiles)
            Save-State $current.Key
            Write-Host 'Saved the current newly signed-in account without closing Codex. Existing profiles were not overwritten.'
            return
        }
        $profiles=@(Get-Profiles)
        if($Mode -eq 'Switch' -and !$current){
            $chosen=@(if($TargetKey){$profiles|Where-Object Key -eq $TargetKey}else{$profiles|Select-Object -First 1})
            if($chosen.Count -ne 1){throw 'Add an account in Codex Manager first, then select Switch to this account.'}
            if((Test-NativeSession $chosen[0]) -ne 'usable'){throw 'This account needs Reconnect before it can be activated.'}
            $target=Read-Auth $chosen[0].Path
            Close-Desktop $app
            try{
                if(Test-Path -LiteralPath $script:Active){throw 'A login appeared while switching. It was preserved; retry from the dashboard.'}
                [IO.Directory]::CreateDirectory($script:AuthHome)|Out-Null
                Write-Atomic $script:Active $target.Raw
                try{Save-State $target.Key}catch{
                    if((Read-Auth $script:Active).Raw -ceq $target.Raw){Remove-Item -LiteralPath $script:Active -Force}
                    throw
                }
            }finally{Open-Desktop $app}
            Write-Host 'Saved account activated. Codex restarted.'
            return
        }
        $statePath=Join-Path $script:Root 'state.json'; $journalPath=Join-Path $script:Root 'pending.json'
        $match=@($profiles | Where-Object {$_.Key -eq $current.Key})
        if($match.Count -ne 1 -and $Mode -ne 'Register'){throw 'Current Codex account is not saved in this manager. Add or reconnect it before switching.'}
        if(Test-Path -LiteralPath $journalPath) {
            $journal=[IO.File]::ReadAllText($journalPath) | ConvertFrom-Json
            if($current.Key -notin @($journal.from,$journal.to)){throw 'Interrupted switch identity mismatch. Stop and inspect the local profiles.'}
            Save-State $current.Key
            Remove-Item -LiteralPath $journalPath
            Write-Host 'Recovered interrupted switch from the actual active identity. Run the switcher again.'
            Open-Desktop $app
            return
        }
        if($Mode -eq 'Check'){Write-Host "Validated $($profiles.Count) distinct profiles; current account is registered. No switch performed.";return}
        if($Mode -eq 'Setup') {
            Save-State $current.Key
            Write-Host "Setup complete: $($profiles.Count) accounts. Rotation follows filename order. No app closed or authentication replaced."
            return
        }
        if($Mode -eq 'Register') {
            Write-Host "Register refreshes the saved credentials for the account you are currently signed into."
            if((Read-Host 'Type SAVE to confirm') -cne 'SAVE'){return}
            Close-Desktop $app
            try {
                $latest=Read-Auth $script:Active
                if($latest.Key -ne $current.Key){throw 'Account changed during registration. No profile overwritten.'}
                if($match.Count -eq 0){
                    Write-Atomic (Join-Path $script:Source ('Account-'+$latest.Key.Substring(0,12)+'.txt')) $latest.Raw
                    $profiles=@(Get-Profiles)
                    $match=@($profiles | Where-Object {$_.Key -eq $latest.Key})
                }
                Write-Atomic ($match[0].Path+'.previous') ([IO.File]::ReadAllText($match[0].Path))
                Write-Atomic $match[0].Path $latest.Raw; Save-State $latest.Key
                $invalidPath=Join-Path (Split-Path $match[0].Path -Parent) 'invalid-session.json'
                if(Test-Path -LiteralPath $invalidPath){Remove-Item -LiteralPath $invalidPath}
            } finally {Open-Desktop $app}
            Write-Host 'Current account credentials saved. Other accounts preserved.'; return
        }
        if($profiles.Count -lt 2){throw 'Add another account in Codex Manager before rotating accounts.'}
        if(!(Test-Path -LiteralPath $statePath)){Save-State $current.Key}
        $state=[IO.File]::ReadAllText($statePath) | ConvertFrom-Json
        if($state.active -ne $current.Key){throw 'Active account differs from switcher state. Run Setup to register the actual current identity.'}
        $index=0; for($i=0;$i -lt $profiles.Count;$i++){if($profiles[$i].Key -eq $current.Key){$index=$i}}
        if($TargetKey -and $TargetKey -eq $current.Key){Write-Host 'This account is already active.';return}
        if($TargetKey -and !@($profiles|Where-Object {$_.Key -eq $TargetKey}).Count){throw 'Selected account is no longer registered.'}
        $next=$null; $nextIndex=-1
        for($offset=1;$offset -lt $profiles.Count;$offset++){
            $candidateIndex=($index+$offset)%$profiles.Count
            $candidate=$profiles[$candidateIndex]
            if($TargetKey -and $candidate.Key -ne $TargetKey){continue}
            $invalidPath=Join-Path (Split-Path $candidate.Path -Parent) 'invalid-session.json'
            if(Test-Path -LiteralPath $invalidPath){Write-Host "Skipping revoked session: $($candidate.Name). Saved profile retained.";continue}
            if(!(Get-Command Test-NativeSession -ErrorAction SilentlyContinue)){throw 'Native-Session.ps1 is missing. Reinstall the helper before switching.'}
            if((Test-NativeSession $candidate) -eq 'rejected'){
                Write-Atomic $invalidPath (@{reason='rejected';authError=$script:LastNativeAuthReason;checked=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json)
                Write-Host "Skipping rejected session: $($candidate.Name). Saved profile retained.";continue
            }
            $next=$candidate; $nextIndex=$candidateIndex; break
        }
        if(!$next){throw 'No other usable saved session is available. Your current login is still running. Revoked sessions require one fresh login; use Register to save it.'}
        $target=Read-Auth $next.Path
        try {Close-Desktop $app} catch {Open-Desktop $app;throw}
        $committed=$false; $journalWritten=$false; $latest=$null
        try {
            $latest=Read-Auth $script:Active
            if($latest.Key -ne $current.Key){throw 'Current identity changed during shutdown. No credentials copied.'}
            if(@(Get-AppProcesses $app).Count){throw 'Codex restarted during switching. No authentication changed.'}
            Write-Atomic ($match[0].Path+'.previous') ([IO.File]::ReadAllText($match[0].Path))
            Write-Atomic $match[0].Path $latest.Raw
            Write-Atomic (Join-Path $script:Root 'previous-auth.json') $latest.Raw
            Write-Atomic $journalPath (@{from=$current.Key;to=$target.Key} | ConvertTo-Json); $journalWritten=$true
            Write-Atomic $script:Active $target.Raw
            Save-State $target.Key
            $committed=$true
            Remove-Item -LiteralPath $journalPath
        } catch {
            if($journalWritten -and !$committed) {
                # Roll back only our own replacement, never an unexpected external login.
                $now=Read-Auth $script:Active
                if($now.Raw -ceq $target.Raw -or $now.Raw -ceq $latest.Raw){
                    Write-Atomic $script:Active $latest.Raw; Save-State $latest.Key
                    Remove-Item -LiteralPath $journalPath -ErrorAction SilentlyContinue
                }
            }
            throw
        } finally {Open-Desktop $app}
        Write-Host "Activated $($next.Name) (Account $($nextIndex+1) of $($profiles.Count)). Saved session passed Codex authentication checks; desktop restarted."
    } finally {if($lock){$lock.Dispose()}}
}
if(!$Library) {
    try {Invoke-Switcher;exit 0} catch {Write-Host ('Stopped: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
}
