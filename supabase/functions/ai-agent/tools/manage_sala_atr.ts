import { AtrTool } from "../types.ts";

// ================================================================
// Listar agendamentos da Sala ATR com filtros
// ================================================================
export const listSalaAtrAgendamentos: AtrTool = {
  name: "list_sala_atr_agendamentos",
  category: "read",
  description:
    "Lista agendamentos da Sala ATR com filtros opcionais por data, período e status. " +
    "Use para: 'mostra agendamentos de hoje', 'lista eventos confirmados desta semana', 'mostra sala disponível'.",
  input_schema: {
    type: "object",
    properties: {
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD (opcional, default hoje)." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD (opcional, default = data_inicio)." },
      status: { type: "string", description: "Filtrar por status: 'Confirmado', 'Pendente', 'Pago', 'Realizado', 'Cancelado'." },
    },
    required: [],
  },

  preview: async (input, _ctx) => {
    const dataInicio = input.data_inicio ? String(input.data_inicio) : new Date().toISOString().split("T")[0];
    const statusText = input.status ? ` status=${input.status}` : "";
    return `Listar agendamentos Sala ATR de ${dataInicio}${statusText}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const dataInicio = input.data_inicio ? String(input.data_inicio) : new Date().toISOString().split("T")[0];
    const dataFim = input.data_fim ? String(input.data_fim) : dataInicio;

    let query = (supabase as any).from("sala_atr_agendamentos")
      .select("*")
      .eq("tenant_id", tenantId)
      .gte("data", dataInicio)
      .lte("data", dataFim);

    if (input.status) {
      query = query.eq("status", String(input.status).trim());
    }

    const { data, error } = await query.order("data", { ascending: true }).order("hora_inicio", { ascending: true });
    if (error) return { ok: false, error: `Erro ao listar agendamentos: ${error.message}` };

    return {
      ok: true,
      data: {
        total: (data as Array<unknown>).length,
        agendamentos: data,
      },
    };
  },
};

// ================================================================
// Obter detalhes de um agendamento específico
// ================================================================
export const getSalaAtrAgendamento: AtrTool = {
  name: "get_sala_atr_agendamento",
  category: "read",
  description: "Obtém detalhes de um agendamento da Sala ATR específico.",
  input_schema: {
    type: "object",
    properties: {
      agendamento_id: { type: "string", description: "ID (UUID) do agendamento." },
    },
    required: ["agendamento_id"],
  },

  preview: async (input, _ctx) => `Obter agendamento Sala ATR: ${input.agendamento_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const { data, error } = await (supabase as any).from("sala_atr_agendamentos")
      .select("*")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.agendamento_id))
      .single();

    if (error || !data) return { ok: false, error: "Agendamento não encontrado." };
    return { ok: true, data };
  },
};

// ================================================================
// Listar despesas da Sala ATR
// ================================================================
export const listSalaAtrDespesas: AtrTool = {
  name: "list_sala_atr_despesas",
  category: "read",
  description: "Lista despesas da Sala ATR com filtros opcionais.",
  input_schema: {
    type: "object",
    properties: {
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD (opcional)." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD (opcional)." },
    },
    required: [],
  },

  preview: async (input, _ctx) => {
    const periodo = input.data_inicio && input.data_fim ? ` de ${input.data_inicio} a ${input.data_fim}` : "";
    return `Listar despesas Sala ATR${periodo}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    let query = (supabase as any).from("sala_atr_despesas")
      .select("*")
      .eq("tenant_id", tenantId);

    if (input.data_inicio && input.data_fim) {
      query = query.gte("data", String(input.data_inicio)).lte("data", String(input.data_fim));
    }

    const { data, error } = await query.order("data", { ascending: false });
    if (error) return { ok: false, error: `Erro ao listar despesas: ${error.message}` };

    const total = (data as Array<any>).reduce((sum, d) => sum + (d.valor || 0), 0);
    return { ok: true, data: { total_despesas: (data as Array<unknown>).length, valor_total: total, despesas: data } };
  },
};

// ================================================================
// Listar pacotes de sessões
// ================================================================
export const listSalaAtrPacotes: AtrTool = {
  name: "list_sala_atr_pacotes",
  category: "read",
  description: "Lista pacotes de sessões (clientes com sessões pré-pagas).",
  input_schema: {
    type: "object",
    properties: {
      ativo_only: { type: "boolean", description: "Se true, retorna apenas pacotes ativos (sessoes_usadas < total_sessoes)." },
    },
    required: [],
  },

  preview: async (input, _ctx) => `Listar pacotes${input.ativo_only ? " (apenas ativos)" : ""}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const { data, error } = await (supabase as any).from("sala_atr_pacotes")
      .select("*")
      .eq("tenant_id", tenantId)
      .order("cliente_nome");

    if (error) return { ok: false, error: `Erro ao listar pacotes: ${error.message}` };

    let pacotes = data as Array<any>;
    if (input.ativo_only) {
      pacotes = pacotes.filter((p) => p.sessoes_usadas < p.total_sessoes);
    }

    return { ok: true, data: { total_pacotes: pacotes.length, pacotes } };
  },
};

