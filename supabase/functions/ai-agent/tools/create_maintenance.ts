import { AtrTool } from "../types.ts";

// ---------------------------------------------------------------
// Helper: resolve veículo por placa (case-insensitive, sem hífen) ou UUID
// ---------------------------------------------------------------
async function resolveVehicle(identifier: unknown, ctx: Record<string, unknown>) {
  const supabase = ctx.supabase as Record<string, unknown>;
  const tenantId = ctx.tenant_id as string;
  const ident = String(identifier);

  const isUuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);

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
// Tool: create_maintenance
// ---------------------------------------------------------------
export const createMaintenance: AtrTool = {
  name: "create_maintenance",
  category: "write",
  description:
    "Registra uma nova manutenção para um veículo da frota ATR Locações. " +
    "Use para solicitações como: " +
    "'registra troca de óleo no ABC-1234 dia 15/05/2026 R$ 280', " +
    "'lança manutenção de freio no caminhão DEF-5678 valor R$ 1.500', " +
    "'cria manutenção preventiva revisão dos 30.000 km', " +
    "'adiciona serviço de ar condicionado na placa XYZ-9999'. " +
    "O registro fica pendente de confirmação — o usuário precisa aprovar antes da gravação.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description:
          "Placa do veículo (com ou sem hífen, case-insensitive) ou UUID. Ex: 'ABC-1234', 'abc1234' ou 'uuid-aqui'.",
      },
      date: {
        type: "string",
        description:
          "Data do serviço no formato YYYY-MM-DD. Ex: '2026-05-15'.",
      },
      type: {
        type: "string",
        description:
          "Tipo do serviço realizado. Ex: 'Troca de óleo', 'Revisão', 'Freio', 'Suspensão', 'Motor', 'Pneu', 'Ar condicionado', 'Elétrica'.",
      },
      cost: {
        type: "number",
        description:
          "Valor do serviço em reais (R$). Deve ser maior que zero. Ex: 280.00, 1500.50.",
      },
      description: {
        type: "string",
        description:
          "Descrição adicional ou observações sobre o serviço (opcional).",
      },
      mileage: {
        type: "integer",
        description:
          "Quilometragem do veículo no momento do serviço (opcional, deve ser >= 0).",
      },
      workshop_name: {
        type: "string",
        description: "Nome da oficina ou prestador do serviço (opcional).",
      },
      workshop_cnpj: {
        type: "string",
        description: "CNPJ da oficina ou prestador (opcional).",
      },
      invoice_number: {
        type: "string",
        description: "Número da nota fiscal do serviço (opcional).",
      },
    },
    required: ["vehicle_identifier", "date", "type", "cost"],
  },

  // ---------------------------------------------------------------
  // Preview: texto humanizado para confirmação do usuário
  // ---------------------------------------------------------------
  preview: async (input, ctx) => {
    const veiculo = await resolveVehicle(input.vehicle_identifier, ctx);
    if (!veiculo) {
      return `Lançar manutenção: Veículo não encontrado para o identificador "${input.vehicle_identifier}".`;
    }

    const custo = Number(input.cost).toFixed(2).replace(".", ",");
    const modelo = (veiculo as any).modelo || "Veículo";
    const placa = (veiculo as any).placa;

    return `Lançar manutenção: ${modelo} (${placa}) — ${input.type} — R$ ${custo} em ${input.date}`;
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

    // 2. Valida data
    const date = String(input.date);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return {
        ok: false,
        error: "Data inválida. Use o formato YYYY-MM-DD (ex: 2026-05-15).",
      };
    }

    // 3. Valida cost
    const cost = Number(input.cost);
    if (isNaN(cost) || cost <= 0) {
      return {
        ok: false,
        error: "Valor do serviço (cost) deve ser um número maior que zero.",
      };
    }

    // 4. Valida type
    const type = String(input.type).trim();
    if (!type) {
      return { ok: false, error: "Tipo de serviço (type) é obrigatório." };
    }

    // 5. Valida mileage se informado
    const mileage =
      input.mileage != null ? Number(input.mileage) : undefined;
    if (mileage !== undefined && (!Number.isInteger(mileage) || mileage < 0)) {
      return {
        ok: false,
        error: "Quilometragem (mileage) deve ser um número inteiro >= 0.",
      };
    }

    // 6. Dados validados e normalizados
    const validatedData = {
      vehicle_id: (veiculo as any).id as string,
      plate: (veiculo as any).placa as string,
      model: ((veiculo as any).modelo as string) || null,
      date,
      type,
      cost,
      description: input.description ? String(input.description).trim() : null,
      mileage: mileage ?? null,
      workshop_name: input.workshop_name
        ? String(input.workshop_name).trim()
        : null,
      workshop_cnpj: input.workshop_cnpj
        ? String(input.workshop_cnpj).trim()
        : null,
      invoice_number: input.invoice_number
        ? String(input.invoice_number).trim()
        : null,
    };

    // 7. Gera preview para exibição
    const display = (await createMaintenance.preview!(input, ctx)) ?? "";

    return { ok: true, data: validatedData, display };
  },
};
