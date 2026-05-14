import { AtrTool } from "../types.ts";

function normalizeContractDate(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;

  const brMatch = raw.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (brMatch) {
    const [, dd, mm, yyyy] = brMatch;
    return `${yyyy}-${mm}-${dd}`;
  }

  return null;
}

async function resolveVehiclePlate(identifier: unknown, ctx: Record<string, unknown>) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier).replace("-", "").toUpperCase();
  const r = await (supabase as any).from("veiculos")
    .select("id, placa, modelo").eq("tenant_id", tenantId).ilike("placa", ident).single();
  return r.data || null;
}

export const createContract: AtrTool = {
  name: "create_contract",
  category: "write",
  description:
    "Cria um novo contrato de locação ATR. " +
    "Use para: 'cria contrato para cliente XPTO, placa ABC-1234, vigência 01/06 a 01/12/2026, R$ 2500/mês'. " +
    "A data final é obrigatória e não pode ficar em branco ou indeterminada.",
  input_schema: {
    type: "object",
    properties: {
      numero: { type: "string", description: "Número do contrato (obrigatório). Ex: 'CTR-2026-001'." },
      cliente_nome: { type: "string", description: "Nome do cliente (obrigatório)." },
      cliente_cnpj: { type: "string", description: "CNPJ do cliente (obrigatório)." },
      veiculo_placa: { type: "string", description: "Placa do veículo (obrigatório)." },
      data_inicio: { type: "string", description: "Data de início YYYY-MM-DD ou DD/MM/AAAA." },
      data_fim: { type: "string", description: "Data de fim obrigatória. Use YYYY-MM-DD ou DD/MM/AAAA. Não deixe em branco." },
      sla_km_mes: { type: "integer", description: "SLA de km por mês." },
      valor_mensal: { type: "number", description: "Valor mensal em R$." },
      observacoes: { type: "string", description: "Observações." },
      cliente_contato: { type: "string", description: "Contato do cliente (telefone/email)." },
    },
    required: ["numero", "cliente_nome", "cliente_cnpj", "veiculo_placa", "data_inicio", "data_fim", "valor_mensal"],
  },

  preview: async (input, ctx) => {
    const veiculo = await resolveVehiclePlate(input.veiculo_placa, ctx);
    const placa = veiculo ? (veiculo as any).placa : "?";
    return `Criar contrato ${input.numero}: ${input.cliente_nome} — ${placa} — R$ ${Number(input.valor_mensal).toFixed(2)}/mês — ${input.data_inicio} a ${input.data_fim}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const veiculo = await resolveVehiclePlate(input.veiculo_placa, ctx);
    if (!veiculo) return { ok: false, error: `Veículo "${input.veiculo_placa}" não encontrado.` };

    const dataInicio = normalizeContractDate(input.data_inicio);
    if (!dataInicio) {
      return { ok: false, error: "Data inicial inválida. Use YYYY-MM-DD ou DD/MM/AAAA." };
    }

    const dataFim = normalizeContractDate(input.data_fim);
    if (!dataFim) {
      return { ok: false, error: "Data final do contrato é obrigatória. Informe em YYYY-MM-DD ou DD/MM/AAAA." };
    }

    if (dataFim < dataInicio) {
      return { ok: false, error: "Data final deve ser igual ou posterior à data inicial." };
    }

    const valor = Number(input.valor_mensal);
    if (isNaN(valor) || valor <= 0) return { ok: false, error: "Valor mensal deve ser > 0." };

    const v = veiculo as any;
    const validatedData = {
      numero: String(input.numero).trim(),
      cliente_nome: String(input.cliente_nome).trim(),
      cliente_cnpj: String(input.cliente_cnpj).trim(),
      veiculo_placa: v.placa,
      data_inicio: dataInicio,
      data_fim: dataFim,
      sla_km_mes: input.sla_km_mes != null ? Number(input.sla_km_mes) : 0,
      valor_mensal: valor,
      observacoes: input.observacoes ? String(input.observacoes).trim() : "",
      cliente_contato: input.cliente_contato ? String(input.cliente_contato).trim() : "",
    };

    const display = (await createContract.preview!(validatedData, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};