// ================================================================
// Verificar disponibilidade de horário (validação crítica)
// ================================================================
export const checkDisponibilidadeSala: AtrTool = {
  name: "check_disponibilidade_sala",
  category: "read",
  description:
    "Verifica se a Sala ATR está disponível num horário específico. " +
    "Retorna conflitos se houver sobreposição. Use ANTES de criar agendamento.",
  input_schema: {
    type: "object",
    properties: {
      data: { type: "string", description: "Data YYYY-MM-DD." },
      hora_inicio: { type: "string", description: "Hora inicial HH:MM." },
      hora_fim: { type: "string", description: "Hora final HH:MM." },
      excluir_agendamento_id: { type: "string", description: "ID do agendamento a excluir da verificação (para UPDATE)." },
    },
    required: ["data", "hora_inicio", "hora_fim"],
  },

  preview: async (input, _ctx) => `Verificar disponibilidade ${input.data} ${input.hora_inicio}-${input.hora_fim}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    let query = (supabase as any).from("sala_atr_agendamentos")
      .select("id, hora_inicio, hora_fim, cliente_nome, status")
      .eq("tenant_id", tenantId)
      .eq("data", String(input.data))
      .neq("status", "Cancelado");

    const { data: conflitos, error } = await query;
    if (error) return { ok: false, error: `Erro ao verificar disponibilidade: ${error.message}` };

    const novaHoraInicio = String(input.hora_inicio);
    const novaHoraFim = String(input.hora_fim);
    const excluirId = input.excluir_agendamento_id ? String(input.excluir_agendamento_id) : null;

    const sobreposicoes = (conflitos as Array<any>).filter((a) => {
      if (excluirId && a.id === excluirId) return false;
      // Verifica se há sobreposição: não(fim_novo <= inicio_existente OU inicio_novo >= fim_existente)
      return !(novaHoraFim <= a.hora_inicio || novaHoraInicio >= a.hora_fim);
    });

    return {
      ok: true,
      data: {
        disponivel: sobreposicoes.length === 0,
        conflitos_encontrados: sobreposicoes.length,
        conflitos: sobreposicoes,
      },
    };
  },
};

// ================================================================
// Criar agendamento na Sala ATR
// ================================================================
export const createSalaAtrAgendamento: AtrTool = {
  name: "create_sala_atr_agendamento",
  category: "write",
  description:
    "Cria um novo agendamento na Sala ATR. " +
    "⚠️ OBRIGATÓRIO: Usar check_disponibilidade_sala ANTES de chamar esta tool.",
  input_schema: {
    type: "object",
    properties: {
      data: { type: "string", description: "Data YYYY-MM-DD." },
      hora_inicio: { type: "string", description: "Hora inicial HH:MM." },
      hora_fim: { type: "string", description: "Hora final HH:MM." },
      cliente_nome: { type: "string", description: "Nome do cliente." },
      quantidade_pessoas: { type: "integer", description: "Quantidade de pessoas." },
      tipo_evento: { type: "string", description: "Tipo: 'Reunião', 'Workshop', 'Treinamento', 'Evento', 'Outro'." },
      pacote: { type: "string", description: "Se cliente tem pacote, especificar (ex: 'Pack 10'). Opcional." },
      valor: { type: "number", description: "Valor do agendamento (opcional)." },
      status: { type: "string", description: "Status inicial: 'Confirmado', 'Pendente'. Default 'Confirmado'." },
      observacoes: { type: "string", description: "Observações (opcional)." },
    },
    required: ["data", "hora_inicio", "hora_fim", "cliente_nome", "quantidade_pessoas", "tipo_evento"],
  },

  preview: async (input, _ctx) => {
    return `Agendar Sala ATR: ${input.cliente_nome} em ${input.data} ${input.hora_inicio}-${input.hora_fim} (${input.tipo_evento})`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    // Validações básicas
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.data))) return { ok: false, error: "Data inválida. Use YYYY-MM-DD." };
    if (!/^\d{2}:\d{2}$/.test(String(input.hora_inicio))) return { ok: false, error: "Hora inicial inválida. Use HH:MM." };
    if (!/^\d{2}:\d{2}$/.test(String(input.hora_fim))) return { ok: false, error: "Hora final inválida. Use HH:MM." };

    const validatedData: Record<string, unknown> = {
      data: String(input.data),
      hora_inicio: String(input.hora_inicio),
      hora_fim: String(input.hora_fim),
      cliente_nome: String(input.cliente_nome).trim(),
      quantidade_pessoas: Number(input.quantidade_pessoas),
      tipo_evento: String(input.tipo_evento).trim(),
      pacote: input.pacote ? String(input.pacote).trim() : null,
      valor: input.valor != null ? Number(input.valor) : null,
      status: input.status ? String(input.status).trim() : "Confirmado",
      observacoes: input.observacoes ? String(input.observacoes).trim() : null,
    };

    const display = (await createSalaAtrAgendamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar agendamento
// ================================================================
export const updateSalaAtrAgendamento: AtrTool = {
  name: "update_sala_atr_agendamento",
  category: "write",
  description:
    "Atualiza um agendamento existente (cliente, hora, status, etc). " +
    "Se mudar horário, usar check_disponibilidade_sala com excluir_agendamento_id.",
  input_schema: {
    type: "object",
    properties: {
      agendamento_id: { type: "string", description: "ID do agendamento a atualizar." },
      data: { type: "string", description: "Nova data (opcional)." },
      hora_inicio: { type: "string", description: "Nova hora inicial (opcional)." },
      hora_fim: { type: "string", description: "Nova hora final (opcional)." },
      status: { type: "string", description: "Novo status (opcional)." },
      valor: { type: "number", description: "Novo valor (opcional)." },
      observacoes: { type: "string", description: "Novas observações (opcional)." },
    },
    required: ["agendamento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("sala_atr_agendamentos")
      .select("id, cliente_nome").eq("tenant_id", tenantId).eq("id", String(input.agendamento_id)).single();
    if (!data) return `Atualizar agendamento: ID ${input.agendamento_id} não encontrado.`;
    return `Atualizar agendamento de ${data.cliente_nome}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.agendamento_id).trim();

    const { data } = await (supabase as any).from("sala_atr_agendamentos")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Agendamento não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.data !== undefined) updates.data = String(input.data);
    if (input.hora_inicio !== undefined) updates.hora_inicio = String(input.hora_inicio);
    if (input.hora_fim !== undefined) updates.hora_fim = String(input.hora_fim);
    if (input.status !== undefined) updates.status = String(input.status).trim();
    if (input.valor !== undefined) updates.valor = Number(input.valor);
    if (input.observacoes !== undefined) updates.observacoes = String(input.observacoes).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateSalaAtrAgendamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { agendamento_id: id, updates }, display };
  },
};

