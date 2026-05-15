create or replace function public.check_contrato_ativo_unique()
returns trigger
language plpgsql
as $function$
begin
  if new.status = 'ativo' then
    if exists (
      select 1
      from public.contratos
      where veiculo_placa = new.veiculo_placa
        and id != new.id
        and status = 'ativo'
        and tenant_id = new.tenant_id
    ) then
      raise exception 'Veículo % já possui contrato ativo', new.veiculo_placa;
    end if;
  end if;

  return new;
end;
$function$;