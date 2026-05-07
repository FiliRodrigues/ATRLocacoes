$ErrorActionPreference = 'Stop'

function Resolve-FlutterCommand {
    $candidates = @(
        'C:\flutter\bin\flutter.bat',
        'C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'Flutter nao encontrado. Instale o SDK ou ajuste o PATH.'
}

function Import-BatchSetFile {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return
    }

    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*set\s+([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

function Get-LatestWriteTimeUtc {
    param(
        [string[]]$Paths
    )

    $latest = [datetime]::MinValue

    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) {
            continue
        }

        $item = Get-Item $path
        if ($item.PSIsContainer) {
            $candidate = Get-ChildItem $path -Recurse -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            if ($candidate -and $candidate.LastWriteTimeUtc -gt $latest) {
                $latest = $candidate.LastWriteTimeUtc
            }
        }
        elseif ($item.LastWriteTimeUtc -gt $latest) {
            $latest = $item.LastWriteTimeUtc
        }
    }

    return $latest
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Import-BatchSetFile (Join-Path $projectRoot 'run_atr.local.bat')

if (-not $env:SUPABASE_URL) {
    throw 'SUPABASE_URL nao definido. Ajuste run_atr.local.bat antes de abrir o app.'
}

if (-not $env:SUPABASE_ANON_KEY) {
    throw 'SUPABASE_ANON_KEY nao definido. Ajuste run_atr.local.bat antes de abrir o app.'
}

$supabaseArgs = @()
if ($env:SUPABASE_URL) {
    $supabaseArgs += "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)"
}
if ($env:SUPABASE_ANON_KEY) {
    $supabaseArgs += "--dart-define=SUPABASE_ANON_KEY=$($env:SUPABASE_ANON_KEY)"
}
if ($env:SUPABASE_SERVICE_ROLE_KEY) {
    Write-Warning 'SUPABASE_SERVICE_ROLE_KEY detectada no ambiente. Nao use service role no app Flutter/Desktop cliente.'
}

$flutterCmd = Resolve-FlutterCommand
$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\ATR.exe'
$legacyExePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\fleet_app.exe'
$windowsBuildDir = Join-Path $projectRoot 'build\windows'
$cmakeCachePath = Join-Path $projectRoot 'build\windows\x64\CMakeCache.txt'
$watchedPaths = @(
    (Join-Path $projectRoot 'lib'),
    (Join-Path $projectRoot 'assets'),
    (Join-Path $projectRoot 'windows'),
    (Join-Path $projectRoot 'pubspec.yaml'),
    (Join-Path $projectRoot 'pubspec.lock'),
    (Join-Path $projectRoot 'analysis_options.yaml')
)

$needsBuild = -not (Test-Path $exePath)
if (-not $needsBuild) {
    # EXE existe: compara carimbo de build para saber se precisa recompilar
    $stampFile = Join-Path $projectRoot '.atr_build_stamp'
    if (Test-Path $stampFile) {
        $stampTime = (Get-Item $stampFile).LastWriteTimeUtc
        $latestSourceWrite = Get-LatestWriteTimeUtc -Paths $watchedPaths
        $needsBuild = $latestSourceWrite -gt $stampTime
    } else {
        $needsBuild = $true
    }
}

# ── Primeiro caso: EXE ainda não existe → build bloqueante obrigatório ──────
if (-not (Test-Path $exePath)) {
    if (Test-Path $windowsBuildDir) {
        $shouldResetWindowsBuild = (Test-Path $legacyExePath)
        if ((-not $shouldResetWindowsBuild) -and (Test-Path $cmakeCachePath)) {
            $shouldResetWindowsBuild = Select-String -Path $cmakeCachePath -Pattern 'fleet_app' -Quiet
        }
        if ($shouldResetWindowsBuild) {
            Remove-Item $windowsBuildDir -Recurse -Force
        }
    }

    Write-Host "Compilando ATR pela primeira vez, aguarde..."
    & $flutterCmd build windows --release `
        @supabaseArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao gerar a versao Windows do ATR.'
    }
    $stampFile = Join-Path $projectRoot '.atr_build_stamp'
    [System.IO.File]::WriteAllText($stampFile, (Get-Date -Format 'o'))
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath)
    exit
}

# ── Segundo caso: EXE existe → se houver mudancas, recompila antes de abrir ──
if ($needsBuild) {
    $shouldResetWindowsBuild = (Test-Path $legacyExePath)
    if ((-not $shouldResetWindowsBuild) -and (Test-Path $cmakeCachePath)) {
        $shouldResetWindowsBuild = Select-String -Path $cmakeCachePath -Pattern 'fleet_app' -Quiet
    }
    if ($shouldResetWindowsBuild -and (Test-Path $windowsBuildDir)) {
        Remove-Item $windowsBuildDir -Recurse -Force
    }

    Write-Host 'Atualizacoes detectadas. Recompilando ATR Desktop antes de abrir...'
    & $flutterCmd build windows --release `
        @supabaseArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao atualizar a versao Windows do ATR.'
    }

    $stampFile = Join-Path $projectRoot '.atr_build_stamp'
    [System.IO.File]::WriteAllText($stampFile, (Get-Date -Format 'o'))
}

Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath)