import { AtrTool } from "../types.ts";

// ---------------------------------------------------------------
// Helper: resolve veículo por placa (case-insensitive, sem hífen) ou UUID.
// Retorna apenas placa (despesas usam veiculo_placa, não FK).
// ---------------------------------------------------------------
async function resolveVehiclePlate(
  identifier: unknown,
  ctx: Record<string, unknown>
): Promise<string | null> {
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
      .select("placa")
      .eq("tenant_id", tenantId)
      .eq("id", ident)
      .single();

    return result.data?.placa || null;
  }

  const placaQuery = ident.replace("-", "").toUpperCase();
  const result = await (supabase as any)
    .from("veiculos")
    .select("placa")
    .eq("tenant_id", tenantId)
    .ilike("placa", placaQuery)
    .single();

  return result.data?.placa || null;
}

// ---------------------------------------------------------------
// Mapeamento: category (input do usuário) -> tipo (coluna no banco)
// ---------------------------------------------------------------
const CATEGORIAS_VALIDAS: Record<string, string> = {
  combustivel: "combustível",
  combustível: "combustível",
  "combustível": "combustível",
  multa: "multa",
  ipva: "IPVA",
  IPVA: "IPVA",
  seguro: "seguro",
  outros: "outros",
};

function mapearCategoria(category: unknown): string | null {
  const key = String(category).trim().toLowerCase();
  return CATEGORIAS_VALIDAS[key] || CATEGORIAS_VALIDAS[String(category).trim()] || null;
}

// ---------------------------------------------------------------
// Tool: create_expense
// ---------------------------------------------------------------
export const createExpense: AtrTool = {
  name: "create_expense",
  category: "write",
  description:
    "Registra uma nova despesa operacional da frota ATR Locações. " +
    "A despesa pode ser vinculada a um veículo específico (via placa) ou ser geral (sem veículo). " +
    "Use para solicitações como: " +
    "'lança despesa de combustível R$ 350 no ABC-1234 dia 10/05', " +
    "'registra multa de trânsito R$ 195,23 placa DEF-5678', " +
    "'cria despesa de IPVA R$ 2.500 para o veículo XYZ-9999', " +
    "'adiciona despesa geral de pedágio R$ 87,50', " +
    "'lança seguro do carro ABC-1234 valor R$ 3.200'. " +
    "O registro fica pendente de confirmação — o usuário precisa aprovar antes da gravação.",
  input_schema: {
    type: "object",
    properties: {
      vehicle_identifier: {
        type: "string",
        description:
          "Placa (com ou sem hífen) ou UUID do veículo. Opcional — se omitido, a despesa é registrada como geral (sem veículo vinculado). Ex: 'ABC-1234' ou 'abc1234'.",
      },
      date: {
        type: "string",
        description:
          "Data da despesa no formato YYYY-MM-DD. Ex: '2026-05-10'.",
      },
      category: {
        type: "string",
        description:
          "Categoria da despesa. Valores aceitos: 'combustível', 'multa', 'IPVA', 'seguro', 'outros'. " +
          "Ex: 'combustível', 'multa'.",
        enum: ["combustível", "multa", "IPVA", "seguro", "outros"],
      },
      amount: {
        type: "number",
        description:
          "Valor da despesa em reais (R$). Deve ser maior que zero. Ex: 350.00, 195.23.",
      },
      description: {
        type: "string",
        description:
          "Descrição adicional ou detalhes da despesa (opcional). Ex: 'Tanque cheio etanol', 'Multa por excesso de velocidade na BR-101'.",
      },
    },
    required: ["date", "category", "amount"],
  },

  // ---------------------------------------------------------------
  // Preview: texto humanizado para confirmação do usuário
  // ---------------------------------------------------------------
  preview: async (input, ctx) => {
    const categoria = String(input.category || "");
    const valor = Number(input.amount).toFixed(2).replace(".", ",");

    let texto = `Lançar despesa: ${categoria} — R$ ${valor} em ${input.date}`;

    if (input.vehicle_identifier) {
      const placa = await resolveVehiclePlate(input.vehicle_identifier, ctx);
      if (placa) {
        texto += ` — ${placa}`;
      } else {
        texto += ` — Veículo não encontrado para "${input.vehicle_identifier}"`;
      }
    }

    return texto;
  },

  // ---------------------------------------------------------------
  // Handler: valida, resolve veículo (se informado), retorna dados
  // ---------------------------------------------------------------
  handler: async (input, ctx) => {
    // 1. Valida data
    const date = String(input.date);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return {
        ok: false,
        error: "Data inválida. Use o formato YYYY-MM-DD (ex: 2026-05-10).",
      };
    }

    // 2. Valida category -> tipo
    const tipo = mapearCategoria(input.category);
    if (!tipo) {
      return {
        ok: false,
        error:
          "Categoria inválida. Use: 'combustível', 'multa', 'IPVA', 'seguro' ou 'outros'.",
      };
    }

    // 3. Valida amount
    const valor = Number(input.amount);
    if (isNaN(valor) || valor <= 0) {
      return {
        ok: false,
        error: "Valor da despesa (amount) deve ser um número maior que zero.",
      };
    }

    // 4. Resolve veículo (opcional)
    let vehicle_plate: string | null = null;
    if (input.vehicle_identifier) {
      const placa = await resolveVehiclePlate(
        input.vehicle_identifier,
        ctx
      );
      if (!placa) {
        return {
          ok: false,
          error:
            "Veículo não encontrado. Se a despesa for geral, omita vehicle_identifier. Se for de um veículo específico, use uma placa válida (ex: ABC-1234).",
        };
      }
      vehicle_plate = placa;
    }

    // 5. Dados validados e normalizados
    const validatedData = {
      vehicle_plate,
      date,
      tipo,
      valor,
      descricao: input.description
        ? String(input.description).trim()
        : null,
    };

    // 6. Gera preview para exibição
    const display = (await createExpense.preview!(input, ctx)) ?? "";

    return { ok: true, data: validatedData, display };
  },
};
