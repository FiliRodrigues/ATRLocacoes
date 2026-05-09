import { AtrTool } from "../types.ts";

// ---------------------------------------------------------------
// Helper: resolve veículo completo por placa (case-insensitive, sem hífen) ou UUID.
// Retorna { id, placa, modelo, km_atual } ou null.
// ---------------------------------------------------------------
async function resolveVehicle(
  identifier: unknown,
  ctx: Record<string, unknown>
) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);

  const isUuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      ident
    );

  if (isUuid) {
    const result = await (supabase as any)
      .from("veiculos")
      .select("id, placa, modelo, km_atual")
      .eq("tenant_id", tenantId)
      .eq("id", ident)
      .single();

    return result.data || null;
  }

  const placaQuery = ident.replace("-", "").toUpperCase();
  const result = await (supabase as any)
    .from("veiculos")
    .select("id, placa, modelo, km_atual")
    .eq("tenant_id", tenantId)
    .ilike("placa", placaQuery)
    .single();

  return result.data || null;
}

// ---------------------------------------------------------------
// Tool: update_vehicle_mileage
// ---------------------------------------------------------------
export const updateVehicleMileage: AtrTool = {
  name: "update_vehicle_mileage",
  category: "write",
  description:
    "Atualiza a quilometragem (hodômetro) de um veículo da frota ATR Locações. " +
    "O novo valor de KM deve ser maior ou igual ao KM atual do veículo — " +
    "não é permitido reduzir a quilometragem. " +
    "Além de atualizar o campo km_atual na tabela veiculos, também registra " +
    "uma entrada na tabela hodometros para histórico. " +
    "Use para solicitações como: " +
    "'atualiza km do ABC-1234 para 45300', " +
    "'registra hodômetro do caminhão DEF-5678 com 120500 km', " +
    "'atualiza quilometragem da placa XYZ-9999 para 78200'. " +
    "O registro fica pendente de confirmação — o usuário precisa aprovar antes da gravação.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description:
          "Placa do veículo (com ou sem hífen, case-insensitive) ou UUID. Ex: 'ABC-1234', 'abc1234' ou 'uuid-aqui'.",
      },
      new_mileage: {
        type: "integer",
        description:
          "Nova quilometragem do veículo. Deve ser um número inteiro >= 0 e >= km_atual atual. Ex: 45300.",
      },
    },
    required: ["vehicle_identifier", "new_mileage"],
  },

  // ---------------------------------------------------------------
  // Preview: texto humanizado para confirmação do usuário
  // ---------------------------------------------------------------
  preview: async (input, ctx) => {
    const veiculo = await resolveVehicle(input.vehicle_identifier, ctx);
    if (!veiculo) {
      return `Atualizar odômetro: Veículo não encontrado para o identificador "${input.vehicle_identifier}".`;
    }

    const placa = (veiculo as any).placa as string;
    const modelo = ((veiculo as any).modelo as string) || "Veículo";
    const kmAtual = (veiculo as any).km_atual;
    const kmAtualStr =
      kmAtual != null ? `${kmAtual}` : "N/D";
    const novoKm = input.new_mileage;

    return `Atualizar odômetro: ${placa} (${modelo}) — de ${kmAtualStr} km para ${novoKm} km`;
  },

  // ---------------------------------------------------------------
  // Handler: valida, resolve veículo, retorna dados prontos para execução
  // ---------------------------------------------------------------
  handler: async (input, ctx) => {
    // 1. Resolve veículo
    const veiculo = await resolveVehicle(input.vehicle_identifier, ctx);
    if (!veiculo) {
      return {
        ok: false,
        error:
          "Veículo não encontrado. Use uma placa válida (ex: ABC-1234) ou UUID.",
      };
    }

    const veiculoId = (veiculo as any).id as string;
    const placa = (veiculo as any).placa as string;
    const modelo = ((veiculo as any).modelo as string) || null;
    const kmAtual = (veiculo as any).km_atual as number | null;

    // 2. Valida new_mileage
    const newMileage = Number(input.new_mileage);
    if (!Number.isInteger(newMileage) || newMileage < 0) {
      return {
        ok: false,
        error:
          "Nova quilometragem (new_mileage) deve ser um número inteiro >= 0.",
      };
    }

    // 3. Valida que não pode reduzir km
    if (kmAtual != null && newMileage < kmAtual) {
      return {
        ok: false,
        error: `Não é permitido reduzir a quilometragem. KM atual: ${kmAtual} km. Novo valor informado: ${newMileage} km.`,
      };
    }

    // 4. Dados validados e normalizados
    const validatedData = {
      vehicle_id: veiculoId,
      plate: placa,
      model: modelo,
      old_mileage: kmAtual ?? 0,
      new_mileage: newMileage,
      // Dados para registro em hodometros (executado via confirmation.ts)
      hodometro_entry: {
        veiculo_placa: placa,
        km: newMileage,
        registrado_por: "ia_assistant",
      },
    };

    // 5. Gera preview para exibição
    const display =
      (await updateVehicleMileage.preview!(input, ctx)) ?? "";

    return { ok: true, data: validatedData, display };
  },
};
