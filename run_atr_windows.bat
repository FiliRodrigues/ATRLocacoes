@echo off
setlocal

echo =======================================================
echo       ATR LOCACOES - GESTAO DE FROTA V2 (WINDOWS)
echo =======================================================

set FLUTTER_CMD=
if exist "C:\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" if exist "C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" set FLUTTER_CMD=flutter

if exist "%~dp0run_atr.local.bat" call "%~dp0run_atr.local.bat"

if "%SUPABASE_URL%"=="" (
    echo [ERRO] SUPABASE_URL nao definido.
    echo        Crie run_atr.local.bat com SUPABASE_URL e SUPABASE_ANON_KEY.
    exit /b 1
)
if "%SUPABASE_ANON_KEY%"=="" (
    echo [ERRO] SUPABASE_ANON_KEY nao definido.
    echo        Crie run_atr.local.bat com SUPABASE_URL e SUPABASE_ANON_KEY.
    exit /b 1
)

set SUPABASE_ARGS=--dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

echo Iniciando ATR no Windows Desktop...
call "%FLUTTER_CMD%" run -d windows %SUPABASE_ARGS%

endlocal
