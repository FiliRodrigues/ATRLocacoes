import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { TOOLS_REGISTRY } from "./tools/index.ts";
import type { ToolContext } from "./types.ts";

// ================================================================
// Sistema de confirmacao de acoes write (two-step)
// ================================================================

const TTL_MS = 60 * 60 * 1000; // 60 minutos (para lotes grandes e revisão)

/**
 * Cria registro pending_confirmation na tabela ai_action_audit.
 * A acao fica pendente ate o usuario confirmar ou rejeitar.
 * Usa serviceClient (service_role) pois a tabela de auditoria
 * nao deve ser acessivel ao usuario comum.
 */
export async function createPendingAudit(params: {
  tenant_id: string;
  user_id: string;
  conversation_id: string;
  tool_name: string;
  input: Record<string, unknown>;
  content_hashes?: string[];
  serviceClient: SupabaseClient;
}): Promise<string> {
  const { data, error } = await params.serviceClient
    .from("ai_action_audit")
    .insert({
      tenant_id: params.tenant_id,
      user_id: params.user_id,
      conversation_id: params.conversation_id,
      tool_name: params.tool_name,
      input: params.input,
      content_hashes: params.content_hashes || [],
      status: "pending_confirmation",
    })
    .select("id")
    .single();

  if (error) throw new Error(`Falha ao criar audit: ${error.message}`);
  return data.id;
}

/**
 * Executa uma acao confirmada pelo usuario.
 * Fluxo:
 * 1. Carrega o registro de auditoria
 * 2. Valida: existe, pertence ao usuario, status = pending_confirmation
 * 3. Verifica TTL (60 minutos)
 * 4. Chama o tool handler para validar/re-processar os dados
 * 5. Executa a operacao de escrita no banco (INSERT/UPDATE)
 * 6. Atualiza o registro de auditoria com o resultado
 *
 * Usa serviceClient (service_role) para auditoria e escrita final.
 */
export async function executeConfirmedAction(
  actionId: string,
  params: {
    tenant_id: string;
    user_id: string;
    userClient: SupabaseClient;
    serviceClient: SupabaseClient;
  }
): Promise<{ ok: boolean; data?: unknown; error?: string; display?: string }> {
  const supabase = params.serviceClient;

  // 1. Carrega audit
  const { data: audit, error: loadErr } = await supabase
    .from("ai_action_audit")
    .select("*")
    .eq("id", actionId)
    .eq("tenant_id", params.tenant_id)
    .single();

  if (loadErr || !audit) {
    return { ok: false, error: "Acao nao encontrada." };
  }
  if (audit.user_id !== params.user_id) {
    return { ok: false, error: "Acao nao pertence a este usuario." };
  }
  if (audit.status !== "pending_confirmation") {
    return { ok: false, error: "Acao ja foi processada." };
  }

  // 2. Verifica TTL (60 minutos)
  const age = Date.now() - new Date(audit.created_at).getTime();
  if (age > TTL_MS) {
    await supabase
      .from("ai_action_audit")
      .update({ status: "cancelled", error: "Expirada (>60 min)" })
      .eq("id", actionId)
      .eq("tenant_id", params.tenant_id);
    return { ok: false, error: "Acao expirou (>60 min). Refaca o pedido." };
  }

  // 3. Busca a tool
  const tool = TOOLS_REGISTRY[audit.tool_name];
  if (!tool) {
    return { ok: false, error: `Tool "${audit.tool_name}" nao encontrada.` };
  }

  // 4. Constroi contexto para a tool (usa userClient para leitura e serviceClient para gravar bypass RLS)
  const ctx: ToolContext = {
    tenant_id: params.tenant_id,
    user_id: params.user_id,
    conversation_id: audit.conversation_id || "",
    channel: "web",
    userClient: params.userClient,
    serviceClient: params.serviceClient,
    // @ts-ignore compatibilidade com tools que usam ctx.supabase - force user context for db reads inside tool validation
    supabase: params.userClient,
  };

  try {
    // 5. Chama o handler (valida e retorna dados estruturados)
    const handlerResult = await tool.handler(audit.input, ctx);

    if (!handlerResult.ok) {
      // Handler retornou erro de validacao
      await supabase
        .from("ai_action_audit")
        .update({
          status: "failed",
          error: handlerResult.error || "Erro de validacao",
          executed_at: new Date().toISOString(),
        })
        .eq("id", actionId)
        .eq("tenant_id", params.tenant_id);

      return handlerResult;
    }

    // 6. Executa a operacao de escrita no banco
    const writeResult = await executeWriteOperation(
      audit.tool_name,
      handlerResult.data,
      supabase,
      params.tenant_id,
      params.user_id
    );

    // 7. Atualiza audit com o resultado final
    await supabase
      .from("ai_action_audit")
      .update({
        status: writeResult.ok ? "executed" : "failed",
        output: writeResult.data || null,
        error: writeResult.error || null,
        executed_at: new Date().toISOString(),
      })
      .eq("id", actionId)
      .eq("tenant_id", params.tenant_id);

    // Display combina resultado da validacao + operacao
    const display = writeResult.ok
      ? handlerResult.display || "Acao executada com sucesso."
      : writeResult.error || "Erro ao executar acao.";

    return { ...writeResult, display };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    await supabase
      .from("ai_action_audit")
      .update({
        status: "failed",
        error: msg,
        executed_at: new Date().toISOString(),
      })
      .eq("id", actionId)
      .eq("tenant_id", params.tenant_id);
    return { ok: false, error: msg };
  }
}

