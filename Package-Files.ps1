$script:AppFiles = @('Account-Login.ps1','Dashboard-Data.ps1','Dashboard.ps1','Native-Session.ps1','Switcher.ps1','CodexManager.ico')
$script:ReleaseFiles = @('Install.cmd','Install.ps1','Uninstall.cmd','Uninstall.ps1','Setup-Common.ps1','Package-Files.ps1','README.md','LICENSE','VERSION','SECURITY.md','CONTRIBUTING.md','docs/USER_GUIDE.md','docs/screenshot.png')
$script:ReleaseFiles += @($script:AppFiles | ForEach-Object { 'app/' + $_ })
$script:ReleaseFiles += @('docs/SWITCH_ACCOUNTS.md','docs/USAGE_LIMITS.md','docs/TROUBLESHOOTING.md','docs/media/quickstart.gif','docs/media/social-preview.png','docs/media/walkthrough.mp4','docs/maintainers/DISCOVERY.md','docs/maintainers/ANNOUNCEMENTS.md')
