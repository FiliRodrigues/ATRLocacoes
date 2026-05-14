import { AtrTool } from "../types.ts";

async function resolveVehicle(identifier: unknown, ctx: Record<string, unknown>) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

  if (isUuid) {
    const r = await (supabase as any).from("veiculos").select("id, placa, modelo, situacao_operacional")
      .eq("tenant_id", tenantId).eq("id", ident).single();
    return r.data || null;
  }
  const placaQuery = ident.replace("-", "").toUpperCase();
  const r = await (supabase as any).from("veiculos").select("id, placa, modelo, situacao_operacional")
    .eq("tenant_id", tenantId).ilike("placa", placaQuery).single();
  return r.data || null;
}

export const deleteVehicle: AtrTool = {
  name: "delete_vehicle",
  category: "write",
  description:
    "Remove um veículo da frota ATR Locações. " +
    "ATENÇÃO: Esta ação é irreversível. Use apenas quando tiver certeza absoluta. " +
    "O veículo não pode estar vinculado a contratos ativos ou financiamentos ativos.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description: "Placa ou UUID do veículo a ser removido.",
      },
      confirm: {
        type: "boolean",
        description: "Deve ser true para confirmar a exclusão. Ex: true.",
      },
    },
    required: ["vehicle_identifier", "confirm"],
  },

  preview: async (input, ctx) => {
    const veiculo = await resolveVehicle(input.vehicle_identifier, ctx);
    if (!veiculo) return `Excluir veículo: não encontrado "${input.vehicle_identifier}".`;
    const v = veiculo as any;
    if (input.confirm !== true) return `⚠️ Excluir veículo ${v.placa} (${v.modelo || "Veículo"}) — confirme com "confirm: true".`;
    return `🗑️ EXCLUIR permanentemente veículo ${v.placa} (${v.modelo || "Veículo"}) — IRREVERSÍVEL`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    if (input.confirm !== true) {
      return { ok: false, error: "Confirme a exclusão com 'confirm: true'." };
    }

    const veiculo = await resolveVehicle(input.vehicle_identifier, ctx);
    if (!veiculo) return { ok: false, error: "Veículo não encontrado." };

    const v = veiculo as any;

    // Verifica contratos ativos
    const { data: contratos } = await (supabase as any)
      .from("contratos")
      .select("id, status")
      .eq("tenant_id", tenantId)
      .eq("veiculo_placa", v.placa)
      .eq("status", "ativo");

    if (contratos && contratos.length > 0) {
      return { ok: false, error: `Veículo ${v.placa} possui ${contratos.length} contrato(s) ativo(s). Encerre-os antes de excluir.` };
    }

    // Verifica financiamentos ativos
    const { data: financiamentos } = await (supabase as any)
      .from("financiamentos")
      .select("id, situacao")
      .eq("tenant_id", tenantId)
      .eq("veiculo_id", v.id)
      .neq("situacao", "Quitado");

    if (financiamentos && financiamentos.length > 0) {
      return { ok: false, error: `Veículo ${v.placa} possui financiamento ativo. Quite ou remova o financiamento antes de excluir.` };
    }

    // Verifica dependências em paralelo (todas as tabelas com FK para veículos)
    const [
      { count: manutCount },
      { count: abastCount },
      { count: despCount },
      { count: hodoCount },
      { count: ipvaCount },
      { count: licCount },
      { count: multaCount },
      { count: seguroCount },
    ] = await Promise.all([
      (supabase as any).from("manutencoes").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).eq("veiculo_id", v.id),
      (supabase as any).from("abastecimentos").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).ilike("veiculo_placa", v.placa),
      (supabase as any).from("despesas").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).ilike("veiculo_placa", v.placa),
      (supabase as any).from("hodometros").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).ilike("veiculo_placa", v.placa),
      (supabase as any).from("ipva").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).eq("veiculo_id", v.id),
      (supabase as any).from("licenciamento").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).eq("veiculo_id", v.id),
      (supabase as any).from("multas").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).eq("veiculo_id", v.id),
      (supabase as any).from("seguros").select("*", { count: "exact", head: true }).eq("tenant_id", tenantId).eq("veiculo_id", v.id),
    ]);

    const dependencias: string[] = [];
    if (manutCount) dependencias.push(`${manutCount} manutenção(ões)`);
    if (abastCount) dependencias.push(`${abastCount} abastecimento(s)`);
    if (despCount)  dependencias.push(`${despCount} despesa(s)`);
    if (hodoCount)  dependencias.push(`${hodoCount} hodômetro(s)`);
    if (ipvaCount)  dependencias.push(`${ipvaCount} registro(s) de IPVA`);
    if (licCount)   dependencias.push(`${licCount} licenciamento(s)`);
    if (multaCount) dependencias.push(`${multaCount} multa(s)`);
    if (seguroCount) dependencias.push(`${seguroCount} seguro(s)`);

    if (dependencias.length > 0) {
      return {
        ok: false,
        error: `Veículo ${v.placa} possui registros vinculados: ${dependencias.join(", ")}. Remova esses registros antes de excluir o veículo.`,
      };
    }

    const display = `🗑️ Excluir veículo ${v.placa} (${v.modelo || "Veículo"})`;
    return { ok: true, data: { vehicle_id: v.id, plate: v.placa }, display };
  },
};