/**
 * Cancela uma acao pendente.
 */
export async function cancelAction(
  actionId: string,
  userId: string,
  tenantId: string,
  serviceClient: SupabaseClient
): Promise<boolean> {
  const { data: audit } = await serviceClient
    .from("ai_action_audit")
    .select("user_id, status, tenant_id")
    .eq("id", actionId)
    .eq("tenant_id", tenantId)
    .single();

  if (!audit || audit.user_id !== userId || audit.status !== "pending_confirmation") {
    return false;
  }

  await serviceClient
    .from("ai_action_audit")
    .update({ status: "cancelled" })
    .eq("id", actionId)
    .eq("tenant_id", tenantId);

  return true;
}

// ================================================================
// Helpers internos: executa a operacao de escrita no banco
// ================================================================

async function executeWriteOperation(
  toolName: string,
  validatedData: unknown,
  supabase: SupabaseClient,
  tenantId: string,
  userId: string
): Promise<{ ok: boolean; data?: unknown; error?: string; display?: string }> {
  switch (toolName) {
    // ----------------------------------------------------------
    // create_maintenance: INSERT em manutencoes
    // ----------------------------------------------------------
    case "create_maintenance": {
      const d = validatedData as Record<string, unknown>;

      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_id: d.vehicle_id,
        veiculo_placa: d.plate || "",
        veiculo_nome: d.model || "",
        titulo: d.titulo || d.type || "",
        coluna: d.coluna || "concluidos",
        prioridade: d.prioridade || "media",
        odometro: d.odometro || 0,
        is_preventiva: d.is_preventiva !== undefined ? Boolean(d.is_preventiva) : true,
        numero_os: d.invoice_number || "",
        nome_anexo: "",
        data: d.date,
        tipo: d.type || "",
        descricao: d.description || "",
        fornecedor: d.workshop_name || "",
        custo: d.cost != null && Number(d.cost) > 0 ? Number(d.cost) : 0,
        km_no_servico: d.mileage != null ? Number(d.mileage) : null,
        status_pagamento: d.status_pagamento || "Pago",
        data_conclusao: d.date ? new Date(String(d.date)).toISOString() : new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("manutencoes")
        .insert(insert)
        .select("id, veiculo_id, data, tipo, descricao, custo")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar manutencao: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // create_expense: INSERT em despesas
    // ----------------------------------------------------------
    case "create_expense": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_placa: d.vehicle_plate || "",
        data: d.date,
        tipo: d.tipo || "",
        descricao: d.descricao || "",
        valor: d.valor != null ? Number(d.valor) : null,
        pago: d.pago !== undefined ? Boolean(d.pago) : false,
      };
      if (d.motorista !== undefined) (insert as Record<string, unknown>).motorista = d.motorista;
      if (d.odometro !== undefined) (insert as Record<string, unknown>).odometro = d.odometro;
      if (d.litros !== undefined) (insert as Record<string, unknown>).litros = d.litros;
      if (d.nf !== undefined) (insert as Record<string, unknown>).nf = d.nf;
      if (d.nome_anexo !== undefined) (insert as Record<string, unknown>).nome_anexo = d.nome_anexo;

      const { data, error } = await supabase
        .from("despesas")
        .insert(insert)
        .select("id, data, tipo, descricao, valor, veiculo_placa, pago")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar despesa: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_vehicle_mileage: UPDATE veiculos + INSERT hodometros
    // ----------------------------------------------------------
    case "update_vehicle_mileage": {
      const d = validatedData as Record<string, unknown>;

      // Atualiza km_atual e insere hodometro em transacao atomica
      const hodEntry = (d.hodometro_entry as Record<string, unknown>) || {};
      const { error: rpcErr } = await supabase.rpc("update_vehicle_mileage", {
        p_vehicle_id: d.vehicle_id,
        p_km: d.new_mileage || hodEntry.km,
        p_placa: d.plate || hodEntry.veiculo_placa,
        p_registrado_por: userId,
        p_tenant_id: tenantId
      });

      if (rpcErr) return { ok: false, error: `Erro ao atualizar km: ${rpcErr.message}` };

      return {
        ok: true,
        data: {
          vehicle_plate: d.plate,
          old_mileage: d.old_mileage,
          new_mileage: d.new_mileage,
          hodometro: { km: d.new_mileage || hodEntry.km },
        },
      };
    }

    // ----------------------------------------------------------
    // create_maintenances_batch: INSERT multiplos em manutencoes
    // ----------------------------------------------------------
    case "create_maintenances_batch": {
      const d = validatedData as Record<string, unknown>;
      const items = (d.items as Array<Record<string, unknown>>) || [];

      if (items.length === 0) {
        return { ok: false, error: "Nenhum item no lote." };
      }

      const results: Array<{ ok: boolean; plate?: string; error?: string; id?: string }> = [];
      let sucessos = 0;
      let falhas = 0;

      for (const item of items) {
      const insert: Record<string, unknown> = {
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          veiculo_id: item.vehicle_id,
          veiculo_placa: item.plate || "",
          veiculo_nome: item.model || "",
          titulo: item.titulo || item.type || "",
          coluna: item.coluna || "concluidos",
          prioridade: item.prioridade || "media",
          odometro: item.odometro || 0,
          is_preventiva: item.is_preventiva !== undefined ? Boolean(item.is_preventiva) : true,
          numero_os: item.invoice_number || "",
          nome_anexo: "",
          data: item.date,
          tipo: item.type || "",
          descricao: item.description || "",
          fornecedor: item.workshop_name || "",
          custo: item.cost != null && Number(item.cost) > 0 ? Number(item.cost) : 0,
          km_no_servico: item.mileage != null ? Number(item.mileage) : null,
          status_pagamento: item.status_pagamento || "Pago",
          data_conclusao: item.date ? new Date(String(item.date)).toISOString() : new Date().toISOString(),
        };

        const { data: inserted, error: insErr } = await supabase
          .from("manutencoes")
          .insert(insert)
          .select("id")
          .single();

        if (insErr) {
          results.push({ ok: false, plate: item.plate as string, error: insErr.message });
          falhas++;
        } else {
          results.push({ ok: true, plate: item.plate as string, id: inserted?.id });
          sucessos++;
        }
      }

      const allFailed = sucessos === 0;
      
      const failedDetails = falhas > 0 
        ? results.filter((r) => !r.ok).map((r) => `• ${r.plate || "Desconhecido"}: ${r.error}`).join("\n")
        : "";

      return {
        ok: !allFailed,
        error: allFailed ? `Todas as ${falhas} inserções falharam.\n${failedDetails}` : undefined,
        display: `Inseridos: ${sucessos}\nFalharam: ${falhas}${failedDetails ? '\nDetalhes das falhas:\n' + failedDetails : ''}`,
        data: {
          total: items.length,
          sucessos,
          falhas,
          results,
          warning: falhas > 0 && !allFailed
            ? `${falhas} de ${items.length} inserções falharam.`
            : undefined,
        },
      };
    }

    // ----------------------------------------------------------
    // create_vehicle: INSERT em veiculos
    // ----------------------------------------------------------
    case "create_vehicle": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        placa: d.placa,
        tipo: d.tipo || null,
        marca: d.marca || null,
        modelo: d.modelo || null,
        ano_fabricacao_modelo: d.ano_fabricacao_modelo || null,
        renavam: d.renavam || null,
        chassi: d.chassi || null,
        km_inicial: d.km_inicial != null ? Number(d.km_inicial) : null,
        km_atual: d.km_atual != null ? Number(d.km_atual) : null,
        situacao_operacional: d.situacao_operacional || "Disponível",
        propriedade_status: d.propriedade_status || null,
        valor_veiculo: d.valor_veiculo != null ? Number(d.valor_veiculo) : null,
        numero_nota_fiscal: d.numero_nota_fiscal || null,
        data_nota_fiscal: d.data_compra || null,
        observacoes: d.observacoes || null,
      };

      const { data, error } = await supabase
        .from("veiculos")
        .insert(insert)
        .select("id, placa, marca, modelo")
        .single();

      if (error) return { ok: false, error: `Erro ao cadastrar veiculo: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_vehicle: UPDATE em veiculos
    // ----------------------------------------------------------
    case "update_vehicle": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("veiculos")
        .update(d.updates)
        .eq("id", d.vehicle_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar veiculo: ${error.message}` };
      return { ok: true, data: { vehicle_id: d.vehicle_id, plate: d.plate, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_vehicle: DELETE em veiculos
    // ----------------------------------------------------------
    case "delete_vehicle": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("veiculos")
        .delete()
        .eq("id", d.vehicle_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao excluir veiculo: ${error.message}` };
      return { ok: true, data: { deleted_vehicle_id: d.vehicle_id, plate: d.plate } };
    }

    // ----------------------------------------------------------
    // update_maintenance: UPDATE em manutencoes
    // ----------------------------------------------------------
    case "update_maintenance": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("manutencoes")
        .update(d.updates)
        .eq("id", d.maintenance_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar manutencao: ${error.message}` };
      return { ok: true, data: { maintenance_id: d.maintenance_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_maintenance: DELETE em manutencoes
    // ----------------------------------------------------------
    case "delete_maintenance": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("manutencoes")
        .delete()
        .eq("id", d.maintenance_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao excluir manutencao: ${error.message}` };
      return { ok: true, data: { deleted_maintenance_id: d.maintenance_id } };
    }

    // ----------------------------------------------------------
    // update_expense: UPDATE em despesas
    // ----------------------------------------------------------
    case "update_expense": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("despesas")
        .update(d.updates)
        .eq("id", d.expense_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar despesa: ${error.message}` };
      return { ok: true, data: { expense_id: d.expense_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_expense: DELETE em despesas
    // ----------------------------------------------------------
    case "delete_expense": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("despesas")
        .delete()
        .eq("id", d.expense_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao excluir despesa: ${error.message}` };
      return { ok: true, data: { deleted_expense_id: d.expense_id } };
    }

    // ----------------------------------------------------------
    // create_abastecimento: INSERT em abastecimentos
    // ----------------------------------------------------------
    case "create_abastecimento": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_placa: d.plate,
        data: d.date,
        litros: d.litros,
        valor_total: d.valor_total,
        km_odometro: d.km_odometro,
        tipo: d.tipo || "gasolina",
        posto: d.posto || null,
        registrado_por: "ia_assistant",
      };

      const { data, error } = await supabase
        .from("abastecimentos")
        .insert(insert)
        .select("id, veiculo_placa, data, litros, valor_total, tipo")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar abastecimento: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_abastecimento: UPDATE em abastecimentos
    // ----------------------------------------------------------
    case "update_abastecimento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("abastecimentos")
        .update(d.updates)
        .eq("id", d.abastecimento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar abastecimento: ${error.message}` };
      return { ok: true, data: { abastecimento_id: d.abastecimento_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_abastecimento: DELETE em abastecimentos
    // ----------------------------------------------------------
    case "delete_abastecimento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("abastecimentos")
        .delete()
        .eq("id", d.abastecimento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao excluir abastecimento: ${error.message}` };
      return { ok: true, data: { deleted_abastecimento_id: d.abastecimento_id } };
    }

    // ----------------------------------------------------------
    // create_contract: INSERT em contratos
    // ----------------------------------------------------------
    case "create_contract": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        numero: d.numero,
        cliente_nome: d.cliente_nome,
        cliente_cnpj: d.cliente_cnpj,
        veiculo_placa: d.veiculo_placa,
        data_inicio: d.data_inicio,
        data_fim: d.data_fim,
        sla_km_mes: d.sla_km_mes || 0,
        valor_mensal: d.valor_mensal,
        status: "ativo",
        observacoes: d.observacoes || "",
        cliente_contato: d.cliente_contato || "",
        criado_por: "ia_assistant",
      };

      const { data, error } = await supabase
        .from("contratos")
        .insert(insert)
        .select("id, numero, cliente_nome, veiculo_placa, valor_mensal, status")
        .single();

      if (error) return { ok: false, error: `Erro ao criar contrato: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_contract: UPDATE em contratos
    // ----------------------------------------------------------
    case "update_contract": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("contratos")
        .update(d.updates)
        .eq("id", d.contract_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar contrato: ${error.message}` };
      return { ok: true, data: { contract_id: d.contract_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_contract: DELETE em contratos
    // ----------------------------------------------------------
    case "delete_contract": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("contratos")
        .delete()
        .eq("id", d.contract_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao excluir contrato: ${error.message}` };
      return { ok: true, data: { deleted_contract_id: d.contract_id } };
    }

    // ----------------------------------------------------------
    // update_payment_status: UPDATE em tabelas financeiras
    // ----------------------------------------------------------
    case "update_payment_status": {
      const d = validatedData as Record<string, unknown>;
      const table = String(d.table);
      const { error } = await supabase
        .from(table)
        .update(d.updates)
        .eq("id", d.entity_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar ${table}: ${error.message}` };
      return { ok: true, data: { entity: d.entity, entity_id: d.entity_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_regra_manutencao: INSERT em regras_manutencao
    // ----------------------------------------------------------
    case "create_regra_manutencao": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        titulo: d.titulo,
        tipo: d.tipo,
        veiculo_placa: d.veiculo_placa || null,
        intervalo_km: d.intervalo_km || null,
        intervalo_dias: d.intervalo_dias || null,
        custo_estimado: d.custo_estimado || 0,
        prioridade: d.prioridade || "media",
        is_ativa: true,
      };

      const { data, error } = await supabase
        .from("regras_manutencao")
        .insert(insert)
        .select("id, titulo, tipo")
        .single();

      if (error) return { ok: false, error: `Erro ao criar regra: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_regra_manutencao: UPDATE em regras_manutencao
    // ----------------------------------------------------------
    case "update_regra_manutencao": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("regras_manutencao")
        .update(d.updates)
        .eq("id", d.regra_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar regra: ${error.message}` };
      return { ok: true, data: { regra_id: d.regra_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_ocorrencia: INSERT em ocorrencias
    // ----------------------------------------------------------
    case "create_ocorrencia": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        contrato_id: d.contrato_id,
        tipo: d.tipo,
        descricao: d.descricao,
        status: "aberta",
        data_ocorrencia: d.data_ocorrencia || new Date().toISOString().split("T")[0],
        valor_estimado: d.valor_estimado || 0,
        impacto_financeiro: d.valor_estimado || 0,
        responsavel_pagamento: d.responsavel_pagamento || "cliente",
        observacoes: d.observacoes || "",
        registrado_por: "ia_assistant",
      };

      const { data, error } = await supabase
        .from("ocorrencias")
        .insert(insert)
        .select("id, contrato_id, tipo, descricao, status")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar ocorrencia: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_ocorrencia: UPDATE em ocorrencias
    // ----------------------------------------------------------
    case "update_ocorrencia": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("ocorrencias")
        .update(d.updates)
        .eq("id", d.ocorrencia_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar ocorrencia: ${error.message}` };
      return { ok: true, data: { ocorrencia_id: d.ocorrencia_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_recebimento: INSERT em recebimentos
    // ----------------------------------------------------------
    case "create_recebimento": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_id: d.veiculo_id,
        locatario: d.locatario || null,
        numero_parcela: d.numero_parcela || null,
        valor_previsto: d.valor_previsto,
        valor_recebido: d.valor_recebido || d.valor_previsto,
        data_vencimento: d.data_vencimento || null,
        data_recebimento: d.data_recebimento || null,
        status_pagamento: d.status_pagamento || "Pendente",
        observacoes: d.observacoes || null,
      };

      const { data, error } = await supabase
        .from("recebimentos")
        .insert(insert)
        .select("id, veiculo_id, valor_previsto, valor_recebido, status_pagamento")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar recebimento: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // execute_sql: DDL Seguro
    // ----------------------------------------------------------
    case "execute_sql": {
      const d = validatedData as Record<string, unknown>;
      const { data, error } = await supabase.rpc("execute_tenant_sql", {
        p_sql: String(d.sql),
        p_tenant_id: tenantId,
      });
      if (error) return { ok: false, error: `Erro SQL: ${error.message}` };
      return { ok: true, data, display: `✅ SQL executado com sucesso.` };
    }

    // ----------------------------------------------------------
    // create_sala_atr_agendamento: INSERT em sala_atr_agendamentos
    // ----------------------------------------------------------
    case "create_sala_atr_agendamento": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        data: d.data,
        hora_inicio: d.hora_inicio,
        hora_fim: d.hora_fim,
        cliente_nome: d.cliente_nome,
        quantidade_pessoas: d.quantidade_pessoas,
        tipo_evento: d.tipo_evento,
        pacote: d.pacote || null,
        valor: d.valor || null,
        status: d.status || "Confirmado",
        observacoes: d.observacoes || null,
      };

      const { data, error } = await supabase
        .from("sala_atr_agendamentos")
        .insert(insert)
        .select("id, data, hora_inicio, hora_fim, cliente_nome, status")
        .single();

      if (error) return { ok: false, error: `Erro ao criar agendamento: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_sala_atr_agendamento: UPDATE em sala_atr_agendamentos
    // ----------------------------------------------------------
    case "update_sala_atr_agendamento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_agendamentos")
        .update(d.updates)
        .eq("id", d.agendamento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar agendamento: ${error.message}` };
      return { ok: true, data: { agendamento_id: d.agendamento_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_sala_atr_agendamento: DELETE em sala_atr_agendamentos
    // ----------------------------------------------------------
    case "delete_sala_atr_agendamento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_agendamentos")
        .delete()
        .eq("id", d.agendamento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao deletar agendamento: ${error.message}` };
      return { ok: true, data: { deleted_agendamento_id: d.agendamento_id } };
    }

    // ----------------------------------------------------------
    // create_sala_atr_despesa: INSERT em sala_atr_despesas
    // ----------------------------------------------------------
    case "create_sala_atr_despesa": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        descricao: d.descricao,
        valor: d.valor,
        data: d.data,
        categoria: d.categoria || "Geral",
        pago: d.pago || false,
      };

      const { data, error } = await supabase
        .from("sala_atr_despesas")
        .insert(insert)
        .select("id, descricao, valor, data, categoria")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar despesa: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_sala_atr_despesa: UPDATE em sala_atr_despesas
    // ----------------------------------------------------------
    case "update_sala_atr_despesa": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_despesas")
        .update(d.updates)
        .eq("id", d.despesa_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar despesa: ${error.message}` };
      return { ok: true, data: { despesa_id: d.despesa_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_sala_atr_despesa: DELETE em sala_atr_despesas
    // ----------------------------------------------------------
    case "delete_sala_atr_despesa": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_despesas")
        .delete()
        .eq("id", d.despesa_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao deletar despesa: ${error.message}` };
      return { ok: true, data: { deleted_despesa_id: d.despesa_id } };
    }

    // ----------------------------------------------------------
    // create_sala_atr_pacote: INSERT em sala_atr_pacotes
    // ----------------------------------------------------------
    case "create_sala_atr_pacote": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        cliente_nome: d.cliente_nome,
        total_sessoes: d.total_sessoes,
        sessoes_usadas: 0,
        valor_pago: d.valor_pago,
        valor_por_sessao: d.valor_por_sessao,
      };

      const { data, error } = await supabase
        .from("sala_atr_pacotes")
        .insert(insert)
        .select("id, cliente_nome, total_sessoes, valor_pago")
        .single();

      if (error) return { ok: false, error: `Erro ao criar pacote: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_sala_atr_pacote: UPDATE em sala_atr_pacotes
    // ----------------------------------------------------------
    case "update_sala_atr_pacote": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_pacotes")
        .update(d.updates)
        .eq("id", d.pacote_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar pacote: ${error.message}` };
      return { ok: true, data: { pacote_id: d.pacote_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_lazer_evento: INSERT em lazer_eventos
    // ----------------------------------------------------------
    case "create_lazer_evento": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        nome: d.nome,
        tipo: d.tipo,
        data: d.data,
        local: d.local || null,
        quantidade_pessoas: d.quantidade_pessoas,
        receita_total: d.receita_total || 0,
        custo_total: 0,
        status: d.status || "Planejado",
      };

      const { data, error } = await supabase
        .from("lazer_eventos")
        .insert(insert)
        .select("id, nome, tipo, data, status")
        .single();

      if (error) return { ok: false, error: `Erro ao criar evento: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_lazer_evento: UPDATE em lazer_eventos
    // ----------------------------------------------------------
    case "update_lazer_evento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("lazer_eventos")
        .update(d.updates)
        .eq("id", d.evento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar evento: ${error.message}` };
      return { ok: true, data: { evento_id: d.evento_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_lazer_evento: DELETE em lazer_eventos
    // ----------------------------------------------------------
    case "delete_lazer_evento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("lazer_eventos")
        .delete()
        .eq("id", d.evento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao deletar evento: ${error.message}` };
      return { ok: true, data: { deleted_evento_id: d.evento_id } };
    }

    // ----------------------------------------------------------
    // create_lazer_despesa: INSERT em lazer_despesas
    // ----------------------------------------------------------
    case "create_lazer_despesa": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        evento_id: d.evento_id || null,
        descricao: d.descricao,
        valor: d.valor,
        data: d.data,
        categoria: d.categoria || "Geral",
        pago: d.pago || false,
      };

      const { data, error } = await supabase
        .from("lazer_despesas")
        .insert(insert)
        .select("id, descricao, valor, data, categoria")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar despesa: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_lazer_despesa: UPDATE em lazer_despesas
    // ----------------------------------------------------------
    case "update_lazer_despesa": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("lazer_despesas")
        .update(d.updates)
        .eq("id", d.despesa_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar despesa: ${error.message}` };
      return { ok: true, data: { despesa_id: d.despesa_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // delete_lazer_despesa: DELETE em lazer_despesas
    // ----------------------------------------------------------
    case "delete_lazer_despesa": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("lazer_despesas")
        .delete()
        .eq("id", d.despesa_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao deletar despesa: ${error.message}` };
      return { ok: true, data: { deleted_despesa_id: d.despesa_id } };
    }

    // ----------------------------------------------------------
    // delete_financiamento: DELETE em financiamentos
    // ----------------------------------------------------------
    case "delete_financiamento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("financiamentos")
        .delete()
        .eq("id", d.financiamento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao deletar financiamento: ${error.message}` };
      return { ok: true, data: { deleted_financiamento_id: d.financiamento_id } };
    }

    // ----------------------------------------------------------
    // update_parcela_seguro: UPDATE em parcelas_seguro
    // ----------------------------------------------------------
    case "update_parcela_seguro": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("parcelas_seguro")
        .update(d.updates)
        .eq("id", d.parcela_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar parcela: ${error.message}` };
      return { ok: true, data: { parcela_id: d.parcela_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_hodometro: INSERT em hodometros
    // ----------------------------------------------------------
    case "create_hodometro": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_placa: d.veiculo_placa,
        km: d.km,
        registrado_por: d.registrado_por || "sistema",
      };

      const { data, error } = await supabase
        .from("hodometros")
        .insert(insert)
        .select("id, veiculo_placa, km")
        .single();

      if (error) return { ok: false, error: `Erro ao registrar hodômetro: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // create_ipva: INSERT em ipva
    // ----------------------------------------------------------
    case "create_ipva": {
      const d = validatedData as Record<string, unknown>;
      const statusValidos = ["Pendente", "Pago", "Vencido"];
      const status = d.status_pagamento ? String(d.status_pagamento) : "Pendente";
      if (!statusValidos.includes(status)) {
        return { ok: false, error: `Status inválido: "${status}". Use: ${statusValidos.join(", ")}.` };
      }

      // Resolve veiculo_id a partir de vehicle_identifier (placa ou UUID)
      const ident = String(d.vehicle_identifier || d.veiculo_id || "");
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);
      let veiculoId: string;
      let veiculoPlaca: string;
      if (isUuid) {
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).eq("id", ident).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      } else {
        const placa = ident.replace(/[\s\-\.]/g, "").toUpperCase();
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).ilike("placa", placa).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      }

      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_id: veiculoId,
        ano_referencia: Number(d.ano_referencia),
        valor_total: Number(d.valor_total),
        data_vencimento: String(d.data_vencimento),
        status_pagamento: status,
      };
      if (d.data_pagamento) insert.data_pagamento = String(d.data_pagamento);
      if (d.observacoes) insert.observacoes = String(d.observacoes);

      const { data, error } = await supabase.from("ipva").insert(insert).select("id, veiculo_id, ano_referencia, valor_total, status_pagamento").single();
      if (error) return { ok: false, error: `Erro ao registrar IPVA: ${error.message}` };
      return {
        ok: true,
        data,
        display: `✅ IPVA ${d.ano_referencia} registrado para ${veiculoPlaca} — R$ ${Number(d.valor_total).toFixed(2)} (${status})`,
      };
    }

    // ----------------------------------------------------------
    // create_licenciamento: INSERT em licenciamento
    // ----------------------------------------------------------
    case "create_licenciamento": {
      const d = validatedData as Record<string, unknown>;
      const statusValidos = ["Pendente", "Pago", "Vencido"];
      const status = d.status_pagamento ? String(d.status_pagamento) : "Pendente";
      if (!statusValidos.includes(status)) {
        return { ok: false, error: `Status inválido: "${status}". Use: ${statusValidos.join(", ")}.` };
      }

      const ident = String(d.vehicle_identifier || d.veiculo_id || "");
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);
      let veiculoId: string;
      let veiculoPlaca: string;
      if (isUuid) {
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).eq("id", ident).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      } else {
        const placa = ident.replace(/[\s\-\.]/g, "").toUpperCase();
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).ilike("placa", placa).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      }

      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_id: veiculoId,
        ano_referencia: Number(d.ano_referencia),
        valor_total: Number(d.valor_total),
        data_vencimento: String(d.data_vencimento),
        status_pagamento: status,
      };
      if (d.mes_vencimento) insert.mes_vencimento = String(d.mes_vencimento);
      if (d.data_pagamento) insert.data_pagamento = String(d.data_pagamento);
      if (d.observacoes) insert.observacoes = String(d.observacoes);

      const { data, error } = await supabase.from("licenciamento").insert(insert).select("id, veiculo_id, ano_referencia, valor_total, status_pagamento").single();
      if (error) return { ok: false, error: `Erro ao registrar licenciamento: ${error.message}` };
      return {
        ok: true,
        data,
        display: `✅ Licenciamento ${d.ano_referencia} registrado para ${veiculoPlaca} — R$ ${Number(d.valor_total).toFixed(2)} (${status})`,
      };
    }

    // ----------------------------------------------------------
    // create_multa: INSERT em multas
    // ----------------------------------------------------------
    case "create_multa": {
      const d = validatedData as Record<string, unknown>;
      const statusValidos = ["Pendente", "Pago", "Vencido"];
      const status = d.status_pagamento ? String(d.status_pagamento) : "Pendente";
      if (!statusValidos.includes(status)) {
        return { ok: false, error: `Status inválido: "${status}". Use: ${statusValidos.join(", ")}.` };
      }

      const ident = String(d.vehicle_identifier || d.veiculo_id || "");
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(ident);
      let veiculoId: string;
      let veiculoPlaca: string;
      if (isUuid) {
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).eq("id", ident).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      } else {
        const placa = ident.replace(/[\s\-\.]/g, "").toUpperCase();
        const { data: v } = await supabase.from("veiculos").select("id, placa").eq("tenant_id", tenantId).ilike("placa", placa).single();
        if (!v) return { ok: false, error: `Veículo não encontrado: "${ident}".` };
        veiculoId = v.id; veiculoPlaca = v.placa;
      }

      const insert: Record<string, unknown> = {
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        veiculo_id: veiculoId,
        ano_referencia: Number(d.ano_referencia),
        mes: String(d.mes),
        valor: Number(d.valor),
        status_pagamento: status,
      };
      if (d.descricao) insert.descricao = String(d.descricao);
      if (d.data_infracao) insert.data_infracao = String(d.data_infracao);
      if (d.data_vencimento) insert.data_vencimento = String(d.data_vencimento);
      if (d.data_pagamento) insert.data_pagamento = String(d.data_pagamento);

      const { data, error } = await supabase.from("multas").insert(insert).select("id, veiculo_id, ano_referencia, mes, valor, status_pagamento").single();
      if (error) return { ok: false, error: `Erro ao registrar multa: ${error.message}` };
      return {
        ok: true,
        data,
        display: `✅ Multa ${d.mes}/${d.ano_referencia} registrada para ${veiculoPlaca} — R$ ${Number(d.valor).toFixed(2)} (${status})`,
      };
    }

    // ----------------------------------------------------------
    // update_ipva: UPDATE em ipva
    // ----------------------------------------------------------
    case "update_ipva": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("ipva")
        .update(d.updates)
        .eq("id", d.ipva_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar IPVA: ${error.message}` };
      return { ok: true, data: { ipva_id: d.ipva_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // update_licenciamento: UPDATE em licenciamento
    // ----------------------------------------------------------
    case "update_licenciamento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("licenciamento")
        .update(d.updates)
        .eq("id", d.licenciamento_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar licenciamento: ${error.message}` };
      return { ok: true, data: { licenciamento_id: d.licenciamento_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // update_multa: UPDATE em multas
    // ----------------------------------------------------------
    case "update_multa": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("multas")
        .update(d.updates)
        .eq("id", d.multa_id)
        .eq("tenant_id", tenantId);

      if (error) return { ok: false, error: `Erro ao atualizar multa: ${error.message}` };
      return { ok: true, data: { multa_id: d.multa_id, ...(d.updates as Record<string, unknown>) } };
    }

    // ----------------------------------------------------------
    // create_checklist_evento: INSERT em checklist_eventos
    // ----------------------------------------------------------
    case "create_checklist_evento": {
      const d = validatedData as Record<string, unknown>;
      const { data, error } = await supabase
        .from("checklist_eventos")
        .insert({ id: crypto.randomUUID(), tenant_id: tenantId, ...d })
        .select("id, tipo, km_odometro, realizado_por")
        .single();
      if (error) return { ok: false, error: `Erro ao criar checklist: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_checklist_evento: UPDATE em checklist_eventos
    // ----------------------------------------------------------
    case "update_checklist_evento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("checklist_eventos")
        .update(d.updates)
        .eq("id", d.checklist_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao atualizar checklist: ${error.message}` };
      return { ok: true, data: { checklist_id: d.checklist_id } };
    }

    // ----------------------------------------------------------
    // create_seguro: INSERT em seguros
    // ----------------------------------------------------------
    case "create_seguro": {
      const d = validatedData as Record<string, unknown>;
      const { data, error } = await supabase
        .from("seguros")
        .insert({ id: crypto.randomUUID(), tenant_id: tenantId, ...d })
        .select("id, veiculo_id, empresa, ano_referencia")
        .single();
      if (error) return { ok: false, error: `Erro ao criar seguro: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_seguro: UPDATE em seguros
    // ----------------------------------------------------------
    case "update_seguro": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("seguros")
        .update(d.updates)
        .eq("id", d.seguro_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao atualizar seguro: ${error.message}` };
      return { ok: true, data: { seguro_id: d.seguro_id } };
    }

    // ----------------------------------------------------------
    // create_financiamento: INSERT em financiamentos
    // ----------------------------------------------------------
    case "create_financiamento": {
      const d = validatedData as Record<string, unknown>;
      const { data, error } = await supabase
        .from("financiamentos")
        .insert({ id: crypto.randomUUID(), tenant_id: tenantId, ...d })
        .select("id, veiculo_id, banco_financeira")
        .single();
      if (error) return { ok: false, error: `Erro ao criar financiamento: ${error.message}` };
      return { ok: true, data };
    }

    // ----------------------------------------------------------
    // update_financiamento: UPDATE em financiamentos
    // ----------------------------------------------------------
    case "update_financiamento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("financiamentos")
        .update(d.updates)
        .eq("id", d.financiamento_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao atualizar financiamento: ${error.message}` };
      return { ok: true, data: { financiamento_id: d.financiamento_id } };
    }

    // ----------------------------------------------------------
    // delete_ocorrencia: DELETE em ocorrencias
    // ----------------------------------------------------------
    case "delete_ocorrencia": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("ocorrencias")
        .delete()
        .eq("id", d.ocorrencia_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao deletar ocorrência: ${error.message}` };
      return { ok: true, data: { deleted_ocorrencia_id: d.ocorrencia_id } };
    }

    // ----------------------------------------------------------
    // delete_regra_manutencao: DELETE em regras_manutencao
    // ----------------------------------------------------------
    case "delete_regra_manutencao": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("regras_manutencao")
        .delete()
        .eq("id", d.regra_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao deletar regra: ${error.message}` };
      return { ok: true, data: { deleted_regra_id: d.regra_id } };
    }

    // ----------------------------------------------------------
    // delete_sala_atr_pacote: DELETE em sala_atr_pacotes
    // ----------------------------------------------------------
    case "delete_sala_atr_pacote": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("sala_atr_pacotes")
        .delete()
        .eq("id", d.pacote_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao deletar pacote: ${error.message}` };
      return { ok: true, data: { deleted_pacote_id: d.pacote_id } };
    }

    // ----------------------------------------------------------
    // delete_recebimento: DELETE em recebimentos
    // ----------------------------------------------------------
    case "delete_recebimento": {
      const d = validatedData as Record<string, unknown>;
      const { error } = await supabase
        .from("recebimentos")
        .delete()
        .eq("id", d.recebimento_id)
        .eq("tenant_id", tenantId);
      if (error) return { ok: false, error: `Erro ao deletar recebimento: ${error.message}` };
      return { ok: true, data: { deleted_recebimento_id: d.recebimento_id } };
    }

    default:
      return {
        ok: false,
        error: `Tool "${toolName}" nao possui operacao de escrita definida.`,
      };
  }
}
