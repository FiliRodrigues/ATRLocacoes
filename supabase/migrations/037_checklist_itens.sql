ALTER TABLE checklist_eventos ADD COLUMN IF NOT EXISTS itens JSONB DEFAULT '{}'::jsonb;
