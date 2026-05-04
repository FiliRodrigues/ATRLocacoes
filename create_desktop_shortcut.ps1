$ErrorActionPreference = 'Stop'

function New-DesktopShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [string]$Arguments = '',
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [string]$IconLocation = ''
    )

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath ("$Name.lnk")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 7

    if ($IconLocation) {
        $shortcut.IconLocation = $IconLocation
    }

    $shortcut.Save()
    return $shortcutPath
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$webLauncher = Join-Path $projectRoot 'run_atr_web_hidden.vbs'
$windowsLauncher = Join-Path $projectRoot 'run_atr_windows_hidden.vbs'
$iconPath = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
$wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
$webArguments = "//B //Nologo `"$webLauncher`""
$windowsArguments = "//B //Nologo `"$windowsLauncher`""

foreach ($requiredPath in @($webLauncher, $windowsLauncher, $iconPath, $wscriptPath)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Arquivo necessario nao encontrado em $requiredPath"
    }
}

$created = @()
$created += New-DesktopShortcut -Name 'ATR Local' -TargetPath $wscriptPath -Arguments $webArguments -WorkingDirectory $projectRoot -Description 'Abre o ATR web local sem mostrar terminal' -IconLocation $iconPath
$created += New-DesktopShortcut -Name 'ATR Desktop' -TargetPath $wscriptPath -Arguments $windowsArguments -WorkingDirectory $projectRoot -Description 'Abre o ATR Windows nativo e recompila quando houver atualizacoes' -IconLocation $iconPath

$created | ForEach-Object {
    Write-Output "Atalho criado/atualizado em: $_"
}