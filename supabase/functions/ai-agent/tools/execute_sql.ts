import { AtrTool } from "../types.ts";

const READ_ONLY_RE = /^\s*(SELECT|EXPLAIN|SHOW|WITH\s)/i;
const BLOCKED_RE = /DROP\s+TABLE|TRUNCATE\s|DELETE\s+FROM\s+\w+\s*;|DROP\s+SCHEMA/i;

export const executeSql: AtrTool = {
  name: "execute_sql",
  category: "write",
  description:
    "Executa SQL no banco ATR. SELECT/EXPLAIN executa imediatamente e retorna dados. " +
    "CREATE TABLE / ALTER TABLE / CREATE INDEX requer confirmação do usuário. " +
    "DROP TABLE, TRUNCATE e DELETE sem filtro são bloqueados por segurança.",
  input_schema: {
    type: "object",
    properties: {
      sql: {
        type: "string",
        description: "SQL a executar. SELECT retorna dados imediatamente. CREATE/ALTER requer confirmação.",
      },
      description: {
        type: "string",
        description: "O que este SQL faz (obrigatório para DDL, ajuda no card de confirmação).",
      },
    },
    required: ["sql"],
  },

  preview: async (input) => {
    const sql = String(input.sql).trim();
    if (BLOCKED_RE.test(sql)) {
      return `🚫 Bloqueado: DROP TABLE, TRUNCATE e DELETE sem filtro não são permitidos.`;
    }
    if (READ_ONLY_RE.test(sql)) {
      return `🔍 Consulta SQL (execução imediata):\n\`\`\`sql\n${sql}\n\`\`\``;
    }
    return `⚠️ DDL — requer confirmação:\n\`\`\`sql\n${sql}\n\`\`\`\n${input.description || ""}`;
  },

  handler: async (input, ctx) => {
    const sql = String(input.sql).trim();

    if (BLOCKED_RE.test(sql)) {
      return { ok: false, error: "Bloqueado: DROP TABLE, TRUNCATE e DELETE sem filtro não são permitidos. Use o painel Supabase para operações destrutivas." };
    }

    if (READ_ONLY_RE.test(sql)) {
      const supabase = ctx.supabase as any;
      const tenantId = ctx.tenant_id as string;
      const { data, error } = await supabase.rpc("execute_tenant_sql", {
        p_sql: sql,
        p_tenant_id: tenantId,
      });
      if (error) return { ok: false, error: `Erro SQL: ${error.message}` };
      const count = Array.isArray(data) ? data.length : 1;
      return { ok: true, data, display: `✅ Consulta executada — ${count} linha(s) retornada(s).` };
    }

    // DDL: devolve dados para confirmation.ts executar após aprovação do usuário
    return {
      ok: true,
      data: { sql, description: input.description || "" },
      display: `DDL preparado — aguardando confirmação do usuário.`,
    };
  },
};
