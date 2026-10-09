$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\app\Native-Session.ps1"
function Check-Error([string]$Message,[string]$Expected){
 $response=@{id=7;error=@{message=$Message}}|ConvertTo-Json -Compress
 $fake=[pscustomobject]@{StandardInput=[IO.StringWriter]::new();StandardOutput=[IO.StringReader]::new($response+[Environment]::NewLine)}
 try{$null=Native-Request $fake 7 'test' @{};throw 'Expected failure'}catch{if($_.Exception.Message -ne $Expected){throw ('Unexpected classification: '+$_.Exception.Message)}}
 Write-Output ('PASS '+$Expected)
}
Check-Error '401 Unauthorized' 'native_auth_check_failed'
Check-Error 'refresh_token_reused' 'saved_session_rejected'
Check-Error 'refresh token was revoked' 'saved_session_rejected'
Check-Error 'refresh_token_expired' 'saved_session_rejected'
$fake=[pscustomobject]@{StandardInput=[IO.StringWriter]::new();StandardOutput=[IO.StringReader]::new('{"id":8,"method":"account/chatgptAuthTokens/refresh","params":{}}')}
try{$null=Native-Request $fake 7 'test' @{};throw 'Expected failure'}catch{if($_.Exception.Message -ne 'active_access_needs_refresh'){throw}}
if($fake.StandardInput.ToString() -notmatch 'Refresh is owned'){throw 'External refresh request did not receive refusal'}
Write-Output 'PASS active account cannot refresh through dashboard'
