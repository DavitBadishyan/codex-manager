$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'Run tests with Windows PowerShell 5.1 (powershell.exe).' }
$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.ps1') + @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'app') -File -Filter '*.ps1') + @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tests') -File -Filter '*.ps1')
foreach ($file in $files) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw "Parse errors in $($file.Name): $($errors.Message -join '; ')" }
}
Write-Host "PASS PowerShell 5.1 parse checks ($($files.Count) scripts)"
foreach ($name in @('Test-Switcher.ps1','Test-Native-Errors.ps1','Test-Isolated-Login.ps1','Test-Install.ps1','Test-First-Run.ps1')) {
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path (Join-Path $PSScriptRoot 'tests') $name)
    if ($LASTEXITCODE -ne 0) { throw "$name failed ($LASTEXITCODE)." }
}
Write-Host 'PASS all tests'
