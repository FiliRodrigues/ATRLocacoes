@echo off
setlocal

echo =======================================================
echo        ATR LOCACOES - PERF PROFILING (WEB)
echo =======================================================

set FLUTTER_CMD=
if exist "C:\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" if exist "C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" set FLUTTER_CMD=flutter

if exist "%~dp0run_atr.local.bat" call "%~dp0run_atr.local.bat"

if "%SUPABASE_URL%"=="" (
  echo [ERRO] SUPABASE_URL nao definido. Configure em run_atr.local.bat.
  exit /b 1
)
if "%SUPABASE_ANON_KEY%"=="" (
  echo [ERRO] SUPABASE_ANON_KEY nao definido. Configure em run_atr.local.bat.
  exit /b 1
)

set SUPABASE_ARGS=--dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

echo [1/2] Encerrando processos paralisados (Flutter/Chrome)...
taskkill /F /IM "dart.exe" /T >nul 2>nul

echo [2/2] Iniciando app com flags de instrumentacao de performance...
call "%FLUTTER_CMD%" run -d chrome --web-port 5000 %SUPABASE_ARGS% --dart-define=ATR_SHOW_PERF_OVERLAY=true --dart-define=ATR_CHECKERBOARD_RASTER_CACHE_IMAGES=true --dart-define=ATR_CHECKERBOARD_OFFSCREEN_LAYERS=true

endlocal
