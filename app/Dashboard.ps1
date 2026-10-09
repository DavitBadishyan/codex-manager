param([switch]$SmokeTest,[switch]$VerifyRefresh,[switch]$VerifyZoom)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace CodexManager {
 public static class Native {
  [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string id);
  [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd,int attribute,ref int value,int size);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd,int attribute,out int value,int size);
 }
}
"@
$script:AppIdentityResult=[CodexManager.Native]::SetCurrentProcessExplicitAppUserModelID('CodexManager.LocalDesktop')
$script:Root = if($env:CODEX_MANAGER_ROOT){[IO.Path]::GetFullPath($env:CODEX_MANAGER_ROOT)}elseif(Test-Path -LiteralPath (Join-Path $PSScriptRoot '.codex-manager-install')){$PSScriptRoot}else{Join-Path $env:LOCALAPPDATA 'CodexManager'}
[IO.Directory]::CreateDirectory($script:Root)|Out-Null
$script:Cache = Join-Path $script:Root 'dashboard.json'
$script:Worker = $null
$script:Stamp = ''
$script:State = $null
$script:Countdowns = @()
$script:SwitchButtons = @()
$script:Operation = ''
$script:OperationStarted = [DateTime]::MinValue
$script:CancelRequested = $false
$script:Zone = [TimeZoneInfo]::Local

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex Manager" Width="1120" Height="790" MinWidth="430" MinHeight="530" WindowStartupLocation="CenterScreen" WindowState="Maximized" Background="#111419" Foreground="#E8EDF4" FontFamily="Segoe UI" UseLayoutRounding="True">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Foreground" Value="#D1E0F5"/><Setter Property="Background" Value="#293E5A"/><Setter Property="Padding" Value="22,13"/><Setter Property="FontSize" Value="15"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Surface" CornerRadius="7" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.85"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="Surface" Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="ScrollBar">
   <Setter Property="Width" Value="12"/><Setter Property="Background" Value="Transparent"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
    <Grid Background="Transparent"><Track x:Name="PART_Track" Orientation="Vertical" IsDirectionReversed="True" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{Binding Value, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" ViewportSize="{TemplateBinding ViewportSize}">
     <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
     <Track.Thumb><Thumb MinHeight="35"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border x:Name="Handle" Background="#4A5668" CornerRadius="4" Margin="3,0"/><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Handle" Property="Background" Value="#7399C4"/></Trigger><Trigger Property="IsDragging" Value="True"><Setter TargetName="Handle" Property="Background" Value="#8AB4E7"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
     <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
    </Track></Grid>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Grid x:Name="DashboardRoot" Margin="30,24,24,20"><Grid.LayoutTransform><ScaleTransform x:Name="UiZoom" ScaleX="1" ScaleY="1"/></Grid.LayoutTransform><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="CODEX MANAGER" FontSize="13" FontWeight="Bold" Foreground="#729ED4"/><TextBlock Text="Your accounts" FontSize="38" FontWeight="SemiBold" Margin="0,6,0,4"/><TextBlock Text="Usage, reset times and one-click switching." FontSize="16" Foreground="#98A3B3" TextWrapping="Wrap"/><TextBlock Text="Add or reconnect here without signing out of Codex." FontSize="13" Foreground="#729ED4" TextWrapping="Wrap" Margin="0,7,8,0"/></StackPanel><WrapPanel x:Name="Actions" Grid.Column="1" Width="320" VerticalAlignment="Center" Margin="12,0,0,0"><Button x:Name="AddAccount" Content="Add account" Background="#527FB9" Foreground="#FFFFFF" Margin="0,0,8,6"/><Button x:Name="Refresh" Content="Refresh usage" Background="#272E39" Foreground="#D0D9E7" Margin="0,0,0,6"/></WrapPanel></Grid>
  <Border Grid.Row="1" Margin="0,22,6,17" Padding="13,10" Background="#20262F" CornerRadius="7"><DockPanel><Button x:Name="CancelSignIn" DockPanel.Dock="Right" Content="Cancel sign-in" Visibility="Collapsed" Background="#35303A" Foreground="#DDC1B9" Padding="12,6" Margin="12,0,0,0"/><TextBlock x:Name="Status" Text="Loading saved accounts..." Foreground="#BAC4D2" TextWrapping="Wrap" FontSize="14" VerticalAlignment="Center"/></DockPanel></Border>
  <ScrollViewer x:Name="AccountScroll" Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><WrapPanel x:Name="Cards"/></ScrollViewer>
  <DockPanel Grid.Row="3" Margin="0,15,0,0"><TextBlock x:Name="ZoomLabel" DockPanel.Dock="Right" Text="Zoom 100%" Foreground="#98A3B3" FontSize="13" Margin="16,0,0,0" ToolTip="Ctrl + wheel or Ctrl + / - to zoom. Ctrl + 0 resets."/><TextBlock Text="Reset times use your computer timezone   |   Switching restarts Codex" Foreground="#818D9E" FontSize="13" TextWrapping="Wrap"/></DockPanel>
 </Grid>
</Window>
'@
$reader = New-Object Xml.XmlNodeReader $xaml
$script:Window = [Windows.Markup.XamlReader]::Load($reader)
$iconPath=Join-Path $PSScriptRoot 'CodexManager.ico'
if(Test-Path -LiteralPath $iconPath){$script:Window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath)}
$script:Window.Add_SourceInitialized({
 $hwnd=[Windows.Interop.WindowInteropHelper]::new($script:Window).Handle
 $dark=1;$result=[CodexManager.Native]::DwmSetWindowAttribute($hwnd,20,[ref]$dark,4)
 if($result -ne 0){$null=[CodexManager.Native]::DwmSetWindowAttribute($hwnd,19,[ref]$dark,4)}
 $caption=0x191411;$text=0xF4EDE8
 $null=[CodexManager.Native]::DwmSetWindowAttribute($hwnd,35,[ref]$caption,4)
 $null=[CodexManager.Native]::DwmSetWindowAttribute($hwnd,36,[ref]$text,4)
})
$script:Cards = $script:Window.FindName('Cards')
$script:Status = $script:Window.FindName('Status')
$script:Refresh = $script:Window.FindName('Refresh')
$script:AddAccount = $script:Window.FindName('AddAccount')
$script:Actions = $script:Window.FindName('Actions')
$script:CancelSignIn = $script:Window.FindName('CancelSignIn')
$script:AccountScroll = $script:Window.FindName('AccountScroll')

