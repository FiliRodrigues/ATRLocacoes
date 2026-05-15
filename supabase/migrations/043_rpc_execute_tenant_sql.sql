CREATE OR REPLACE FUNCTION execute_tenant_sql(p_sql text, p_tenant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Bloqueia operações destrutivas
  IF p_sql ~* 'DROP\s+TABLE|TRUNCATE|DROP\s+SCHEMA' THEN
    RAISE EXCEPTION 'Operação bloqueada por segurança';
  END IF;
  
  -- Para DDL (CREATE/ALTER/CREATE INDEX), executa diretamente
  IF p_sql ~* '^\s*(CREATE|ALTER|DROP)' THEN
    EXECUTE p_sql;
    RETURN '"DDL executado com sucesso"'::jsonb;
  END IF;
  
  -- Para SELECT, retorna resultado como JSON
  EXECUTE 'SELECT jsonb_agg(row_to_json(t)) FROM (' || p_sql || ') t' INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION execute_tenant_sql TO service_role;
