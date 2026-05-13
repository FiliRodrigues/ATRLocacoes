CREATE OR REPLACE FUNCTION public.create_maintenances_batch(p_items JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  item JSONB;
  new_id UUID;
  created_ids UUID[] := '{}';
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.manutencoes (
      veiculo_placa,
      data,
      tipo,
      titulo,
      descricao,
      fornecedor,
      custo,
      km_no_servico,
      numero_os,
      tenant_id
    ) VALUES (
      item->>'plate',
      (item->>'date')::DATE,
      item->>'type',
      item->>'type',
      item->>'description',
      item->>'workshop_name',
      (item->>'cost')::NUMERIC,
      (item->>'mileage')::INTEGER,
      item->>'invoice_number',
      (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID
    )
    RETURNING id INTO new_id;
    created_ids := created_ids || new_id;
  END LOOP;
  RETURN jsonb_build_object('created_ids', created_ids, 'count', array_length(created_ids, 1));
END;
$$;
