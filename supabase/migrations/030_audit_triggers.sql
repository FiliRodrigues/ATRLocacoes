-- Migration 030: Triggers de auditoria automática
-- Função tf_audit_log() registra INSERT/UPDATE/DELETE em tabelas principais

CREATE OR REPLACE FUNCTION tf_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_action text;
  v_entity_id text;
  v_before jsonb;
  v_after jsonb;
  v_tenant_id uuid;
  v_username text;
BEGIN
  -- Determina ação
  CASE TG_OP
    WHEN 'INSERT' THEN v_action := 'criar';
    WHEN 'UPDATE' THEN v_action := 'atualizar';
    WHEN 'DELETE' THEN v_action := 'deletar';
    ELSE v_action := lower(TG_OP);
  END CASE;

  -- Extrai ID e tenant
  IF TG_OP = 'DELETE' THEN
    v_entity_id := OLD.id::text;
    v_before := to_jsonb(OLD);
    v_after := NULL;
    v_tenant_id := OLD.tenant_id;
  ELSIF TG_OP = 'UPDATE' THEN
    v_entity_id := NEW.id::text;
    v_before := to_jsonb(OLD);
    v_after := to_jsonb(NEW);
    v_tenant_id := COALESCE(NEW.tenant_id, OLD.tenant_id);
  ELSE -- INSERT
    v_entity_id := NEW.id::text;
    v_before := NULL;
    v_after := to_jsonb(NEW);
    v_tenant_id := NEW.tenant_id;
  END IF;

  -- Username do JWT ou 'sistema'
  v_username := COALESCE(
    current_setting('request.jwt.claims', true)::jsonb->>'username',
    'sistema'
  );

  INSERT INTO audit_log (
    username, effective_user, tenant_id, action, entity, entity_id,
    payload, before_state, after_state, origin, created_at
  ) VALUES (
    v_username,
    v_username,
    v_tenant_id,
    v_action,
    TG_TABLE_NAME,
    v_entity_id,
    jsonb_build_object('op', TG_OP, 'table', TG_TABLE_NAME),
    v_before,
    v_after,
    'trigger',
    now()
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Triggers nas tabelas principais
DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'veiculos', 'manutencoes', 'despesas', 'contratos', 'financiamentos',
    'ipva', 'licenciamento', 'seguros', 'multas'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_audit_%I ON %I;
       CREATE TRIGGER trg_audit_%I
         AFTER INSERT OR UPDATE OR DELETE ON %I
         FOR EACH ROW EXECUTE FUNCTION tf_audit_log();',
      tbl, tbl, tbl, tbl
    );
  END LOOP;
END $$;
