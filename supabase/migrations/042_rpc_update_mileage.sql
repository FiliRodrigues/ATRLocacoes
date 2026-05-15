CREATE OR REPLACE FUNCTION update_vehicle_mileage(
  p_vehicle_id uuid,
  p_km numeric,
  p_placa text,
  p_registrado_por text,
  p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE veiculos
  SET km_atual = p_km::integer
  WHERE id = p_vehicle_id AND tenant_id = p_tenant_id;

  INSERT INTO hodometros (id, veiculo_placa, km, registrado_por, tenant_id)
  VALUES (gen_random_uuid(), p_placa, p_km::integer, p_registrado_por, p_tenant_id);
END;
$$;

GRANT EXECUTE ON FUNCTION update_vehicle_mileage TO authenticated;
GRANT EXECUTE ON FUNCTION update_vehicle_mileage TO service_role;
