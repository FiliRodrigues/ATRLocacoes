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

if "%ATR_LOGIN_USER%"=="" set ATR_LOGIN_USER=adm
if "%ATR_DEV_QUICK_LOGIN%"=="" set ATR_DEV_QUICK_LOGIN=true

if "%ATR_LOGIN_PASS%"=="" (
	echo [ERRO] ATR_LOGIN_PASS nao definido.
	echo        Defina variavel de ambiente ATR_LOGIN_PASS ou crie run_atr.local.bat.
	exit /b 1
)

echo [1/3] Encerrando processos paralisados (Flutter/Chrome)...
taskkill /F /IM "dart.exe" /T >nul 2>nul

echo [2/3] Limpando o build cache para forcar atualizacao...
call "%FLUTTER_CMD%" clean >nul 2>nul

echo [3/3] Iniciando o servidor na porta 5000...
call "%FLUTTER_CMD%" run -d chrome --web-port 5000 --dart-define=ATR_LOGIN_USER=%ATR_LOGIN_USER% --dart-define=ATR_LOGIN_PASS=%ATR_LOGIN_PASS% --dart-define=ATR_DEV_QUICK_LOGIN=%ATR_DEV_QUICK_LOGIN%

endlocal
