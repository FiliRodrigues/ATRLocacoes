import { AtrTool } from "../types.ts";

async function resolveVehicleId(identifier: unknown, ctx: Record<string, unknown>) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

  if (isUuid) {
    const r = await (supabase as any).from("veiculos").select("id, placa, modelo, marca, km_atual")
      .eq("tenant_id", tenantId).eq("id", ident).single();
    return r.data || null;
  }
  const placaQuery = ident.replace("-", "").toUpperCase();
  const r = await (supabase as any).from("veiculos").select("id, placa, modelo, marca, km_atual")
    .eq("tenant_id", tenantId).ilike("placa", placaQuery).single();
  return r.data || null;
}

export const updateVehicle: AtrTool = {
  name: "update_vehicle",
  category: "write",
  description:
    "Atualiza os dados de um veículo existente na frota ATR Locações. " +
    "Use para: 'atualiza km do ABC-1234 para 50000', " +
    "'muda status do veículo DEF-5678 para Em manutenção', " +
    "'altera situação operacional do XYZ-9999 para Locado'. " +
    "Todos os campos são opcionais — apenas os informados serão alterados.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description: "Placa (com ou sem hífen) ou UUID do veículo a ser atualizado.",
      },
      placa: { type: "string", description: "Nova placa (se quiser trocar a placa)." },
      tipo: { type: "string", description: "Novo tipo do veículo." },
      marca: { type: "string", description: "Nova marca." },
      modelo: { type: "string", description: "Novo modelo." },
      ano_fabricacao_modelo: { type: "string", description: "Novo ano de fabricação/modelo." },
      km_atual: { type: "integer", description: "Nova quilometragem atual." },
      situacao_operacional: { type: "string", description: "Nova situação operacional." },
      propriedade_status: { type: "string", description: "Novo status de propriedade." },
      valor_veiculo: { type: "number", description: "Novo valor de mercado." },
      observacoes: { type: "string", description: "Novas observações." },
    },
    required: ["vehicle_identifier"],
  },

  preview: async (input, ctx) => {
    const veiculo = await resolveVehicleId(input.vehicle_identifier, ctx);
    if (!veiculo) return `Atualizar veículo: não encontrado "${input.vehicle_identifier}".`;
    const placa = (veiculo as any).placa;
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "vehicle_identifier" && v !== undefined && v !== null) {
        mudancas.push(`${k}=${v}`);
      }
    }
    return `Atualizar veículo ${placa}: ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const veiculo = await resolveVehicleId(input.vehicle_identifier, ctx);
    if (!veiculo) return { ok: false, error: "Veículo não encontrado. Use placa válida ou UUID." };

    const updates: Record<string, unknown> = {};
    const campos = ["placa", "tipo", "marca", "modelo", "ano_fabricacao_modelo", "km_atual",
      "situacao_operacional", "propriedade_status", "valor_veiculo", "observacoes"];

    for (const campo of campos) {
      if (input[campo] !== undefined && input[campo] !== null) {
        const val = campo === "km_atual" || campo === "valor_veiculo" ? Number(input[campo]) : String(input[campo]).trim();
        if (val !== "" || typeof val === "number") updates[campo] = val;
      }
    }

    if (Object.keys(updates).length === 0) {
      return { ok: false, error: "Nenhum campo para atualizar foi informado." };
    }

    const validatedData = {
      vehicle_id: (veiculo as any).id,
      plate: (veiculo as any).placa,
      updates,
    };

    const display = (await updateVehicle.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};
