CREATE OR REPLACE FUNCTION public.create_maintenances_batch(p_items JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  item JSONB;
  new_id UUID;
  created_ids UUID[] := '{}';
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.manutencoes (
      veiculo_id, data_servico, tipo_servico, descricao,
      oficina, valor_servico, km_registro, tenant_id
    ) VALUES (
      (item->>'vehicle_id')::UUID,
      (item->>'date')::DATE,
      item->>'type',
      item->>'description',
      item->>'workshop_name',
      (item->>'cost')::NUMERIC,
      NULLIF(item->>'mileage', '')::INTEGER,
      (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID
    ) RETURNING id INTO new_id;
    created_ids := created_ids || new_id;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'created_ids', to_jsonb(created_ids), 'count', array_length(created_ids, 1));
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;
