-- Migration 029: Ajuste coluna local em lazer_eventos
-- Remove restrição NOT NULL para permitir eventos sem local definido

ALTER TABLE lazer_eventos ALTER COLUMN local DROP NOT NULL;
