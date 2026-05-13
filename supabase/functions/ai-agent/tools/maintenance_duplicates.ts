export type DuplicateMaintenanceMatch = {
  id: string;
  veiculo_id: string;
  data: string;
  tipo: string | null;
  custo: number | null;
  descricao: string | null;
  dateDiffDays: number;
  valueDiff: number;
};

export type DuplicateMaintenanceCheckResult = {
  isDuplicate: boolean;
  matches: DuplicateMaintenanceMatch[];
};

type CheckInput = {
  supabase: any;
  tenantId: string;
  vehicleId: string;
  date: string;
  type: string;
  cost: number;
  dateToleranceDays?: number;
  valueTolerance?: number;
};

const DEFAULT_DATE_TOLERANCE_DAYS = 7;
const DEFAULT_VALUE_TOLERANCE = 20;

function normalizeType(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

function typeMatches(existingRaw: unknown, targetNormalized: string): boolean {
  const existingNormalized = normalizeType(String(existingRaw ?? ""));
  if (!existingNormalized || !targetNormalized) return false;

  if (existingNormalized === targetNormalized) return true;
  if (existingNormalized.includes(targetNormalized)) return true;
  if (targetNormalized.includes(existingNormalized)) return true;

  const existingTokens = existingNormalized.split(" ").filter((t) => t.length >= 3);
  const targetTokens = targetNormalized.split(" ").filter((t) => t.length >= 3);
  if (existingTokens.length === 0 || targetTokens.length === 0) return false;

  const targetSet = new Set(targetTokens);
  const overlap = existingTokens.filter((t) => targetSet.has(t)).length;
  const requiredOverlap = Math.max(1, Math.ceil(Math.min(existingTokens.length, targetTokens.length) * 0.6));
  return overlap >= requiredOverlap;
}

function parseDateOnly(dateValue: string): Date {
  const date = new Date(`${dateValue}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Data inválida para checagem de duplicidade: ${dateValue}`);
  }
  return date;
}

function isoDateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function absDaysBetween(a: Date, b: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round(Math.abs(a.getTime() - b.getTime()) / msPerDay);
}

export async function checkDuplicateMaintenance(input: CheckInput): Promise<DuplicateMaintenanceCheckResult> {
  const dateToleranceDays = input.dateToleranceDays ?? DEFAULT_DATE_TOLERANCE_DAYS;
  const valueTolerance = input.valueTolerance ?? DEFAULT_VALUE_TOLERANCE;

  const targetDate = parseDateOnly(input.date);
  const minDate = new Date(targetDate);
  minDate.setUTCDate(minDate.getUTCDate() - dateToleranceDays);
  const maxDate = new Date(targetDate);
  maxDate.setUTCDate(maxDate.getUTCDate() + dateToleranceDays);

  const targetType = normalizeType(input.type);

  const { data, error } = await input.supabase
    .from("manutencoes")
    .select("id, veiculo_id, data, tipo, custo, descricao")
    .eq("tenant_id", input.tenantId)
    .eq("veiculo_id", input.vehicleId)
    .gte("data", isoDateOnly(minDate))
    .lte("data", isoDateOnly(maxDate));

  if (error) {
    throw new Error(`Erro ao checar duplicidade de manutenção: ${error.message}`);
  }

  const matches: DuplicateMaintenanceMatch[] = [];

  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    if (!typeMatches(row.tipo, targetType)) continue;

    const existingValue = Number(row.custo ?? 0);
    const valueDiff = Math.abs(existingValue - input.cost);
    if (valueDiff > valueTolerance) continue;

    const existingDate = parseDateOnly(String(row.data));
    const dateDiffDays = absDaysBetween(existingDate, targetDate);
    if (dateDiffDays > dateToleranceDays) continue;

    matches.push({
      id: String(row.id),
      veiculo_id: String(row.veiculo_id),
      data: String(row.data),
      tipo: row.tipo == null ? null : String(row.tipo),
      custo: row.custo == null ? null : Number(row.custo),
      descricao: row.descricao == null ? null : String(row.descricao),
      dateDiffDays,
      valueDiff,
    });
  }

  matches.sort((a, b) => {
    if (a.dateDiffDays !== b.dateDiffDays) return a.dateDiffDays - b.dateDiffDays;
    return a.valueDiff - b.valueDiff;
  });

  return {
    isDuplicate: matches.length > 0,
    matches,
  };
}

export function buildDuplicateWarningMessage(matches: DuplicateMaintenanceMatch[], maxItems = 3): string {
  const listed = matches.slice(0, maxItems);
  const lines = listed.map((m, index) => {
    const valor = m.custo != null ? `R$ ${m.custo.toFixed(2).replace(".", ",")}` : "sem valor";
    const tipo = m.tipo ?? "tipo não informado";
    return `${index + 1}) ${m.data} • ${tipo} • ${valor} • id ${m.id}`;
  });

  const more = matches.length > maxItems ? `\n... e mais ${matches.length - maxItems} registro(s).` : "";
  return `⚠️ Possível duplicidade detectada (${matches.length} registro(s) similar(es)):\n${lines.join("\n")}${more}`;
}
