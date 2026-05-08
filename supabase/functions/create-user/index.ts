import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, password, username, nome_completo, role, allowed_features } = await req.json();

    // 1. Validação
    if (!email || !password || !username) {
      return new Response(JSON.stringify({ error: 'Campos obrigatórios: email, password, username' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (password.length < 12) {
      return new Response(JSON.stringify({ error: 'A senha deve ter no mínimo 12 caracteres.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (!['admin', 'member'].includes(role)) {
      return new Response(JSON.stringify({ error: 'Role inválida. Use admin ou member.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Verifica que o caller é admin
    const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization')! } },
    });
    const { data: { user: caller } } = await userClient.auth.getUser();
    if (!caller || caller.app_metadata?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Apenas administradores podem criar usuários.' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const callerTenant = caller.app_metadata?.tenant_id;

    // 3. Cria auth.users via Admin API
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: {
        role,
        username,
        tenant_id: callerTenant,
        allowed_features: role === 'admin' ? [] : (allowed_features ?? []),
      },
      user_metadata: { full_name: nome_completo },
    });

    if (createError) {
      const msg = createError.message.includes('duplicate')
        ? 'Email já cadastrado no sistema.'
        : createError.message;
      return new Response(JSON.stringify({ error: msg }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. Insere em app_users
    const { error: insertError } = await admin.from('app_users').insert({
      username,
      password_hash: '',
      password_salt: '',
      role,
      nome_completo: nome_completo ?? '',
      tenant_id: callerTenant,
      id: created.user.id,
      allowed_features: role === 'admin' ? [] : (allowed_features ?? []),
      must_change_password: true,
    });

    if (insertError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ ok: true, user_id: created.user.id }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : 'Erro interno' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
