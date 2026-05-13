import { AtrTool } from "../types.ts";

// ================================================================
// Listar eventos de Lazer com filtros
// ================================================================
export const listLazerEventos: AtrTool = {
  name: "list_lazer_eventos",
  category: "read",
  description:
    "Lista eventos de Lazer com filtros opcionais por status e período. " +
    "Use para: 'mostra eventos planejados', 'lista eventos do mês'.",
  input_schema: {
    type: "object",
    properties: {
      status: { type: "string", description: "Filtrar por status: 'Planejado', 'Realizado', 'Cancelado'." },
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD (opcional)." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD (opcional)." },
    },
    required: [],
  },

  preview: async (input, _ctx) => {
    const statusText = input.status ? ` status=${input.status}` : "";
    const periodoText = input.data_inicio ? ` (${input.data_inicio} a ${input.data_fim})` : "";
    return `Listar eventos de Lazer${statusText}${periodoText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    let query = (supabase as any).from("lazer_eventos")
      .select("*")
      .eq("tenant_id", tenantId);

    if (input.status) {
      query = query.eq("status", String(input.status).trim());
    }

    if (input.data_inicio && input.data_fim) {
      query = query.gte("data", String(input.data_inicio)).lte("data", String(input.data_fim));
    }

    const { data, error } = await query.order("data", { ascending: false });
    if (error) return { ok: false, error: `Erro ao listar eventos: ${error.message}` };

    return {
      ok: true,
      data: {
        total: (data as Array<unknown>).length,
        eventos: data,
      },
    };
  },
};

// ================================================================
// Listar despesas de Lazer
// ================================================================
export const listLazerDespesas: AtrTool = {
  name: "list_lazer_despesas",
  category: "read",
  description: "Lista despesas de Lazer, opcionalmente filtradas por evento ou período.",
  input_schema: {
    type: "object",
    properties: {
      evento_id: { type: "string", description: "Filtrar por evento (opcional)." },
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD (opcional)." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD (opcional)." },
    },
    required: [],
  },

  preview: async (input, _ctx) => {
    const eventoText = input.evento_id ? ` evento=${input.evento_id}` : "";
    const periodoText = input.data_inicio ? ` (${input.data_inicio} a ${input.data_fim})` : "";
    return `Listar despesas Lazer${eventoText}${periodoText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    let query = (supabase as any).from("lazer_despesas")
      .select("*")
      .eq("tenant_id", tenantId);

    if (input.evento_id) {
      query = query.eq("evento_id", String(input.evento_id));
    }

    if (input.data_inicio && input.data_fim) {
      query = query.gte("data", String(input.data_inicio)).lte("data", String(input.data_fim));
    }

    const { data, error } = await query.order("data", { ascending: false });
    if (error) return { ok: false, error: `Erro ao listar despesas: ${error.message}` };

    const totalDespesas = (data as Array<any>).reduce((sum, d) => sum + (d.valor || 0), 0);
    return { ok: true, data: { total_despesas: (data as Array<unknown>).length, valor_total: totalDespesas, despesas: data } };
  },
};

// ================================================================
// Criar evento de Lazer
// ================================================================
export const createLazerEvento: AtrTool = {
  name: "create_lazer_evento",
  category: "write",
  description:
    "Cria um novo evento de Lazer. " +
    "Use para: 'cria evento churrasco no próximo sábado', 'agenda festa de confraternização'.",
  input_schema: {
    type: "object",
    properties: {
      nome: { type: "string", description: "Nome do evento." },
      tipo: { type: "string", description: "Tipo: 'Confraternização', 'Churrasco', 'Reunião Social', 'Outro'." },
      data: { type: "string", description: "Data YYYY-MM-DD." },
      local: { type: "string", description: "Local do evento (opcional)." },
      quantidade_pessoas: { type: "integer", description: "Quantidade estimada de pessoas." },
      receita_total: { type: "number", description: "Receita esperada em R$ (0 se sem custo)." },
      status: { type: "string", description: "Status inicial: 'Planejado', 'Realizado'. Default 'Planejado'." },
    },
    required: ["nome", "tipo", "data", "quantidade_pessoas"],
  },

  preview: async (input, _ctx) => {
    return `Criar evento Lazer: "${input.nome}" em ${input.data} (${input.tipo})`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data))) {
      return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
    }

    const validatedData: Record<string, unknown> = {
      nome: String(input.nome).trim(),
      tipo: String(input.tipo).trim(),
      data: String(input.data),
      local: input.local ? String(input.local).trim() : null,
      quantidade_pessoas: Number(input.quantidade_pessoas),
      receita_total: input.receita_total != null ? Number(input.receita_total) : 0,
      custo_total: 0,
      status: input.status ? String(input.status).trim() : "Planejado",
    };

    const display = (await createLazerEvento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar evento de Lazer
// ================================================================
export const updateLazerEvento: AtrTool = {
  name: "update_lazer_evento",
  category: "write",
  description: "Atualiza um evento de Lazer (status, receita, local).",
  input_schema: {
    type: "object",
    properties: {
      evento_id: { type: "string", description: "ID do evento." },
      nome: { type: "string", description: "Novo nome (opcional)." },
      data: { type: "string", description: "Nova data (opcional)." },
      status: { type: "string", description: "Novo status (opcional)." },
      receita_total: { type: "number", description: "Nova receita (opcional)." },
    },
    required: ["evento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("lazer_eventos")
      .select("id, nome").eq("tenant_id", tenantId).eq("id", String(input.evento_id)).single();
    if (!data) return `Atualizar evento: ID ${input.evento_id} não encontrado.`;
    return `Atualizar evento "${data.nome}"`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.evento_id).trim();

    const { data } = await (supabase as any).from("lazer_eventos")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Evento não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.nome !== undefined) updates.nome = String(input.nome).trim();
    if (input.data !== undefined) updates.data = String(input.data);
    if (input.status !== undefined) updates.status = String(input.status).trim();
    if (input.receita_total !== undefined) updates.receita_total = Number(input.receita_total);

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateLazerEvento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { evento_id: id, updates }, display };
  },
};

// ================================================================
// Deletar evento de Lazer
// ================================================================
export const deleteLazerEvento: AtrTool = {
  name: "delete_lazer_evento",
  category: "write",
  description: "Remove um evento de Lazer.",
  input_schema: {
    type: "object",
    properties: {
      evento_id: { type: "string", description: "ID do evento a deletar." },
    },
    required: ["evento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("lazer_eventos")
      .select("id, nome").eq("tenant_id", tenantId).eq("id", String(input.evento_id)).single();
    if (!data) return `Deletar evento: ID não encontrado.`;
    return `Cancelar evento "${data.nome}"`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.evento_id).trim();

    const { data } = await (supabase as any).from("lazer_eventos")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Evento não encontrado." };

    const display = (await deleteLazerEvento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { evento_id: id }, display };
  },
};

// ================================================================
// Criar despesa de Lazer
// ================================================================
export const createLazerDespesa: AtrTool = {
  name: "create_lazer_despesa",
  category: "write",
  description:
    "Registra uma despesa de Lazer (pode estar vinculada a um evento). " +
    "Use para: 'registra gasto R$200 com refrigerante para o churrasco'.",
  input_schema: {
    type: "object",
    properties: {
      evento_id: { type: "string", description: "ID do evento (opcional, se não informado é despesa geral)." },
      descricao: { type: "string", description: "Descrição da despesa." },
      valor: { type: "number", description: "Valor em R$." },
      data: { type: "string", description: "Data YYYY-MM-DD (opcional, default hoje)." },
      categoria: { type: "string", description: "Categoria (default 'Geral')." },
      pago: { type: "boolean", description: "Se já foi pago (default false)." },
    },
    required: ["descricao", "valor"],
  },

  preview: async (input, _ctx) => {
    const eventoText = input.evento_id ? ` para evento ${input.evento_id}` : "";
    return `Registrar despesa Lazer: ${input.descricao} R$ ${Number(input.valor).toFixed(2)}${eventoText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const valor = Number(input.valor);
    if (valor <= 0) return { ok: false, error: "Valor deve ser > 0." };

    const validatedData: Record<string, unknown> = {
      evento_id: input.evento_id ? String(input.evento_id) : null,
      descricao: String(input.descricao).trim(),
      valor,
      data: input.data ? String(input.data) : new Date().toISOString().split("T")[0],
      categoria: input.categoria ? String(input.categoria).trim() : "Geral",
      pago: input.pago !== undefined ? Boolean(input.pago) : false,
    };

    const display = (await createLazerDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar despesa de Lazer
// ================================================================
export const updateLazerDespesa: AtrTool = {
  name: "update_lazer_despesa",
  category: "write",
  description: "Atualiza uma despesa de Lazer.",
  input_schema: {
    type: "object",
    properties: {
      despesa_id: { type: "string", description: "ID da despesa." },
      descricao: { type: "string", description: "Nova descrição (opcional)." },
      valor: { type: "number", description: "Novo valor (opcional)." },
      pago: { type: "boolean", description: "Marcar como pago (opcional)." },
    },
    required: ["despesa_id"],
  },

  preview: async (input, _ctx) => `Atualizar despesa Lazer: ${input.despesa_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.despesa_id).trim();

    const { data } = await (supabase as any).from("lazer_despesas")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Despesa não encontrada." };

    const updates: Record<string, unknown> = {};
    if (input.descricao !== undefined) updates.descricao = String(input.descricao).trim();
    if (input.valor !== undefined) updates.valor = Number(input.valor);
    if (input.pago !== undefined) updates.pago = Boolean(input.pago);

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateLazerDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: { despesa_id: id, updates }, display };
  },
};

// ================================================================
// Deletar despesa de Lazer
// ================================================================
export const deleteLazerDespesa: AtrTool = {
  name: "delete_lazer_despesa",
  category: "write",
  description: "Remove uma despesa de Lazer.",
  input_schema: {
    type: "object",
    properties: {
      despesa_id: { type: "string", description: "ID da despesa a deletar." },
    },
    required: ["despesa_id"],
  },

  preview: async (input, _ctx) => `Deletar despesa Lazer: ${input.despesa_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.despesa_id).trim();

    const { data } = await (supabase as any).from("lazer_despesas")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Despesa não encontrada." };

    const display = (await deleteLazerDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: { despesa_id: id }, display };
  },
};

// ================================================================
// Relatório financeiro de Lazer
// ================================================================
export const relatorioLazer: AtrTool = {
  name: "relatorio_lazer",
  category: "read",
  description:
    "Gera relatório financeiro completo de Lazer num período " +
    "(total eventos, receita, custos, resultado, margem).",
  input_schema: {
    type: "object",
    properties: {
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD." },
    },
    required: ["data_inicio", "data_fim"],
  },

  preview: async (input, _ctx) => `Relatório Lazer: ${input.data_inicio} a ${input.data_fim}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const { data: eventos, error: evErr } = await (supabase as any).from("lazer_eventos")
      .select("*")
      .eq("tenant_id", tenantId)
      .gte("data", String(input.data_inicio))
      .lte("data", String(input.data_fim));

    if (evErr) return { ok: false, error: `Erro ao gerar relatório: ${evErr.message}` };

    const { data: despesas } = await (supabase as any).from("lazer_despesas")
      .select("valor")
      .eq("tenant_id", tenantId)
      .gte("data", String(input.data_inicio))
      .lte("data", String(input.data_fim));

    const totalEventos = (eventos as Array<any>).length;
    const eventosRealizados = (eventos as Array<any>).filter((e) => e.status === "Realizado").length;
    const receita = (eventos as Array<any>).reduce((sum, e) => sum + (e.receita_total || 0), 0);
    const custos = (despesas as Array<any>).reduce((sum, d) => sum + (d.valor || 0), 0);
    const resultado = receita - custos;

    return {
      ok: true,
      data: {
        periodo: `${input.data_inicio} a ${input.data_fim}`,
        total_eventos: totalEventos,
        eventos_realizados: eventosRealizados,
        eventos_planejados: totalEventos - eventosRealizados,
        receita_total: receita,
        custos_totais: custos,
        resultado_liquido: resultado,
        margem_percentual: receita > 0 ? ((resultado / receita) * 100).toFixed(1) : "N/A",
        custo_medio_evento: totalEventos > 0 ? (custos / totalEventos).toFixed(2) : "0",
      },
    };
  },
};