// ================================================================
// Deletar agendamento
// ================================================================
export const deleteSalaAtrAgendamento: AtrTool = {
  name: "delete_sala_atr_agendamento",
  category: "write",
  description: "Cancela/remove um agendamento.",
  input_schema: {
    type: "object",
    properties: {
      agendamento_id: { type: "string", description: "ID do agendamento a deletar." },
      motivo: { type: "string", description: "Motivo do cancelamento (opcional)." },
    },
    required: ["agendamento_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("sala_atr_agendamentos")
      .select("id, cliente_nome").eq("tenant_id", tenantId).eq("id", String(input.agendamento_id)).single();
    if (!data) return `Deletar agendamento: ID não encontrado.`;
    return `Cancelar agendamento de ${data.cliente_nome}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.agendamento_id).trim();

    const { data } = await (supabase as any).from("sala_atr_agendamentos")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Agendamento não encontrado." };

    const display = (await deleteSalaAtrAgendamento.preview!(input, ctx)) ?? "";
    return { ok: true, data: { agendamento_id: id }, display };
  },
};

// ================================================================
// Criar despesa da Sala ATR
// ================================================================
export const createSalaAtrDespesa: AtrTool = {
  name: "create_sala_atr_despesa",
  category: "write",
  description:
    "Registra uma nova despesa da Sala ATR (limpeza, manutenção, etc). " +
    "Use para: 'registra gasto com limpeza R$150', 'adiciona custo de café R$45'.",
  input_schema: {
    type: "object",
    properties: {
      descricao: { type: "string", description: "Descrição da despesa." },
      valor: { type: "number", description: "Valor em R$." },
      data: { type: "string", description: "Data YYYY-MM-DD (opcional, default hoje)." },
      categoria: { type: "string", description: "Categoria (default 'Geral')." },
      pago: { type: "boolean", description: "Se já foi pago (default false)." },
    },
    required: ["descricao", "valor"],
  },

  preview: async (input, _ctx) => `Registrar despesa Sala ATR: ${input.descricao} R$ ${Number(input.valor).toFixed(2)}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const valor = Number(input.valor);
    if (valor <= 0) return { ok: false, error: "Valor deve ser > 0." };

    const validatedData: Record<string, unknown> = {
      descricao: String(input.descricao).trim(),
      valor,
      data: input.data ? String(input.data) : new Date().toISOString().split("T")[0],
      categoria: input.categoria ? String(input.categoria).trim() : "Geral",
      pago: input.pago !== undefined ? Boolean(input.pago) : false,
    };

    const display = (await createSalaAtrDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar despesa
// ================================================================
export const updateSalaAtrDespesa: AtrTool = {
  name: "update_sala_atr_despesa",
  category: "write",
  description: "Atualiza uma despesa da Sala ATR.",
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

  preview: async (input, _ctx) => `Atualizar despesa Sala ATR: ${input.despesa_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.despesa_id).trim();

    const { data } = await (supabase as any).from("sala_atr_despesas")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Despesa não encontrada." };

    const updates: Record<string, unknown> = {};
    if (input.descricao !== undefined) updates.descricao = String(input.descricao).trim();
    if (input.valor !== undefined) updates.valor = Number(input.valor);
    if (input.pago !== undefined) updates.pago = Boolean(input.pago);

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateSalaAtrDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: { despesa_id: id, updates }, display };
  },
};

// ================================================================
// Deletar despesa
// ================================================================
export const deleteSalaAtrDespesa: AtrTool = {
  name: "delete_sala_atr_despesa",
  category: "write",
  description: "Remove uma despesa da Sala ATR.",
  input_schema: {
    type: "object",
    properties: {
      despesa_id: { type: "string", description: "ID da despesa a deletar." },
    },
    required: ["despesa_id"],
  },

  preview: async (input, _ctx) => `Deletar despesa Sala ATR: ${input.despesa_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.despesa_id).trim();

    const { data } = await (supabase as any).from("sala_atr_despesas")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Despesa não encontrada." };

    const display = (await deleteSalaAtrDespesa.preview!(input, ctx)) ?? "";
    return { ok: true, data: { despesa_id: id }, display };
  },
};

// ================================================================
// Criar pacote de sessões
// ================================================================
export const createSalaAtrPacote: AtrTool = {
  name: "create_sala_atr_pacote",
  category: "write",
  description:
    "Cria um novo pacote de sessões pré-pagas para um cliente. " +
    "Use para: 'cria pacote de 10 sessões para cliente XYZ por R$1.000'.",
  input_schema: {
    type: "object",
    properties: {
      cliente_nome: { type: "string", description: "Nome do cliente." },
      total_sessoes: { type: "integer", description: "Total de sessões no pacote." },
      valor_pago: { type: "number", description: "Valor total pago pelo pacote em R$." },
    },
    required: ["cliente_nome", "total_sessoes", "valor_pago"],
  },

  preview: async (input, _ctx) => {
    const valorPorSessao = Number(input.valor_pago) / input.total_sessoes;
    return `Criar pacote: ${input.cliente_nome} — ${input.total_sessoes} sessões por R$ ${Number(input.valor_pago).toFixed(2)} (R$ ${valorPorSessao.toFixed(2)}/sessão)`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const totalSessoes = Number(input.total_sessoes);
    const valorPago = Number(input.valor_pago);

    if (totalSessoes <= 0) return { ok: false, error: "total_sessoes deve ser > 0." };
    if (valorPago <= 0) return { ok: false, error: "valor_pago deve ser > 0." };

    const validatedData: Record<string, unknown> = {
      cliente_nome: String(input.cliente_nome).trim(),
      total_sessoes: totalSessoes,
      sessoes_usadas: 0,
      valor_pago: valorPago,
      valor_por_sessao: valorPago / totalSessoes,
    };

    const display = (await createSalaAtrPacote.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar pacote (usar sessões)
// ================================================================
export const updateSalaAtrPacote: AtrTool = {
  name: "update_sala_atr_pacote",
  category: "write",
  description:
    "Atualiza um pacote (principalmente para registrar sessões usadas). " +
    "Use para: 'marca 2 sessões como usadas do pacote de XYZ'.",
  input_schema: {
    type: "object",
    properties: {
      pacote_id: { type: "string", description: "ID do pacote." },
      sessoes_usadas: { type: "integer", description: "Novo valor de sessões usadas (opcional, substitui o anterior)." },
      incrementar_sessoes: { type: "integer", description: "Incrementar sessões usadas em N (alternativa a sessoes_usadas)." },
    },
    required: ["pacote_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("sala_atr_pacotes")
      .select("id, cliente_nome").eq("tenant_id", tenantId).eq("id", String(input.pacote_id)).single();
    if (!data) return `Atualizar pacote: ID ${input.pacote_id} não encontrado.`;
    return `Atualizar pacote de ${data.cliente_nome}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.pacote_id).trim();

    const { data } = await (supabase as any).from("sala_atr_pacotes")
      .select("*").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Pacote não encontrado." };

    const updates: Record<string, unknown> = {};

    if (input.sessoes_usadas !== undefined) {
      const novasUsadas = Number(input.sessoes_usadas);
      if (novasUsadas < 0 || novasUsadas > data.total_sessoes) {
        return { ok: false, error: `sessoes_usadas deve estar entre 0 e ${data.total_sessoes}.` };
      }
      updates.sessoes_usadas = novasUsadas;
    } else if (input.incrementar_sessoes !== undefined) {
      const incremento = Number(input.incrementar_sessoes);
      const novasUsadas = (data.sessoes_usadas || 0) + incremento;
      if (novasUsadas < 0 || novasUsadas > data.total_sessoes) {
        return { ok: false, error: `Resultaria em ${novasUsadas} sessões usadas (limite: ${data.total_sessoes}).` };
      }
      updates.sessoes_usadas = novasUsadas;
    }

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateSalaAtrPacote.preview!(input, ctx)) ?? "";
    return { ok: true, data: { pacote_id: id, updates }, display };
  },
};

// ================================================================
// Deletar pacote de sessões
// ================================================================
export const deleteSalaAtrPacote: AtrTool = {
  name: "delete_sala_atr_pacote",
  category: "write",
  description:
    "Remove um pacote de sessões da Sala ATR. " +
    "Use para: 'cancela pacote de 10 sessões do cliente X', 'remove pacote criado errado'.",
  input_schema: {
    type: "object",
    properties: {
      pacote_id: { type: "string", description: "ID (UUID) do pacote a remover." },
    },
    required: ["pacote_id"],
  },

  preview: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const { data } = await (supabase as any).from("sala_atr_pacotes")
      .select("id, cliente_nome, total_sessoes")
      .eq("tenant_id", tenantId)
      .eq("id", String(input.pacote_id))
      .single();
    if (!data) return `Deletar pacote: ID ${input.pacote_id} não encontrado.`;
    return `Deletar pacote de ${data.total_sessoes} sessões do cliente "${data.cliente_nome}"`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.pacote_id).trim();

    const { data } = await (supabase as any).from("sala_atr_pacotes")
      .select("id, cliente_nome")
      .eq("tenant_id", tenantId)
      .eq("id", id)
      .single();
    if (!data) return { ok: false, error: "Pacote não encontrado." };

    const display = (await deleteSalaAtrPacote.preview!(input, ctx)) ?? "";
    return { ok: true, data: { pacote_id: id }, display };
  },
};

// ================================================================
// Gerar relatório de ocupação
// ================================================================
export const relatorioOcupacaoSala: AtrTool = {
  name: "relatorio_ocupacao_sala",
  category: "read",
  description:
    "Gera relatório de ocupação da Sala ATR num período (ocupação %, receita, eventos).",
  input_schema: {
    type: "object",
    properties: {
      data_inicio: { type: "string", description: "Data inicial YYYY-MM-DD." },
      data_fim: { type: "string", description: "Data final YYYY-MM-DD." },
    },
    required: ["data_inicio", "data_fim"],
  },

  preview: async (input, _ctx) => `Relatório ocupação Sala ATR: ${input.data_inicio} a ${input.data_fim}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    const { data: agendamentos, error: agErr } = await (supabase as any).from("sala_atr_agendamentos")
      .select("*")
      .eq("tenant_id", tenantId)
      .gte("data", String(input.data_inicio))
      .lte("data", String(input.data_fim))
      .neq("status", "Cancelado");

    if (agErr) return { ok: false, error: `Erro ao gerar relatório: ${agErr.message}` };

    const { data: despesas } = await (supabase as any).from("sala_atr_despesas")
      .select("valor")
      .eq("tenant_id", tenantId)
      .gte("data", String(input.data_inicio))
      .lte("data", String(input.data_fim));

    const totalEventes = (agendamentos as Array<any>).length;
    const eventosConfirmados = (agendamentos as Array<any>).filter((a) => a.status === "Confirmado").length;
    const receita = (agendamentos as Array<any>).reduce((sum, a) => sum + (a.valor || 0), 0);
    const custos = (despesas as Array<any>).reduce((sum, d) => sum + (d.valor || 0), 0);
    const resultado = receita - custos;

    return {
      ok: true,
      data: {
        periodo: `${input.data_inicio} a ${input.data_fim}`,
        total_eventos: totalEventes,
        eventos_confirmados: eventosConfirmados,
        ocupacao_percentual: totalEventes > 0 ? ((eventosConfirmados / totalEventes) * 100).toFixed(1) : "0",
        receita_total: receita,
        custos_totais: custos,
        resultado_liquido: resultado,
        margem_percentual: receita > 0 ? ((resultado / receita) * 100).toFixed(1) : "0",
      },
    };
  },
};

// ================================================================
// Listar pacientes da Sala ATR
// ================================================================
export const listSalaAtrClientes: AtrTool = {
  name: "list_sala_atr_clientes",
  category: "read",
  description:
    "Lista pacientes da Sala ATR. Use para buscar pacientes por nome ou telefone.",
  input_schema: {
    type: "object",
    properties: {
      busca: { type: "string", description: "Texto para buscar no nome ou telefone." },
    },
    required: [],
  },

  preview: async (input, _ctx) => {
    const busca = input.busca ? ` "${input.busca}"` : "";
    return `Listar pacientes Sala ATR${busca}`;
  },

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;

    let query = (supabase as any).from("sala_atr_clientes")
      .select("*")
      .eq("tenant_id", tenantId)
      .order("nome");

    if (input.busca) {
      const termo = String(input.busca);
      query = query.or(`nome.ilike.%${termo}%,telefone.ilike.%${termo}%`);
    }

    const { data, error } = await query.limit(20);
    if (error) return { ok: false, error: `Erro ao listar pacientes: ${error.message}` };

    return {
      ok: true,
      data,
      display: data?.length
        ? `Encontrei ${(data as Array<unknown>).length} paciente(s).`
        : "Nenhum paciente encontrado.",
    };
  },
};

// ================================================================
// Obter detalhes do paciente com histórico de sessões
// ================================================================
export const getSalaAtrCliente: AtrTool = {
  name: "get_sala_atr_cliente",
  category: "read",
  description: "Obtém detalhes de um paciente e seu histórico de sessões.",
  input_schema: {
    type: "object",
    properties: {
      cliente_id: { type: "string", description: "UUID do paciente." },
    },
    required: ["cliente_id"],
  },

  preview: async (input, _ctx) => `Obter paciente Sala ATR: ${input.cliente_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const clienteId = String(input.cliente_id);

    const { data: cliente } = await (supabase as any).from("sala_atr_clientes")
      .select("*")
      .eq("id", clienteId)
      .eq("tenant_id", tenantId)
      .single();

    const { data: agendamentos } = await (supabase as any).from("sala_atr_agendamentos")
      .select("*")
      .eq("cliente_id", clienteId)
      .eq("tenant_id", tenantId)
      .order("data", { ascending: false })
      .limit(50);

    const { data: pacotes } = await (supabase as any).from("sala_atr_pacotes")
      .select("*")
      .eq("cliente_id", clienteId)
      .eq("tenant_id", tenantId);

    return {
      ok: true,
      data: { cliente, agendamentos, pacotes },
      display: `Paciente: ${cliente?.nome}. ${(agendamentos as Array<unknown>)?.length || 0} sessões, ${(pacotes as Array<unknown>)?.length || 0} pacotes.`,
    };
  },
};

// ================================================================
// Criar ficha de paciente (pending confirmation)
// ================================================================
export const createSalaAtrCliente: AtrTool = {
  name: "create_sala_atr_cliente",
  category: "write",
  description: "Cria uma ficha de paciente na Sala ATR.",
  input_schema: {
    type: "object",
    properties: {
      nome: { type: "string", description: "Nome completo." },
      telefone: { type: "string", description: "Telefone com DDD." },
      email: { type: "string", description: "Email (opcional)." },
      data_nascimento: { type: "string", description: "Data de nascimento AAAA-MM-DD (opcional)." },
      convenio: { type: "string", description: "Convênio (opcional)." },
      anotacoes: { type: "string", description: "Anotações gerais (opcional)." },
    },
    required: ["nome", "telefone"],
  },

  preview: async (input, _ctx) => `Criar ficha de paciente: ${input.nome}`,

  handler: async (input, ctx) => {
    const validatedData: Record<string, unknown> = {
      nome: String(input.nome).trim(),
      telefone: String(input.telefone).trim(),
      email: input.email ? String(input.email).trim() : null,
      data_nascimento: input.data_nascimento ? String(input.data_nascimento) : null,
      convenio: input.convenio ? String(input.convenio).trim() : null,
      anotacoes: input.anotacoes ? String(input.anotacoes).trim() : null,
    };

    const display = (await createSalaAtrCliente.preview!(input, ctx)) ?? "";
    return { ok: true, data: validatedData, display };
  },
};

// ================================================================
// Atualizar dados do paciente (pending confirmation)
// ================================================================
export const updateSalaAtrCliente: AtrTool = {
  name: "update_sala_atr_cliente",
  category: "write",
  description: "Atualiza dados de um paciente da Sala ATR.",
  input_schema: {
    type: "object",
    properties: {
      cliente_id: { type: "string", description: "UUID do paciente." },
      nome: { type: "string", description: "Novo nome (opcional)." },
      telefone: { type: "string", description: "Novo telefone (opcional)." },
      email: { type: "string", description: "Novo email (opcional)." },
      convenio: { type: "string", description: "Novo convênio (opcional)." },
      anotacoes: { type: "string", description: "Novas anotações (opcional)." },
    },
    required: ["cliente_id"],
  },

  preview: async (input, _ctx) => `Atualizar paciente Sala ATR: ${input.cliente_id}`,

  handler: async (input, ctx) => {
    const supabase = ctx.supabase as Record<string, unknown>;
    const tenantId = ctx.tenant_id as string;
    const id = String(input.cliente_id).trim();

    const { data } = await (supabase as any).from("sala_atr_clientes")
      .select("id").eq("tenant_id", tenantId).eq("id", id).single();
    if (!data) return { ok: false, error: "Paciente não encontrado." };

    const updates: Record<string, unknown> = {};
    if (input.nome !== undefined) updates.nome = String(input.nome).trim();
    if (input.telefone !== undefined) updates.telefone = String(input.telefone).trim();
    if (input.email !== undefined) updates.email = String(input.email).trim();
    if (input.convenio !== undefined) updates.convenio = String(input.convenio).trim();
    if (input.anotacoes !== undefined) updates.anotacoes = String(input.anotacoes).trim();

    if (Object.keys(updates).length === 0) return { ok: false, error: "Nenhum campo para atualizar." };
    const display = (await updateSalaAtrCliente.preview!(input, ctx)) ?? "";
    return { ok: true, data: { cliente_id: id, updates }, display };
  },
};
