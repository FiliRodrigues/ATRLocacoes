-- Performance em queries de auditoria
CREATE INDEX IF NOT EXISTS ai_action_audit_tenant_user_idx
  ON ai_action_audit(tenant_id, user_id, created_at DESC);

-- Rate limit: busca rápida por user_id web
CREATE INDEX IF NOT EXISTS ai_rate_limits_user_id_created_idx
  ON ai_rate_limits(user_id) WHERE user_id IS NOT NULL;
