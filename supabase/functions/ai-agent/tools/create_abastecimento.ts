import { AtrTool } from "../types.ts";

async function resolveVehiclePlate(identifier: unknown, ctx: Record<string, unknown>) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);
  const placaQuery = ident.replace("-", "").toUpperCase();
  const r = await (supabase as any).from("veiculos")
    .select("id, placa, modelo, km_atual")
    .eq("tenant_id", tenantId).ilike("placa", placaQuery).single();
  return r.data || null;
}

export const createAbastecimento: AtrTool = {
  name: "create_abastecimento",
  category: "write",
  description:
    "Registra um novo abastecimento de combustível. " +
    "Use para: 'registra abastecimento ABC-1234 45 litros R$ 250', " +
    "'lança tanque cheio etanol no DEF-5678'. " +
    "O registro fica pendente de confirmação.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_plate: { type: "string", description: "Placa do veículo (obrigatório). Ex: 'ABC-1234'." },
      data: { type: "string", description: "Data YYYY-MM-DD." },
      litros: { type: "number", description: "Litros abastecidos." },
      valor_total: { type: "number", description: "Valor total em R$." },
      km_odometro: { type: "number", description: "KM do odômetro no abastecimento." },
      tipo: { type: "string", description: "Tipo de combustível: 'gasolina', 'etanol', 'diesel', 'gnv'." },
      posto: { type: "string", description: "Nome do posto (opcional)." },
    },
    required: ["vehicle_plate", "data", "litros", "valor_total"],
  },

  preview: async (input, ctx) => {
    const veiculo = await resolveVehiclePlate(input.vehicle_plate, ctx);
    if (!veiculo) return `Registrar abastecimento: veículo não encontrado "${input.vehicle_plate}".`;
    const v = veiculo as any;
    return `Registrar abastecimento: ${v.placa} (${v.modelo || "Veículo"}) — ${input.litros}L — R$ ${Number(input.valor_total).toFixed(2)} — ${input.data}`;
  },

  handler: async (input, ctx) => {
    const veiculo = await resolveVehiclePlate(input.vehicle_plate, ctx);
    if (!veiculo) return { ok: false, error: "Veículo não encontrado. Use uma placa válida." };

    const date = String(input.data);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };

    const litros = Number(input.litros);
    if (isNaN(litros) || litros <= 0) return { ok: false, error: "Litros deve ser > 0." };

    const valor_total = Number(input.valor_total);
    if (isNaN(valor_total) || valor_total <= 0) return { ok: false, error: "Valor total deve ser > 0." };

    const v = veiculo as any;
    const validatedData = {
      vehicle_id: v.id,
      plate: v.placa,
      date,
      litros,
      valor_total,
      km_odometro: input.km_odometro != null ? Number(input.km_odometro) : null,
      tipo: input.tipo ? String(input.tipo).trim() : "gasolina",
      posto: input.posto ? String(input.posto).trim() : null,
    };

    const display = (await createAbastecimento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};
