-- Migration 028: Tabelas de Obras, Sala ATR e Lazer
-- Cria tabelas para os módulos complementares com RLS ativo

-- ═══════════════════════════════════════════════════════════════════════
-- Obras
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS obras (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  cidade text NOT NULL,
  equipe_responsavel text NOT NULL,
  status text NOT NULL DEFAULT 'Em andamento',
  data_inicio date,
  data_fim date,
  valor_total numeric DEFAULT 0,
  custo_mao_obra numeric DEFAULT 0,
  custo_material numeric DEFAULT 0,
  custo_equipamento numeric DEFAULT 0,
  raio_x_justificativa text DEFAULT '',
  raio_x_aprovado boolean DEFAULT false,
  observacoes text DEFAULT '',
  tenant_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE obras ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "obras_select" ON obras FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "obras_insert" ON obras FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "obras_update" ON obras FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "obras_delete" ON obras FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_obras_tenant ON obras(tenant_id);
CREATE INDEX IF NOT EXISTS idx_obras_status ON obras(status);

-- ═══════════════════════════════════════════════════════════════════════
-- Sala ATR Agendamentos
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS sala_atr_agendamentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data date NOT NULL,
  hora_inicio time NOT NULL,
  hora_fim time NOT NULL,
  cliente_nome text NOT NULL,
  quantidade_pessoas integer DEFAULT 1,
  tipo_evento text DEFAULT 'Reunião',
  pacote text DEFAULT 'Padrão',
  valor numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'Confirmado',
  observacoes text DEFAULT '',
  tenant_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE sala_atr_agendamentos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "sala_atr_agendamentos_select" ON sala_atr_agendamentos FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_agendamentos_insert" ON sala_atr_agendamentos FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_agendamentos_update" ON sala_atr_agendamentos FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_agendamentos_delete" ON sala_atr_agendamentos FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
-- Sala ATR Despesas
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS sala_atr_despesas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  descricao text NOT NULL,
  valor numeric NOT NULL DEFAULT 0,
  data date NOT NULL,
  categoria text DEFAULT 'Geral',
  pago boolean DEFAULT false,
  tenant_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE sala_atr_despesas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "sala_atr_despesas_select" ON sala_atr_despesas FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_despesas_insert" ON sala_atr_despesas FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_despesas_update" ON sala_atr_despesas FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "sala_atr_despesas_delete" ON sala_atr_despesas FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
-- Lazer Eventos
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS lazer_eventos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  tipo text NOT NULL DEFAULT 'Evento',
  data date NOT NULL,
  local text,
  quantidade_pessoas integer DEFAULT 0,
  receita_total numeric DEFAULT 0,
  custo_total numeric DEFAULT 0,
  status text DEFAULT 'Planejado',
  observacoes text DEFAULT '',
  tenant_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE lazer_eventos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "lazer_eventos_select" ON lazer_eventos FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_eventos_insert" ON lazer_eventos FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_eventos_update" ON lazer_eventos FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_eventos_delete" ON lazer_eventos FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
-- Lazer Despesas
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS lazer_despesas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evento_id uuid,
  descricao text NOT NULL,
  valor numeric NOT NULL DEFAULT 0,
  data date NOT NULL,
  categoria text DEFAULT 'Geral',
  pago boolean DEFAULT false,
  tenant_id uuid NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE lazer_despesas ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "lazer_despesas_select" ON lazer_despesas FOR SELECT USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_despesas_insert" ON lazer_despesas FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_despesas_update" ON lazer_despesas FOR UPDATE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "lazer_despesas_delete" ON lazer_despesas FOR DELETE USING (tenant_id = auth_tenant_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
