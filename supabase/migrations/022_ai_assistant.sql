-- ============================================================
-- 022_ai_assistant.sql
-- IA conversacional + WhatsApp + auditoria de ações da IA
-- ============================================================

-- 1. Conversas de IA (histórico por usuário)
CREATE TABLE IF NOT EXISTS public.ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('web', 'whatsapp')),
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON public.ai_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_tenant ON public.ai_conversations(tenant_id);

-- 2. Mensagens de cada conversa
CREATE TABLE IF NOT EXISTS public.ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'tool_result')),
  content JSONB NOT NULL, -- array de blocos: text, image, tool_use, tool_result
  tool_calls JSONB,        -- ferramentas chamadas nesta mensagem (se assistant)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation ON public.ai_messages(conversation_id, created_at);

-- 3. Auditoria de ações executadas pela IA (write actions)
CREATE TABLE IF NOT EXISTS public.ai_action_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES public.ai_conversations(id) ON DELETE SET NULL,
  tool_name TEXT NOT NULL,
  input JSONB NOT NULL,
  output JSONB,
  status TEXT NOT NULL CHECK (status IN ('pending_confirmation', 'confirmed', 'executed', 'failed', 'cancelled')),
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  executed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ai_audit_tenant_date ON public.ai_action_audit(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_audit_user ON public.ai_action_audit(user_id, created_at DESC);

-- 4. Vínculo de usuário ATR <-> número WhatsApp
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS whatsapp_phone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ai_enabled BOOLEAN NOT NULL DEFAULT TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_whatsapp_phone
  ON public.app_users(whatsapp_phone)
  WHERE whatsapp_phone IS NOT NULL;

-- 5. Rate limiting do WhatsApp
CREATE TABLE IF NOT EXISTS public.ai_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL,
  minute_count INTEGER NOT NULL DEFAULT 0,
  hour_count INTEGER NOT NULL DEFAULT 0,
  day_count INTEGER NOT NULL DEFAULT 0,
  minute_window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  hour_window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  day_window_start TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_rate_limits_phone ON public.ai_rate_limits(phone);

-- 6. RLS
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_action_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_rate_limits ENABLE ROW LEVEL SECURITY;

-- Policy: usuário vê apenas suas próprias conversas
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_conv_select') THEN
    CREATE POLICY ai_conv_select ON public.ai_conversations
      FOR SELECT USING (
        tenant_id::text = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')
        AND user_id = auth.uid()
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_conv_insert') THEN
    CREATE POLICY ai_conv_insert ON public.ai_conversations
      FOR INSERT WITH CHECK (
        tenant_id::text = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')
        AND user_id = auth.uid()
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_conv_update') THEN
    CREATE POLICY ai_conv_update ON public.ai_conversations
      FOR UPDATE USING (user_id = auth.uid());
  END IF;
END $$;

-- Policies para ai_messages: via conversation_id
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_msg_select') THEN
    CREATE POLICY ai_msg_select ON public.ai_messages
      FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.ai_conversations c
                WHERE c.id = conversation_id AND c.user_id = auth.uid())
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_msg_insert') THEN
    CREATE POLICY ai_msg_insert ON public.ai_messages
      FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.ai_conversations c
                WHERE c.id = conversation_id AND c.user_id = auth.uid())
      );
  END IF;
END $$;

-- Audit: usuários veem suas próprias; admins veem todas do tenant
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ai_audit_select') THEN
    CREATE POLICY ai_audit_select ON public.ai_action_audit
      FOR SELECT USING (
        tenant_id::text = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')
        AND (
          user_id = auth.uid()
          OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
        )
      );
  END IF;
END $$;

-- Audit insert: somente service_role (Edge Function), nunca cliente
-- (sem policy de insert para usuários comuns = bloqueado por default)

-- Rate limits: service_role apenas (gerenciado pela Edge Function)

-- 7. Trigger updated_at para ai_conversations
CREATE OR REPLACE FUNCTION public.tg_ai_conversations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'ai_conversations_updated_at') THEN
    CREATE TRIGGER ai_conversations_updated_at
      BEFORE UPDATE ON public.ai_conversations
      FOR EACH ROW EXECUTE FUNCTION public.tg_ai_conversations_updated_at();
  END IF;
END $$;

-- 8. Função RPC: criar manutenções em lote com atomicidade
CREATE OR REPLACE FUNCTION public.create_maintenances_batch(p_items JSONB)
RETURNS JSONB AS $$
DECLARE
  item JSONB;
  new_id UUID;
  created_ids UUID[] := '{}';
  tenant_uuid UUID;
BEGIN
  -- Extrai tenant_id do JWT (primeiro item deve ter tenant consistente)
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.manutencoes (
      veiculo_id, data_servico, descricao, tipo_servico,
      oficina, valor_servico, km_registro, tenant_id
    ) VALUES (
      (item->>'vehicle_id')::UUID,
      (item->>'date')::DATE,
      item->>'description',
      item->>'type',
      item->>'workshop_name',
      (item->>'cost')::NUMERIC,
      (item->>'mileage')::INTEGER,
      (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID
    )
    RETURNING id INTO new_id;

    created_ids := array_append(created_ids, new_id);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'created_ids', to_jsonb(created_ids),
    'count', array_length(created_ids, 1)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Otimizações
ANALYZE public.ai_conversations;
ANALYZE public.ai_messages;
ANALYZE public.ai_action_audit;
