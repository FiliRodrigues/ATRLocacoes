$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\ATR.exe'
$fallbackScript = Join-Path $projectRoot 'run_atr_windows.ps1'

if (-not (Test-Path $exePath)) {
    Write-Host 'ATR.exe ainda nao existe. Executando launcher completo para gerar a build...'
    & $fallbackScript
    exit $LASTEXITCODE
}

Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath)