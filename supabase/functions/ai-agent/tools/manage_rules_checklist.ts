import { AtrTool } from "../types.ts";

// ================================================================
// Criar/atualizar regra de manutenção
// ================================================================
export const createRegraManutencao: AtrTool = {
  name: "create_regra_manutencao",
  category: "write",
  description:
    "Cria uma nova regra de manutenção preventiva. " +
    "Use para: 'cria regra de troca de óleo a cada 10000 km', " +
    "'adiciona revisão anual para todos os veículos'.",
  input_schema: {
    type: "object",
    properties: {
      titulo: { type: "string", description: "Título da regra. Ex: 'Troca de óleo', 'Revisão anual'." },
      tipo: { type: "string", description: "Tipo de serviço." },
      veiculo_placa: { type: "string", description: "Placa do veículo (opcional — se omitido, aplica a todos)." },
      intervalo_km: { type: "integer", description: "Intervalo em km." },
      intervalo_dias: { type: "integer", description: "Intervalo em dias." },
      custo_estimado: { type: "number", description: "Custo estimado em R$." },
      prioridade: { type: "string", description: "Prioridade: 'alta', 'media', 'baixa'." },
    },
    required: ["titulo", "tipo"],
  },

  preview: async (input, _ctx) => {
    const km = input.intervalo_km ? ` a cada ${input.intervalo_km}km` : "";
    const dias = input.intervalo_dias ? ` a cada ${input.intervalo_dias} dias` : "";
    const placa = input.veiculo_placa ? ` (${input.veiculo_placa})` : " (todos)";
    return `Criar regra: "${input.titulo}"${placa}${km}${dias} — R$ ${Number(input.custo_estimado || 0).toFixed(2)}`;
  },

  handler: async (input, _ctx) => {
    const titulo = String(input.titulo).trim();
    const tipo = String(input.tipo).trim();
    if (!titulo || !tipo) return { ok: false, error: "Título e tipo são obrigatórios." };

    const validatedData: Record<string, unknown> = {
      titulo,
      tipo,
      veiculo_placa: input.veiculo_placa ? String(input.veiculo_placa).trim() : null,
      intervalo_km: input.intervalo_km != null ? Number(input.intervalo_km) : null,
      intervalo_dias: input.intervalo_dias != null ? Number(input.intervalo_dias) : null,
      custo_estimado: input.custo_estimado != null ? Number(input.custo_estimado) : 0,
      prioridade: input.prioridade ? String(input.prioridade).trim() : "media",
    };

    if (validatedData.prioridade && !["alta", "media", "baixa"].includes(String(validatedData.prioridade))) {
      return { ok: false, error: "Prioridade inválida. Use: 'alta', 'media' ou 'baixa'." };
    }

    const display = (await createRegraManutencao.preview!(input, _ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Criar ocorrência de contrato
// ================================================================
export const createOcorrencia: AtrTool = {
  name: "create_ocorrencia",
  category: "write",
  description:
    "Registra uma nova ocorrência (sinistro, avaria, multa) vinculada a um contrato. " +
    "Use para: 'registra batida no para-choque contrato CTR-001', " +
    "'lança multa de trânsito no contrato do cliente XPTO'.",
  input_schema: {
    type: "object",
    properties: {
      contrato_id: { type: "string", description: "ID (UUID) do contrato." },
      tipo: { type: "string", description: "Tipo de ocorrência: 'avaria', 'sinistro', 'multa', 'furto', 'outros'." },
      descricao: { type: "string", description: "Descrição detalhada da ocorrência." },
      data_ocorrencia: { type: "string", description: "Data YYYY-MM-DD." },
      valor_estimado: { type: "number", description: "Valor estimado do reparo/multa." },
      responsavel_pagamento: { type: "string", description: "Responsável: 'cliente', 'atr', 'seguro', 'terceiro'." },
      observacoes: { type: "string", description: "Observações adicionais." },
    },
    required: ["contrato_id", "tipo", "descricao"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("contratos")
      .select("id, numero, cliente_nome")
      .eq("tenant_id", tenantId).eq("id", String(input.contrato_id)).single();
    if (!data) return `Criar ocorrência: contrato ${input.contrato_id} não encontrado.`;
    return `Criar ocorrência "${input.tipo}" no contrato ${data.numero} (${data.cliente_nome}): ${String(input.descricao).substring(0, 80)}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data: contrato } = await (supabase as any).from("contratos")
      .select("id, numero").eq("tenant_id", tenantId).eq("id", String(input.contrato_id)).single();
    if (!contrato) return { ok: false, error: "Contrato não encontrado." };

    const validatedData: Record<string, unknown> = {
      contrato_id: String(input.contrato_id),
      tipo: String(input.tipo).trim(),
      descricao: String(input.descricao).trim(),
      data_ocorrencia: input.data_ocorrencia ? String(input.data_ocorrencia) : new Date().toISOString().split("T")[0],
      valor_estimado: input.valor_estimado != null ? Number(input.valor_estimado) : 0,
      responsavel_pagamento: input.responsavel_pagamento ? String(input.responsavel_pagamento).trim() : "cliente",
      observacoes: input.observacoes ? String(input.observacoes).trim() : "",
    };

    if (validatedData.data_ocorrencia && !/^\d{4}-\d{2}-\d{2}$/.test(String(validatedData.data_ocorrencia))) {
      return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
    }

    const display = (await createOcorrencia.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar regra de manutenção
// ================================================================
export const updateRegraManutencao: AtrTool = {
  name: "update_regra_manutencao",
  category: "write",
  description: "Atualiza uma regra de manutenção. Use para alterar intervalo, custo, ativar/desativar.",
  input_schema: {
    type: "object",
    properties: {
      regra_id: { type: "string", description: "ID da regra." },
      titulo: { type: "string", description: "Novo título." },
      intervalo_km: { type: "integer", description: "Novo intervalo em km." },
      intervalo_dias: { type: "integer", description: "Novo intervalo em dias." },
      custo_estimado: { type: "number", description: "Novo custo estimado." },
      prioridade: { type: "string", description: "Nova prioridade." },
      is_ativa: { type: "boolean", description: "Ativar (true) ou desativar (false)." },
      km_ultima_execucao: { type: "integer", description: "KM da última execução." },
    },
    required: ["regra_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("regras_manutencao")
      .select("id, titulo").eq("tenant_id", tenantId).eq("id", String(input.regra_id)).single();
    if (!data) return `Atualizar regra: ID ${input.regra_id} não encontrado.`;
    const mudancas: string[] = [];
    for (const [k, v] of Object.entries(input)) {
      if (k !== "regra_id" && v !== undefined && v !== null) mudancas.push(`${k}=${v}`);
    }
    return `Atualizar regra "${data.titulo}": ${mudancas.join(", ") || "sem alterações"}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.regra_id).trim();
    const { data } = await (supabase as any).from("regras_manutencao")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: `Regra ${id} não encontrada.` };

    const updates: Record<string, unknown> = {};
    if (input.titulo !== undefined) updates.titulo = String(input.titulo).trim();
    if (input.intervalo_km !== undefined) updates.intervalo_km = Number(input.intervalo_km);
    if (input.intervalo_dias !== undefined) updates.intervalo_dias = Number(input.intervalo_dias);
    if (input.custo_estimado !== undefined) updates.custo_estimado = Number(input.custo_estimado);
    if (input.prioridade !== undefined) updates.prioridade = String(input.prioridade).trim();
    if (input.is_ativa !== undefined) updates.is_ativa = Boolean(input.is_ativa);
    if (input.km_ultima_execucao !== undefined) updates.km_ultima_execucao = Number(input.km_ultima_execucao);

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateRegraManutencao.preview!(input, ctx)) ?? "";
    return { ok: true, data: { regra_id: id, updates }, display };
  },
};

// ================================================================
// Deletar ocorrência
// ================================================================
export const deleteOcorrencia: AtrTool = {
  name: "delete_ocorrencia",
  category: "write",
  description:
    "Remove uma ocorrência registrada incorretamente. " +
    "Use para: 'apaga ocorrência X registrada errado', 'remove sinistro duplicado'.",
  input_schema: {
    type: "object",
    properties: {
      ocorrencia_id: { type: "string", description: "ID (UUID) da ocorrência a remover." },
    },
    required: ["ocorrencia_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("ocorrencias")
      .select("id, tipo, descricao")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.ocorrencia_id))
      .single();
    if (!data) return `Deletar ocorrência: ID ${input.ocorrencia_id} não encontrado.`;
    return `Deletar ocorrência "${data.tipo}": ${String(data.descricao).substring(0, 60)}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.ocorrencia_id).trim();

    const { data } = await (supabase as any)
      .from("ocorrencias")
      .select("id, tipo")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Ocorrência não encontrada." };

    const display = (await deleteOcorrencia.preview!(input, ctx)) ?? "";
    return { ok: true, data: { ocorrencia_id: id }, display };
  },
};

// ================================================================
// Deletar regra de manutenção
// ================================================================
export const deleteRegraManutencao: AtrTool = {
  name: "delete_regra_manutencao",
  category: "write",
  description:
    "Remove uma regra de manutenção obsoleta ou criada incorretamente. " +
    "Use para: 'apaga regra de troca de óleo duplicada', 'remove regra desatualizada'.",
  input_schema: {
    type: "object",
    properties: {
      regra_id: { type: "string", description: "ID da regra de manutenção a remover." },
    },
    required: ["regra_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any)
      .from("regras_manutencao")
      .select("id, titulo")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.regra_id))
      .single();
    if (!data) return `Deletar regra: ID ${input.regra_id} não encontrado.`;
    return `Deletar regra de manutenção: "${data.titulo}"`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.regra_id).trim();

    const { data } = await (supabase as any)
      .from("regras_manutencao")
      .select("id, titulo")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Regra de manutenção não encontrada." };

    const display = (await deleteRegraManutencao.preview!(input, ctx)) ?? "";
    return { ok: true, data: { regra_id: id }, display };
  },
};

// ================================================================
// Atualizar ocorrência de contrato
// ================================================================
export const updateOcorrencia: AtrTool = {
  name: "update_ocorrencia",
  category: "write",
  description:
    "Atualiza uma ocorrência (sinistro, avaria, multa) — pode fechar/resolver com valor final. " +
    "Use para: 'resolve a avaria CTR-001 com custo de R$2.800', " +
    "'marca sinistro como resolvido'.",
  input_schema: {
    type: "object",
    properties: {
      ocorrencia_id: { type: "string", description: "ID (UUID) da ocorrência." },
      status: { type: "string", description: "Novo status: 'aberta', 'resolvida'." },
      valor_final: { type: "number", description: "Valor final (após resolução). Obrigatório se status='resolvida'." },
      resolvido_por: { type: "string", description: "Quem resolveu (opcional)." },
      data_resolucao: { type: "string", description: "Data de resolução YYYY-MM-DD (obrigatório se status='resolvida')." },
      observacoes: { type: "string", description: "Observações adicionais." },
    },
    required: ["ocorrencia_id", "status"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("ocorrencias")
      .select("id, tipo, descricao, status").eq("tenant_id", tenantId).eq("id", String(input.ocorrencia_id)).single();
    if (!data) return `Atualizar ocorrência: ID ${input.ocorrencia_id} não encontrado.`;
    return `Atualizar ocorrência "${data.tipo}" para status "${input.status}"${input.valor_final ? ` com custo final R$ ${Number(input.valor_final).toFixed(2)}` : ""}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const ocorrenciaId = String(input.ocorrencia_id).trim();
    const { data: ocorrencia } = await (supabase as any).from("ocorrencias")
      .select("id, status, valor_estimado").eq("tenant_id", tenantId).eq("id", ocorrenciaId).single();
    if (!ocorrencia) return { ok: false, error: "Ocorrência não encontrada." };

    const novoStatus = String(input.status).trim();
    if (!["aberta", "resolvida"].includes(novoStatus)) {
      return { ok: false, error: "Status inválido. Use: 'aberta' ou 'resolvida'." };
    }

    const updates: Record<string, unknown> = { status: novoStatus };

    // Se fechando (resolvida), validar campos obrigatórios
    if (novoStatus === "resolvida") {
      if (input.valor_final === undefined || input.valor_final === null) {
        return { ok: false, error: "valor_final é obrigatório para resolver ocorrência." };
      }
      const valorFinal = Number(input.valor_final);
      if (valorFinal < 0) return { ok: false, error: "valor_final deve ser >= 0." };
      updates.valor_final = valorFinal;

      if (!input.data_resolucao) {
        return { ok: false, error: "data_resolucao é obrigatória para resolver ocorrência." };
      }
      if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data_resolucao))) {
        return { ok: false, error: "data_resolucao inválida. Use YYYY-MM-DD." };
      }
      updates.data_resolucao = String(input.data_resolucao);

      if (input.resolvido_por) {
        updates.resolvido_por = String(input.resolvido_por).trim();
      }
    }

    if (input.observacoes) {
      updates.observacoes = String(input.observacoes).trim();
    }

    const display = (await updateOcorrencia.preview!(input, ctx)) ?? "";
    return { ok: true, data: { ocorrencia_id: ocorrenciaId, updates }, display };
  },
};
