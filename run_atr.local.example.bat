@echo off
REM Copie este arquivo para run_atr.local.bat e ajuste os valores.
REM Use apenas a chave publica (anon/publishable) no app cliente.
REM Nunca coloque SUPABASE_SERVICE_ROLE_KEY neste arquivo.

REM Autenticacao agora usa Supabase Auth nativo. Faca login no app
REM com o email do usuario e a senha definida no Supabase Dashboard.

set SUPABASE_URL=https://SEU-PROJETO.supabase.co
set SUPABASE_ANON_KEY=sb_publishable_xxxxxxxxxxxxxxxxxxxxx
