-- Migration 031: Tabela de notificações para usuários (item A3 do plano de auditoria)
-- Cada usuário recebe notificações sobre manutenções, vencimentos, multas, etc.

CREATE TABLE IF NOT EXISTS notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    type text NOT NULL DEFAULT 'info',
    entity_id text,
    route text,
    read boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Índices para queries frequentes
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications (user_id, read, created_at DESC)
    WHERE read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_tenant
    ON notifications (tenant_id);

-- RLS: usuário só vê as próprias notificações
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select_own ON notifications
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- INSERT permitido apenas pelo backend (Edge Functions / service_role)
-- Nenhuma política INSERT para usuários autenticados normais.
