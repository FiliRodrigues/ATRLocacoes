-- Habilita REPLICA IDENTITY FULL nas tabelas da Sala ATR para Realtime
ALTER TABLE sala_atr_agendamentos REPLICA IDENTITY FULL;
ALTER TABLE sala_atr_despesas REPLICA IDENTITY FULL;
ALTER TABLE sala_atr_pacotes REPLICA IDENTITY FULL;

-- Adiciona tabelas à publicação Realtime do Supabase (se ainda não estiverem)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'sala_atr_agendamentos'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sala_atr_agendamentos;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'sala_atr_despesas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sala_atr_despesas;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'sala_atr_pacotes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sala_atr_pacotes;
  END IF;
END $$;