$script:ZoomFactor=1.0
$script:UiZoom=$script:Window.FindName('UiZoom')
$script:ZoomLabel=$script:Window.FindName('ZoomLabel')
function Set-Zoom([double]$Value) {
 $script:ZoomFactor=[math]::Round([math]::Max(0.6,[math]::Min(1.8,$Value)),2)
 $script:UiZoom.ScaleX=$script:ZoomFactor;$script:UiZoom.ScaleY=$script:ZoomFactor
 $script:ZoomLabel.Text=('Zoom {0:0}%' -f ($script:ZoomFactor*100))
 $script:Window.UpdateLayout();Resize-Cards
}
function Handle-ZoomKey($EventArgs,$Modifiers=[Windows.Input.Keyboard]::Modifiers) {
 if(!($Modifiers -band [Windows.Input.ModifierKeys]::Control)){return}
 if($EventArgs.Key -in @([Windows.Input.Key]::OemPlus,[Windows.Input.Key]::Add)){Set-Zoom ($script:ZoomFactor+0.1);$EventArgs.Handled=$true}
 elseif($EventArgs.Key -in @([Windows.Input.Key]::OemMinus,[Windows.Input.Key]::Subtract)){Set-Zoom ($script:ZoomFactor-0.1);$EventArgs.Handled=$true}
 elseif($EventArgs.Key -in @([Windows.Input.Key]::D0,[Windows.Input.Key]::NumPad0)){Set-Zoom 1;$EventArgs.Handled=$true}
}
$script:Window.Add_PreviewKeyDown({param($sender,$eventArgs) Handle-ZoomKey $eventArgs})
function Handle-ZoomWheel($EventArgs,$Modifiers=[Windows.Input.Keyboard]::Modifiers) {
 if($Modifiers -band [Windows.Input.ModifierKeys]::Control){
  Set-Zoom ($script:ZoomFactor+([math]::Sign($EventArgs.Delta)*0.1));$EventArgs.Handled=$true
 }
}
$script:Window.Add_PreviewMouseWheel({param($sender,$eventArgs) Handle-ZoomWheel $eventArgs})
function Brush([string]$Color) { return [Windows.Media.BrushConverter]::new().ConvertFromString($Color) }
function Text([string]$Value, [double]$Size=12, [string]$Color='#98A3B3') {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text=$Value; $t.FontSize=$Size*1.2; $t.Foreground=Brush $Color; $t.TextWrapping='Wrap'
    return $t
}
function Add-Text($Panel, [string]$Value, [double]$Size=12, [string]$Color='#98A3B3', [string]$Margin='0,0,0,0') {
    $t=Text $Value $Size $Color; $t.Margin=[Windows.ThicknessConverter]::new().ConvertFromString($Margin); $null=$Panel.Children.Add($t); return $t
}
function Format-Date($Value) {
    try {
        if($Value -is [ValueType] -or "$Value" -match '^\d{10,13}$') {
            $n=[double]$Value; if($n -gt 100000000000){$n=$n/1000}
            $d=[DateTimeOffset]::FromUnixTimeSeconds([long]$n).UtcDateTime
        } else {$d=[DateTimeOffset]::Parse("$Value").UtcDateTime}
        return [TimeZoneInfo]::ConvertTimeFromUtc($d,$script:Zone).ToString('dd MMM yyyy, HH:mm')
    } catch {return 'Unavailable'}
}
function Add-Window($Panel, [string]$Label, $Usage) {
    $null=Add-Text $Panel $Label 12 '#BAC4D2' '0,12,0,7'
    if($null -eq $Usage -or $null -eq $Usage.usedPercent) {
        $null=Add-Text $Panel 'Usage unavailable' 15 '#7F8B9D'
        return
    }
    $used=[math]::Max(0,[math]::Min(100,[double]$Usage.usedPercent)); $left=100-$used
    $null=Add-Text $Panel ('{0:0.#}% remaining' -f $left) 22 '#E2E8F2'
    $bar=New-Object Windows.Controls.ProgressBar
    $bar.Height=8;$bar.Margin='0,8,0,8';$bar.Minimum=0;$bar.Maximum=100;$bar.Value=$left
    $bar.Background=Brush '#303845';$bar.Foreground=Brush $(if($left -lt 15){'#D5A16C'}else{'#6992C7'});$bar.BorderThickness=0
    $null=$Panel.Children.Add($bar)
    if($null -ne $Usage.resetsAt) {
        $null=Add-Text $Panel ('Resets ' + (Format-Date $Usage.resetsAt)) 11
        $counter=Add-Text $Panel '' 11 '#729ED4' '0,3,0,0'
        $script:Countdowns += @{Control=$counter;Epoch=$Usage.resetsAt}
    } else {$null=Add-Text $Panel 'Reset time unavailable' 11}
}
function Render-Accounts {
    $script:Cards.Children.Clear();$script:Countdowns=@();$script:SwitchButtons=@()
    $rows=@($script:State.accounts)
    if(!$rows.Count -or $null -eq $rows[0]) {$null=Add-Text $script:Cards 'No saved accounts yet. Choose Add account to sign in and save your first account.' 16 '#BAC4D2';return}
    foreach($account in $rows) {
        $card=New-Object Windows.Controls.Border
        $card.Width=322;$card.Margin='0,0,16,16';$card.Padding=24;$card.CornerRadius=10
        $card.Background=Brush '#1B2028';$card.BorderThickness=1
        $card.BorderBrush=Brush $(if($account.active){'#648FC7'}else{'#333C49'})
        $panel=New-Object Windows.Controls.StackPanel;$card.Child=$panel
        $tag=if($account.active){'ACTIVE ACCOUNT'}else{'SAVED ACCOUNT'}
        $null=Add-Text $panel $tag 10 $(if($account.active){'#729ED4'}else{'#7F8B9D'})
        $name=if($account.name){$account.name}else{'Codex account'}
        $title=Add-Text $panel $name 21 '#EDF1F7' '0,6,0,3';$title.FontWeight='SemiBold'
        $null=Add-Text $panel $(if($account.email){$account.email}else{'Email unavailable'}) 12
        $plan=if($account.plan){$account.plan.ToString().ToUpperInvariant()}else{'UNKNOWN PLAN'}
        $null=Add-Text $panel ($plan+'  /  '+$account.status) 11 '#BAC4D2' '0,8,0,0'
        $limits=$account.limits.rateLimits
        if(!$limits -and $account.limits.rateLimitsByLimitId) {
            $entries=@($account.limits.rateLimitsByLimitId.PSObject.Properties)
            $chosen=$entries|Where-Object {$_.Name -eq 'codex'}|Select-Object -First 1
            if(!$chosen){$chosen=$entries|Select-Object -First 1};if($chosen){$limits=$chosen.Value}
        }
        $short=$null;$weekly=$null
        foreach($w in @($limits.primary,$limits.secondary)) {
            if($null -eq $w){continue}
            if($w.windowDurationMins -eq 300){$short=$w}
            elseif($w.windowDurationMins -eq 10080){$weekly=$w}
        }
        Add-Window $panel '5-HOUR LIMIT' $short
        Add-Window $panel 'WEEKLY LIMIT' $weekly
        $sep=New-Object Windows.Controls.Border;$sep.Height=1;$sep.Background=Brush '#333B47';$sep.Margin='0,12,0,10';$null=$panel.Children.Add($sep)
        $credits=$account.limits.rateLimitResetCredits
        if($null -ne $credits.availableCount){$creditText='{0} available' -f $credits.availableCount}else{$creditText='Unavailable'}
        $null=Add-Text $panel ('Reset credits: '+$creditText) 12 '#BAC4D2'
        if($account.billing){$billingText=$account.billingStatus+': '+(Format-Date $account.billing)}else{$billingText='Subscription date unavailable'}
        $null=Add-Text $panel $billingText 11 '#98A3B3' '0,7,0,0'
        $checkedText=if($account.checked){'Last checked '+(Format-Date $account.checked)}else{'Last checked unavailable'}
        $null=Add-Text $panel $checkedText 10 '#818D9E' '0,7,0,0'
        $button=New-Object Windows.Controls.Button;$button.Margin='0,12,0,0'
        $needsLogin=$account.status -eq 'Sign-in required'
        $button.Tag=@{Key=$account.key;Action=$(if($needsLogin){'Reconnect'}else{'Switch'})}
        $button.Content=if($needsLogin){'Reconnect'}elseif($account.active){'Currently active'}else{'Switch to this account'}
        $button.IsEnabled=($needsLogin -or !$account.active)
        $button.Add_Click({param($sender,$eventArgs) Start-Worker ([string]$sender.Tag.Action) ([string]$sender.Tag.Key)})
        $null=$panel.Children.Add($button);$script:SwitchButtons+=@{Control=$button;Allowed=$button.IsEnabled}
        $null=$script:Cards.Children.Add($card)
    }
    Resize-Cards
    Update-Countdowns
}
function Resize-Cards {
    $script:Actions.Width=if(($script:Window.ActualWidth/$script:ZoomFactor) -lt 750){170}else{320}
    $width=if($script:Cards.ActualWidth -gt 0){$script:Cards.ActualWidth}else{$script:Window.ActualWidth-110}
    $width=[math]::Max(300,$width-22)
    $columns=[math]::Max(1,[math]::Min($script:Cards.Children.Count,[math]::Floor($width/360)))
    $cardWidth=[math]::Max(270,[math]::Floor($width/$columns)-18)
    foreach($card in $script:Cards.Children){if($card -is [Windows.Controls.Border]){$card.Width=$cardWidth}}
}
function Update-Countdowns {
    foreach($item in $script:Countdowns) {
        try {
            $epoch=[double]$item.Epoch;if($epoch -gt 100000000000){$epoch=$epoch/1000}
            $span=[DateTimeOffset]::FromUnixTimeSeconds([long]$epoch)-[DateTimeOffset]::UtcNow
            if($span.TotalSeconds -le 0){$item.Control.Text='Reset time reached - refresh usage'}
            elseif($span.TotalDays -ge 1){$item.Control.Text=('In {0}d {1}h {2}m' -f [int][math]::Floor($span.TotalDays),$span.Hours,$span.Minutes)}
            else{$item.Control.Text=('In {0}h {1}m {2}s' -f [int][math]::Floor($span.TotalHours),$span.Minutes,$span.Seconds)}
        } catch {$item.Control.Text='Countdown unavailable'}
    }
}
function Set-Busy([bool]$Busy) {
    $script:Refresh.IsEnabled=!$Busy
    $script:AddAccount.IsEnabled=!$Busy
    $script:CancelSignIn.Visibility=if($Busy -and $script:Operation -in @('Add','Reconnect')){'Visible'}else{'Collapsed'}
    $script:CancelSignIn.IsEnabled=(!$script:CancelRequested)
    foreach($b in $script:SwitchButtons){$b.Control.IsEnabled=(!$Busy -and $b.Allowed)}
}
function Start-Worker([string]$Action,[string]$Key='') {
    if($script:Worker -and !$script:Worker.HasExited){return}
    $script:Operation=$Action
    $script:CancelRequested=$false
    $script:CancelSignIn.Content='Cancel sign-in'
    $script:Status.Text=switch($Action){
        'Switch' {'Switching account and restarting Codex...'}
        'Add' {'Complete sign-in in your browser to add an account. Your current Codex account stays signed in.'}
        'Reconnect' {'Complete sign-in in your browser using the account you chose to reconnect. Your current Codex account stays signed in.'}
        default {'Refreshing usage for saved accounts...'}
    }
    Set-Busy $true
    $args='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Dashboard-Data.ps1')+'" -Action '+$Action
    if($Key){if($Key -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid account key'};$args+=' -TargetKey '+$Key}
    try {
        if($Action -in @('Switch','Add','Reconnect')) {
            $resultPath=Join-Path $script:Root 'dashboard-action.json'
            if(Test-Path -LiteralPath $resultPath){Remove-Item -LiteralPath $resultPath -Force}
        }
        if($Action -in @('Add','Reconnect')) {
            $cancelPath=Join-Path $script:Root 'login-cancel'
            if(Test-Path -LiteralPath $cancelPath){Remove-Item -LiteralPath $cancelPath -Force}
        }
        $script:OperationStarted=[DateTime]::UtcNow
        $script:Worker=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $args -WindowStyle Hidden -PassThru
    } catch {$script:Status.Text='Could not start account operation: '+$_.Exception.Message;Set-Busy $false}
}
function Read-Cache {
    if(Test-Path -LiteralPath $script:Cache) {
        try {
            $raw=[IO.File]::ReadAllText($script:Cache)
            if($raw -ne $script:Stamp){
                $script:State=$raw|ConvertFrom-Json;$script:Stamp=$raw;Render-Accounts
                if(!$script:Worker){
                    $script:Status.Text=if($script:State.loading){'Refreshing usage for saved accounts...'}else{'Usage updated. '+@($script:State.accounts).Count+' saved accounts.'}
                }
            }
        } catch {$script:Status.Text='Waiting for account data...'}
    }
}
function Save-VerificationImage([string]$Path) {
    $bmp=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$script:Window.ActualWidth),([int]$script:Window.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($script:Window)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $stream=[IO.File]::Create($Path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
function Key-Fingerprint($Key) {
    if([string]::IsNullOrWhiteSpace([string]$Key)){return '<empty>'}
    $value=[string]$Key
    return $value.Substring(0,[math]::Min(12,$value.Length))
}
$script:Refresh.Add_Click({Start-Worker 'Refresh'})
$script:AddAccount.Add_Click({Start-Worker 'Add'})
$script:CancelSignIn.Add_Click({
    try {
        [IO.File]::WriteAllText((Join-Path $script:Root 'login-cancel'),'')
        $script:CancelRequested=$true
        $script:CancelSignIn.IsEnabled=$false
        $script:CancelSignIn.Content='Cancelling...'
        $script:Status.Text='Cancelling browser sign-in...'
    } catch {$script:Status.Text='Could not cancel sign-in: '+$_.Exception.Message}
})
$script:Timer=New-Object Windows.Threading.DispatcherTimer
$script:Timer.Interval=[TimeSpan]::FromSeconds(1)
$script:Timer.Add_Tick({
    Read-Cache;Update-Countdowns
    if($script:Worker) {
        if(!$script:Worker.HasExited){Set-Busy $true;return}
        $exitCode=$script:Worker.ExitCode
        $script:Worker.Dispose();$script:Worker=$null
        if($script:Operation -in @('Switch','Add','Reconnect')) {
            $resultPath=Join-Path $script:Root 'dashboard-action.json'
            try {
                $resultFile=Get-Item -LiteralPath $resultPath
                if($resultFile.LastWriteTimeUtc -lt $script:OperationStarted){throw 'Stale operation result'}
                $r=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
                if(!$r.ok){$script:Status.Text=$script:Operation+' failed: '+$r.error;Set-Busy $false;return}
                if($exitCode -ne 0){throw ('Account worker exited with code '+$exitCode)}
            }catch{$script:Status.Text=$script:Operation+' could not be confirmed. Refresh to verify the account.';Set-Busy $false;return}
            Start-Worker 'Refresh';return
        }
        $errorPath=Join-Path $script:Root 'dashboard-error.json'
        if(Test-Path $errorPath){try{$script:Status.Text=(Get-Content $errorPath -Raw|ConvertFrom-Json).error}catch{}}
        else {$script:Status.Text='Usage updated. '+@($script:State.accounts).Count+' saved accounts.'}
    }
    Set-Busy ([bool]$script:State.loading)
})
$script:Window.Add_SizeChanged({Resize-Cards})
$script:Window.Add_Closed({$script:Timer.Stop()})
$script:Window.Add_ContentRendered({
    Read-Cache
    if($VerifyRefresh){
        $script:VerifyBaselineLoaded=($null -ne $script:State -and @($script:State.accounts).Count -gt 0)
        $script:VerifyCachePresent=Test-Path -LiteralPath $script:Cache
        $script:VerifyExpected=@($script:State.accounts|ForEach-Object {$_.key})
        $script:VerifyStarted=[DateTime]::UtcNow
        $script:Refresh.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $script:VerifyLaunched=($null -ne $script:Worker)
        $script:VerifyTimer=New-Object Windows.Threading.DispatcherTimer
        $script:VerifyTimer.Interval=[TimeSpan]::FromSeconds(1)
        $script:VerifyTimer.Add_Tick({
            $elapsed=([DateTime]::UtcNow-$script:VerifyStarted).TotalSeconds
            if($script:Worker -and $elapsed -lt 120){return}
            $script:VerifyTimer.Stop();Read-Cache
            $rows=@($script:State.accounts)
            $fresh=@($rows|Where-Object {try{[DateTimeOffset]::Parse($_.checked).UtcDateTime -ge $script:VerifyStarted}catch{$false}})
            $connected=@($rows|Where-Object {$_.status -eq 'Connected' -and $null -ne $_.limits})
            $keys=@($rows|ForEach-Object {$_.key})
            $missing=@($script:VerifyExpected|Where-Object {$_ -notin $keys})
            $out=Join-Path $PSScriptRoot 'outputs';[IO.Directory]::CreateDirectory($out)|Out-Null
            $script:Window.UpdateLayout();Resize-Cards;$script:Window.UpdateLayout()
            $positions=@($script:Cards.Children|ForEach-Object {$_.TranslatePoint([Windows.Point]::new(0,0),$script:Cards).Y})
            $buttonsVisible=$true
            foreach($item in $script:SwitchButtons){$p=$item.Control.TranslatePoint([Windows.Point]::new(0,0),$script:AccountScroll);if(($p.Y+$item.Control.ActualHeight) -gt $script:AccountScroll.ActualHeight){$buttonsVisible=$false}}
            Save-VerificationImage (Join-Path $out 'dashboard-refresh-default.png')
            $script:Window.Width=480;$script:Window.Height=650;$script:Window.UpdateLayout();Resize-Cards;$script:Window.UpdateLayout()
            Save-VerificationImage (Join-Path $out 'dashboard-refresh-small-top.png')
            $script:AccountScroll.ScrollToEnd();$script:Window.UpdateLayout()
            Save-VerificationImage (Join-Path $out 'dashboard-refresh-small-bottom.png')
            $report=[ordered]@{
                ok=($script:VerifyLaunched -and !$script:Worker -and !$script:State.loading -and $rows.Count -gt 0 -and $fresh.Count -eq $rows.Count -and $connected.Count -eq $rows.Count -and $missing.Count -eq 0)
                handler='Refresh.RaiseEvent(Button.ClickEvent)';workerLaunched=$script:VerifyLaunched
                accounts=$rows.Count;freshChecked=$fresh.Count;missingAccounts=$missing.Count;loading=[bool]$script:State.loading
                baselineLoaded=$script:VerifyBaselineLoaded;cachePresentAtStart=$script:VerifyCachePresent
                expectedCount=$script:VerifyExpected.Count
                expectedKeyFingerprints=@($script:VerifyExpected|ForEach-Object {Key-Fingerprint $_})
                returnedKeyFingerprints=@($keys|ForEach-Object {Key-Fingerprint $_})
                missingKeyFingerprints=@($missing|ForEach-Object {Key-Fingerprint $_})
                connectedWithUsage=$connected.Count;refreshStatuses=@($rows|ForEach-Object {$_.status})
                defaultAllCardsSameRow=(@($positions|Select-Object -Unique).Count -eq 1);defaultAllButtonsVisible=$buttonsVisible
                actionButtons=@($script:SwitchButtons|ForEach-Object {$_.Control.Content})
                smallViewportCanScroll=($script:AccountScroll.ScrollableHeight -gt 0);smallViewportAtBottom=($script:AccountScroll.VerticalOffset -ge $script:AccountScroll.ScrollableHeight-1)
                seconds=[math]::Round($elapsed,1);updated=$script:State.updated
            }
            [IO.File]::WriteAllText((Join-Path $out 'dashboard-refresh-verification.json'),($report|ConvertTo-Json -Depth 5))
            $script:Window.Close()
        });$script:VerifyTimer.Start()
    }
    elseif(!$SmokeTest -and !$VerifyZoom){Start-Worker 'Refresh'}
    else {
        $script:SmokeTimer=New-Object Windows.Threading.DispatcherTimer
        $script:SmokeTimer.Interval=[TimeSpan]::FromSeconds(3)
        $script:SmokeTimer.Add_Tick({
            $script:SmokeTimer.Stop()
            $out=Join-Path $script:Root 'outputs';[IO.Directory]::CreateDirectory($out)|Out-Null
            if($VerifyZoom){
                $checks=@()
                foreach($key in @('OemPlus','Add')){Set-Zoom 1;$e=[pscustomobject]@{Key=[Windows.Input.Key]::$key;Handled=$false};Handle-ZoomKey $e ([Windows.Input.ModifierKeys]::Control);$checks+=($e.Handled -and $script:ZoomFactor -eq 1.1)}
                foreach($key in @('OemMinus','Subtract')){Set-Zoom 1;$e=[pscustomobject]@{Key=[Windows.Input.Key]::$key;Handled=$false};Handle-ZoomKey $e ([Windows.Input.ModifierKeys]::Control);$checks+=($e.Handled -and $script:ZoomFactor -eq 0.9)}
                foreach($key in @('D0','NumPad0')){Set-Zoom 1.4;$e=[pscustomobject]@{Key=[Windows.Input.Key]::$key;Handled=$false};Handle-ZoomKey $e ([Windows.Input.ModifierKeys]::Control);$checks+=($e.Handled -and $script:ZoomFactor -eq 1)}
                foreach($delta in @(120,-120)){Set-Zoom 1;$e=[pscustomobject]@{Delta=$delta;Handled=$false};Handle-ZoomWheel $e ([Windows.Input.ModifierKeys]::Control);$checks+=($e.Handled -and $script:ZoomFactor -eq $(if($delta -gt 0){1.1}else{0.9}))}
                $e=[pscustomobject]@{Delta=120;Handled=$false};Set-Zoom 1;Handle-ZoomWheel $e ([Windows.Input.ModifierKeys]::None);$checks+=(!$e.Handled -and $script:ZoomFactor -eq 1)
                Set-Zoom 99;$checks+=($script:ZoomFactor -eq 1.8);Set-Zoom 0;$checks+=($script:ZoomFactor -eq 0.6)
                Set-Zoom 1.3;$script:Window.UpdateLayout();$script:AccountScroll.ScrollToEnd();$script:Window.UpdateLayout()
                Save-VerificationImage (Join-Path $out 'zoom-130-scroll.png')
                $checks+=($script:UiZoom.ScaleX -eq 1.3 -and $script:UiZoom.ScaleY -eq 1.3)
                $scrollWorks=($script:AccountScroll.ScrollableHeight -gt 0 -and $script:AccountScroll.VerticalOffset -ge $script:AccountScroll.ScrollableHeight-1)
                Set-Zoom 1;$script:AccountScroll.ScrollToTop();$script:Window.UpdateLayout()
                [IO.File]::WriteAllText((Join-Path $out 'zoom-verification.json'),(@{ok=(@($checks|Where-Object {!$_}).Count -eq 0);checks=$checks.Count;scrollAtZoomWorks=$scrollWorks;resetZoom=$script:ZoomFactor;maximized=($script:Window.WindowState -eq 'Maximized')}|ConvertTo-Json))
            }
            $bmp=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$script:Window.ActualWidth),([int]$script:Window.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
            $bmp.Render($script:Window)
            $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
            $stream=[IO.File]::Create((Join-Path $out 'dashboard-smoke.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
            [IO.File]::WriteAllText((Join-Path $out 'dashboard-smoke.json'),(@{ok=$true;cards=$script:Cards.Children.Count;time=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json))
            $script:Window.Close()
        });$script:SmokeTimer.Start()
    }
})
$script:Timer.Start()
$null=$script:Window.ShowDialog()
