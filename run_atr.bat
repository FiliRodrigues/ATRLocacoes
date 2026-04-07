@echo off
echo =======================================================
echo          ATR LOCACOES - GESTAO DE FROTA V2 (DEV)       
echo =======================================================
echo [1/3] Encerrando processos paralisados (Flutter/Chrome)...
taskkill /F /IM "dart.exe" /T >nul 2>nul

echo [2/3] Limpando o build cache para forcar atualizacao...
call C:\flutter\bin\flutter.bat clean >nul 2>nul

echo [3/3] Iniciando o servidor na porta 5000...
call C:\flutter\bin\flutter.bat run -d chrome --web-port 5000
