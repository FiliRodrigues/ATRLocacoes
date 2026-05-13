import { AtrTool } from "../types.ts";

export const getAlertasFrota: AtrTool = {
  name: "get_alertas_frota",
  category: "read",
  description:
    "Retorna alertas críticos da frota: multas vencidas, IPVA/licenciamento vencido, " +
    "veículos sem KM atualizado, manutenções preventivas vencidas. " +
    "Use quando o usuário pede: 'tem alguma pendência?', 'o que está vencido?', 'alertas da frota'.",
  input_schema: {
    type: "object",
    properties: {
      dias_km_sem_atualizacao: {
        type: "integer",
        description: "Dias sem atualizar KM para considerar alerta (padrão: 7)."
      },
    },
    required: [],
  },
  preview: async (input, _ctx) => {
    const dias = input.dias_km_sem_atualizacao || 7;
    return `Verificar alertas críticos da frota (multas, IPVA, licenciamento, KM, manutenções) — KM sem atualizar há ${dias} dias`;
  },
  handler: async (input, ctx) => {
    const supabase = ctx.supabase as any;
    const tenantId = ctx.tenant_id as string;
    const dias = input.dias_km_sem_atualizacao || 7;
    const hoje = new Date();
    const dataLimite = new Date(hoje.getTime() - dias * 24 * 60 * 60 * 1000);
    const dataLimiteStr = dataLimite.toISOString().split("T")[0];

    // Multas vencidas
    const { data: multas } = await supabase
      .from("multas")
      .select("id, veiculo_id, valor, descricao, data_vencimento")
      .eq("tenant_id", tenantId)
      .eq("status_pagamento", "Pendente")
      .lt("data_vencimento", hoje.toISOString().split("T")[0]);

    // IPVA vencido
    const { data: ipvas } = await supabase
      .from("ipva")
      .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento")
      .eq("tenant_id", tenantId)
      .eq("status_pagamento", "Pendente")
      .lt("data_vencimento", hoje.toISOString().split("T")[0]);

    // Licenciamento vencido
    const { data: licenciamentos } = await supabase
      .from("licenciamento")
      .select("id, veiculo_id, ano_referencia, valor_total, data_vencimento")
      .eq("tenant_id", tenantId)
      .eq("status_pagamento", "Pendente")
      .lt("data_vencimento", hoje.toISOString().split("T")[0]);

    // Veículos sem hodômetro atualizado há X dias
    const { data: veiculos } = await supabase
      .from("veiculos")
      .select("placa, modelo, km_atual")
      .eq("tenant_id", tenantId);
    const { data: hodometros } = await supabase
      .from("hodometros")
      .select("veiculo_placa, created_at")
      .eq("tenant_id", tenantId)
      .order("created_at", { ascending: false });
    // Agrupar em JS: último registro por placa
    const ultimoHodometro: Record<string, string> = {};
    for (const h of (hodometros || [])) {
      if (!ultimoHodometro[h.veiculo_placa]) {
        ultimoHodometro[h.veiculo_placa] = h.created_at;
      }
    }
    const placasSemKm = (veiculos || []).filter((v: any) => {
      const ultimo = ultimoHodometro[v.placa];
      if (!ultimo) return true;
      return ultimo < dataLimiteStr + "T00:00:00Z";
    });

    // Manutenções preventivas vencidas por KM
    const { data: regras } = await supabase
      .from("regras_manutencao")
      .select("veiculo_placa, intervalo_km, km_ultima_execucao, is_ativa")
      .eq("tenant_id", tenantId)
      .eq("is_ativa", true);
    const manutsVencidas = (regras || []).filter((r: any) => {
      const v = (veiculos || []).find((v: any) => v.placa === r.veiculo_placa);
      if (!v || r.km_ultima_execucao == null || r.intervalo_km == null) return false;
      return v.km_atual > (r.km_ultima_execucao + r.intervalo_km);
    });

    return {
      ok: true,
      data: {
        multas_vencidas: multas || [],
        ipva_vencido: ipvas || [],
        licenciamentos_vencidos: licenciamentos || [],
        veiculos_sem_km_atualizado: placasSemKm,
        manutencoes_vencidas_km: manutsVencidas,
      },
    };
  },
};
