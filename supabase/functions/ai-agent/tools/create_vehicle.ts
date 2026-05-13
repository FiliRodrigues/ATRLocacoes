import { AtrTool } from "../types.ts";

export const createVehicle: AtrTool = {
  name: "create_vehicle",
  category: "write",
  description:
    "Cadastra um novo veículo na frota ATR Locações. " +
    "Use para: 'cadastra veículo ABC-1234 Toyota Hilux 2023', " +
    "'adiciona carro novo placa DEF-5678', " +
    "'registra caminhão na frota'.",
  input_schema: {
    type: "object",
    properties: {
      placa: {
        type: "string",
        description: "Placa do veículo (obrigatório). Ex: 'ABC-1234' ou 'ABC1234'.",
      },
      tipo: {
        type: "string",
        description: "Tipo do veículo. Ex: 'Carro', 'Caminhão', 'Moto', 'Van', 'SUV'.",
      },
      marca: {
        type: "string",
        description: "Marca. Ex: 'Toyota', 'Volkswagen', 'Honda'.",
      },
      modelo: {
        type: "string",
        description: "Modelo. Ex: 'Hilux', 'Gol', 'Civic'.",
      },
      ano_fabricacao_modelo: {
        type: "string",
        description: "Ano de fabricação/modelo. Ex: '2023/2023', '2022'.",
      },
      renavam: {
        type: "string",
        description: "Número do RENAVAM (opcional).",
      },
      chassi: {
        type: "string",
        description: "Número do chassi (opcional).",
      },
      km_inicial: {
        type: "number",
        description: "Quilometragem inicial do veículo.",
      },
      km_atual: {
        type: "integer",
        description: "Quilometragem atual do veículo.",
      },
      situacao_operacional: {
        type: "string",
        description: "Situação operacional. Ex: 'Disponível', 'Locado', 'Em manutenção', 'Indisponível'.",
      },
      propriedade_status: {
        type: "string",
        description: "Status de propriedade. Ex: 'Próprio', 'Financiado', 'Locado'.",
      },
      valor_veiculo: {
        type: "number",
        description: "Valor de aquisição do veículo em reais.",
      },
      numero_nota_fiscal: {
        type: "string",
        description: "Número da nota fiscal de compra.",
      },
      data_compra: {
        type: "string",
        description: "Data da compra no formato YYYY-MM-DD.",
      },
      observacoes: {
        type: "string",
        description: "Observações adicionais.",
      },
    },
    required: ["placa"],
  },

  preview: async (input, _ctx) => {
    const placa = String(input.placa || "").toUpperCase();
    const modelo = input.modelo ? ` ${input.modelo}` : "";
    const marca = input.marca ? `${input.marca}` : "";
    const nome = [marca, modelo].filter(Boolean).join("") || "Veículo";
    return `Cadastrar veículo: ${nome} — Placa ${placa}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const placa = String(input.placa || "").replace("-", "").toUpperCase();

    if (!placa || placa.length < 3) {
      return { ok: false, error: "Placa inválida. Informe uma placa válida (ex: ABC-1234)." };
    }

    // Verifica duplicidade de placa
    const { data: existente } = await (supabase as any)
      .from("veiculos")
      .select("id, placa")
      .eq("tenant_id", tenantId)
      .ilike("placa", placa)
      .maybeSingle();

    if (existente) {
      return { ok: false, error: `Já existe um veículo com a placa ${placa}.` };
    }

    const validatedData: Record<string, unknown> = {
      placa,
      tipo: input.tipo ? String(input.tipo).trim() : null,
      marca: input.marca ? String(input.marca).trim() : null,
      modelo: input.modelo ? String(input.modelo).trim() : null,
      ano_fabricacao_modelo: input.ano_fabricacao_modelo ? String(input.ano_fabricacao_modelo).trim() : null,
      renavam: input.renavam ? String(input.renavam).trim() : null,
      chassi: input.chassi ? String(input.chassi).trim() : null,
      km_inicial: input.km_inicial != null ? Number(input.km_inicial) : null,
      km_atual: input.km_atual != null ? Number(input.km_atual) : null,
      situacao_operacional: input.situacao_operacional ? String(input.situacao_operacional).trim() : null,
      propriedade_status: input.propriedade_status ? String(input.propriedade_status).trim() : null,
      valor_veiculo: input.valor_veiculo != null ? Number(input.valor_veiculo) : null,
      numero_nota_fiscal: input.numero_nota_fiscal ? String(input.numero_nota_fiscal).trim() : null,
      data_compra: input.data_compra ? String(input.data_compra).trim() : null,
      observacoes: input.observacoes ? String(input.observacoes).trim() : null,
    };

    // Valida data_compra se informada
    if (validatedData.data_compra && !/^\d{4}-\d{2}-\d{2}$/.test(String(validatedData.data_compra))) {
      return { ok: false, error: "Data de compra inválida. Use o formato YYYY-MM-DD." };
    }

    const display = (await createVehicle.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};
