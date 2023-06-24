$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Definition)

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $Command = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath powershell -Verb RunAs -ArgumentList $Command
        exit
    }
}

foreach ($RegistryPath in @("HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
    foreach ($Item in (Get-ItemProperty $RegistryPath)) {
        if ($Item.PSChildName -eq "QQ") {
            $QQInstallDir = (Split-Path -Parent $Item.UninstallString)
            break
        }
    }
}

if (($null -eq $QQInstallDir) -or ((Test-Path $QQInstallDir) -eq $false)) {
    throw "QQNT installation not found."
}
$QQAppDir = "$QQInstallDir\resources\app"
$QQAppLauncherDir = "$QQAppDir\app_launcher"
$EntryFile = "$QQAppLauncherDir\index.js"
$EntryBackupFile = "$EntryFile.bak"
$PackageJSONFile = "$QQAppDir\package.json"
$QQNTimFlagFile = "$QQAppLauncherDir\qqntim-flag.txt"

if ((Test-Path $EntryBackupFile) -eq $true) {
    Write-Output "Cleaning up old installation..."
    Move-Item $EntryFile $EntryBackupFile -Force
    "" | Set-Content $QQNTimFlagFile -Encoding UTF8 -Force -NoNewline
}

if ((Test-Path $QQNTimFlagFile) -eq $false) {
    throw "QQNTim not installed."
}

if ((Read-Host "Do you want to uninstall QQNTim (y/n)?") -notcontains "y") {
    exit -1
}

if ((Read-Host "Also remove your data (y/n)?") -contains "y") {
    Remove-Item "${env:UserProfile}\.qqntim" -Recurse -Force
}

Write-Output "Killing QQ processes..."
Stop-Process -Name QQ -ErrorAction SilentlyContinue

Write-Output "Removing files..."
Remove-Item "$QQAppLauncherDir\qqntim.js", "$QQAppLauncherDir\qqntim-renderer.js" -Force

Write-Output "Restoring entry..."
Move-Item $EntryFileBackup $EntryFile -Force
Write-Output "Restoring package.json..."
(Get-Content $PackageJSONFile -Raw -Encoding UTF8 -Force) -replace "./app_launcher/qqntim.js", "./app_launcher/index.js" | Set-Content $PackageJSONFile -Encoding UTF8 -Force -NoNewline

Remove-Item $QQNTimFlagFile -Force

Write-Output "Uninstalled successfully."
Pause
