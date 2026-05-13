-- 026_ai_audit_content_hashes
-- Adiciona coluna content_hashes em ai_action_audit para detecção de PDF já processado.
-- Permite identificar se um PDF (via hash SHA-256) já foi confirmado pelo usuário,
-- evitando reprocessamento silencioso.

ALTER TABLE public.ai_action_audit
  ADD COLUMN IF NOT EXISTS content_hashes TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_ai_audit_content_hashes
  ON public.ai_action_audit USING GIN (content_hashes);
