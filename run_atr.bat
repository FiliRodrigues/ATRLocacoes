@echo off
setlocal

echo =======================================================
echo          ATR LOCACOES - GESTAO DE FROTA V2 (DEV)
echo =======================================================

set FLUTTER_CMD=
if exist "C:\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" if exist "C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\Users\filip\.puro\envs\stable\flutter\bin\flutter.bat
if "%FLUTTER_CMD%"=="" set FLUTTER_CMD=flutter

if exist "%~dp0run_atr.local.bat" call "%~dp0run_atr.local.bat"

REM ATR_DEV_QUICK_LOGIN removido (P007): autenticacao agora usa Supabase Auth nativo.

if "%SUPABASE_URL%"=="" (
	echo [ERRO] SUPABASE_URL nao definido.
	echo        Crie run_atr.local.bat a partir de run_atr.local.example.bat e defina SUPABASE_URL e SUPABASE_ANON_KEY.
	exit /b 1
)
if "%SUPABASE_ANON_KEY%"=="" (
	echo [ERRO] SUPABASE_ANON_KEY nao definido.
	echo        Crie run_atr.local.bat a partir de run_atr.local.example.bat e defina SUPABASE_URL e SUPABASE_ANON_KEY.
	exit /b 1
)

set SUPABASE_ARGS=--dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if not "%SUPABASE_SERVICE_ROLE_KEY%"=="" (
	echo [AVISO] SUPABASE_SERVICE_ROLE_KEY detectada no ambiente.
	echo         Nao use service role no app Flutter/Web cliente.
)

echo [1/3] Encerrando processos paralisados (Flutter/Chrome)...
taskkill /F /IM "dart.exe" /T >nul 2>nul

echo [2/3] Limpando o build cache para forcar atualizacao...
call "%FLUTTER_CMD%" clean >nul 2>nul

echo [3/3] Iniciando o servidor na porta 5000...
call "%FLUTTER_CMD%" run -d chrome --web-port 5000 %SUPABASE_ARGS%

endlocal
