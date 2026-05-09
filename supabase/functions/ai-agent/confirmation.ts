import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { TOOLS_REGISTRY } from "./tools/index.ts";
import type { ToolContext } from "./types.ts";

// ================================================================
// Sistema de confirmacao de acoes write (two-step)
// ================================================================

const TTL_MS = 15 * 60 * 1000; // 15 minutos

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
 * 3. Verifica TTL (15 min)
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
    serviceClient: SupabaseClient;
  }
): Promise<{ ok: boolean; data?: unknown; error?: string; display?: string }> {
  const supabase = params.serviceClient;

  // 1. Carrega audit
  const { data: audit, error: loadErr } = await supabase
    .from("ai_action_audit")
    .select("*")
    .eq("id", actionId)
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

  // 2. Verifica TTL (15 minutos)
  const age = Date.now() - new Date(audit.created_at).getTime();
  if (age > TTL_MS) {
    await supabase
      .from("ai_action_audit")
      .update({ status: "cancelled", error: "Expirada (>15 min)" })
      .eq("id", actionId);
    return { ok: false, error: "Acao expirou (>15 min). Refaca o pedido." };
  }

  // 3. Busca a tool
  const tool = TOOLS_REGISTRY[audit.tool_name];
  if (!tool) {
    return { ok: false, error: `Tool "${audit.tool_name}" nao encontrada.` };
  }

  // 4. Constroi contexto para a tool (usa serviceClient para bypass RLS na escrita)
  const ctx: ToolContext = {
    tenant_id: params.tenant_id,
    user_id: params.user_id,
    conversation_id: audit.conversation_id || "",
    channel: "web",
    userClient: supabase,
    serviceClient: supabase,
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
        .eq("id", actionId);

      return handlerResult;
    }

    // 6. Executa a operacao de escrita no banco
    const writeResult = await executeWriteOperation(
      audit.tool_name,
      handlerResult.data,
      supabase,
      params.tenant_id
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
      .eq("id", actionId);

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
      .eq("id", actionId);
    return { ok: false, error: msg };
  }
}

/**
 * Cancela uma acao pendente.
 */
export async function cancelAction(
  actionId: string,
  userId: string,
  serviceClient: SupabaseClient
): Promise<boolean> {
  const { data: audit } = await serviceClient
    .from("ai_action_audit")
    .select("user_id, status")
    .eq("id", actionId)
    .single();

  if (!audit || audit.user_id !== userId || audit.status !== "pending_confirmation") {
    return false;
  }

  await serviceClient
    .from("ai_action_audit")
    .update({ status: "cancelled" })
    .eq("id", actionId);

  return true;
}

// ================================================================
// Helpers internos: executa a operacao de escrita no banco
// ================================================================

async function executeWriteOperation(
  toolName: string,
  validatedData: unknown,
  supabase: SupabaseClient,
  tenantId: string
): Promise<{ ok: boolean; data?: unknown; error?: string }> {
  switch (toolName) {
    // ----------------------------------------------------------
    // create_maintenance: INSERT em manutencoes
    // ----------------------------------------------------------
    case "create_maintenance": {
      const d = validatedData as Record<string, unknown>;
      const insert: Record<string, unknown> = {
        tenant_id: tenantId,
        veiculo_id: d.vehicle_id,
        data_servico: d.date,
        tipo_servico: d.type || null,
        descricao: d.description || null,
        oficina: d.workshop_name || null,
        valor_servico: d.cost != null ? Number(d.cost) : null,
        km_registro: d.mileage != null ? Number(d.mileage) : null,
        status_pagamento: "Pendente",
      };

      const { data, error } = await supabase
        .from("manutencoes")
        .insert(insert)
        .select("id, veiculo_id, data_servico, tipo_servico, descricao, valor_servico, status_pagamento")
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
        tenant_id: tenantId,
        veiculo_placa: d.vehicle_plate || null,
        data: d.date,
        tipo: d.tipo || null,
        descricao: d.descricao || null,
        valor: d.valor != null ? Number(d.valor) : null,
        pago: false,
      };

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

      // Atualiza km_atual na tabela veiculos
      const { error: updErr } = await supabase
        .from("veiculos")
        .update({ km_atual: d.new_mileage })
        .eq("id", d.vehicle_id)
        .eq("tenant_id", tenantId);

      if (updErr) return { ok: false, error: `Erro ao atualizar km: ${updErr.message}` };

      // Registra entrada na tabela hodometros
      const hodEntry = (d.hodometro_entry as Record<string, unknown>) || {};
      const { data: hod, error: hodErr } = await supabase
        .from("hodometros")
        .insert({
          veiculo_placa: d.plate || hodEntry.veiculo_placa,
          km: d.new_mileage || hodEntry.km,
          registrado_por: hodEntry.registrado_por || "ia_assistant",
          tenant_id: tenantId,
        })
        .select("id, veiculo_placa, km, registrado_por")
        .single();

      if (hodErr) return { ok: false, error: `Hodometro registrado mas com erro no historico: ${hodErr.message}` };

      return {
        ok: true,
        data: {
          vehicle_plate: d.plate,
          old_mileage: d.old_mileage,
          new_mileage: d.new_mileage,
          hodometro: hod,
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
          tenant_id: tenantId,
          veiculo_id: item.vehicle_id,
          data_servico: item.date,
          tipo_servico: item.type || null,
          descricao: item.description || null,
          oficina: item.workshop_name || null,
          valor_servico: item.cost != null ? Number(item.cost) : null,
          km_registro: item.mileage != null ? Number(item.mileage) : null,
          status_pagamento: "Pendente",
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

      return {
        ok: true,
        data: {
          total: items.length,
          sucessos,
          falhas,
          results,
        },
      };
    }

    default:
      return {
        ok: false,
        error: `Tool "${toolName}" nao possui operacao de escrita definida.`,
      };
  }
}
