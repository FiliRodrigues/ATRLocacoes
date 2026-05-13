import { AtrTool, ToolDefinition } from "../types.ts";

// ── READ — Frota ──────────────────────────────────────────────────
import { listVehicles } from "./list_vehicles.ts";
import { getVehicleDetails } from "./get_vehicle_details.ts";
import { listMaintenances } from "./list_maintenances.ts";
import { listContracts } from "./list_contracts.ts";
import { getFinancingStatus } from "./get_financing_status.ts";
import { getCostsSummary } from "./get_costs_summary.ts";
import { listDrivers } from "./list_drivers.ts";
import { extractInvoiceData } from "./extract_invoice_data.ts";
import { getIpva } from "./get_ipva.ts";
import { getLicenciamento } from "./get_licenciamento.ts";
import { getSeguros } from "./get_seguros.ts";
import { getParcelasSeguro } from "./get_parcelas_seguro.ts";
import { getMultas } from "./get_multas.ts";
import { getChecklistEventos } from "./get_checklist_eventos.ts";
import { getOcorrencias } from "./get_ocorrencias.ts";
import { getAbastecimentos } from "./get_abastecimentos.ts";
import { getRegrasManutencao } from "./get_regras_manutencao.ts";
import { getRecebimentos } from "./get_recebimentos.ts";
import { listExpenses } from "./list_expenses.ts";
import { searchGlobal } from "./search_global.ts";

import { getAlertasFrota } from "./get_alertas_frota.ts";
import { getContratosProximosVencer } from "./get_contratos_proximos_vencer.ts";

// ── WRITE — Frota ─────────────────────────────────────────────────
import { createMaintenance } from "./create_maintenance.ts";
import { createMaintenancesBatch } from "./create_maintenances_batch.ts";
import { updateMaintenance } from "./update_maintenance.ts";
import { deleteMaintenance } from "./delete_maintenance.ts";
import { createExpense } from "./create_expense.ts";
import { updateExpense } from "./update_expense.ts";
import { deleteExpense } from "./delete_expense.ts";
import { createVehicle } from "./create_vehicle.ts";
import { updateVehicle } from "./update_vehicle.ts";
import { updateVehicleMileage } from "./update_vehicle_mileage.ts";
import { deleteVehicle } from "./delete_vehicle.ts";
import { createAbastecimento } from "./create_abastecimento.ts";
import { updateAbastecimento, deleteAbastecimento } from "./update_abastecimento.ts";
import { createContract } from "./create_contract.ts";
import { updateContract } from "./update_contract.ts";
import { deleteContract } from "./delete_contract.ts";
import { createRegraManutencao, updateRegraManutencao, createOcorrencia, updateOcorrencia, deleteOcorrencia, deleteRegraManutencao } from "./manage_rules_checklist.ts";
import { updatePaymentStatus, createRecebimento, deleteRecebimento } from "./manage_finance.ts";
import { createChecklistEvento, updateChecklistEvento } from "./manage_checklist.ts";
import { createSeguro, updateSeguro } from "./manage_seguros.ts";
import { createFinanciamento, updateFinanciamento } from "./manage_financiamento.ts";
import { deleteFinanciamento, updateParcelaSeguro, createHodometro, updateIpva, updateLicenciamento, updateMulta, validateKmIntervalo } from "./manage_finance_extended.ts";

// ── READ + WRITE — Sala ATR ───────────────────────────────────────
import {
  listSalaAtrAgendamentos,
  getSalaAtrAgendamento,
  listSalaAtrDespesas,
  listSalaAtrPacotes,
  checkDisponibilidadeSala,
  relatorioOcupacaoSala,
  createSalaAtrAgendamento,
  updateSalaAtrAgendamento,
  deleteSalaAtrAgendamento,
  createSalaAtrDespesa,
  updateSalaAtrDespesa,
  deleteSalaAtrDespesa,
  createSalaAtrPacote,
  updateSalaAtrPacote,
  deleteSalaAtrPacote,
} from "./manage_sala_atr.ts";

// ── READ + WRITE — Lazer ATR ──────────────────────────────────────
import {
  listLazerEventos,
  listLazerDespesas,
  relatorioLazer,
  createLazerEvento,
  updateLazerEvento,
  deleteLazerEvento,
  createLazerDespesa,
  updateLazerDespesa,
  deleteLazerDespesa,
} from "./manage_lazer.ts";

export const TOOLS_REGISTRY: Record<string, AtrTool> = {
  // ── READ — Frota (23 tools) ───────────────────────────────────
  list_vehicles: listVehicles,
  get_vehicle_details: getVehicleDetails,
  list_maintenances: listMaintenances,
  list_contracts: listContracts,
  get_financing_status: getFinancingStatus,
  get_costs_summary: getCostsSummary,
  list_drivers: listDrivers,
  extract_invoice_data: extractInvoiceData,
  get_ipva: getIpva,
  get_licenciamento: getLicenciamento,
  get_seguros: getSeguros,
  get_parcelas_seguro: getParcelasSeguro,
  get_multas: getMultas,
  get_checklist_eventos: getChecklistEventos,
  get_ocorrencias: getOcorrencias,
  get_abastecimentos: getAbastecimentos,
  get_regras_manutencao: getRegrasManutencao,
  get_recebimentos: getRecebimentos,
  list_expenses: listExpenses,
  search_global: searchGlobal,
  get_alertas_frota: getAlertasFrota,
  get_contratos_proximos_vencer: getContratosProximosVencer,
  validate_km_intervalo: validateKmIntervalo,

  // ── WRITE — Manutenções (4) ───────────────────────────────────
  create_maintenance: createMaintenance,
  create_maintenances_batch: createMaintenancesBatch,
  update_maintenance: updateMaintenance,
  delete_maintenance: deleteMaintenance,

  // ── WRITE — Despesas (3) ──────────────────────────────────────
  create_expense: createExpense,
  update_expense: updateExpense,
  delete_expense: deleteExpense,

  // ── WRITE — Veículos (4) ──────────────────────────────────────
  create_vehicle: createVehicle,
  update_vehicle: updateVehicle,
  update_vehicle_mileage: updateVehicleMileage,
  delete_vehicle: deleteVehicle,

  // ── WRITE — Abastecimentos (3) ────────────────────────────────
  create_abastecimento: createAbastecimento,
  update_abastecimento: updateAbastecimento,
  delete_abastecimento: deleteAbastecimento,

  // ── WRITE — Contratos (3) ─────────────────────────────────────
  create_contract: createContract,
  update_contract: updateContract,
  delete_contract: deleteContract,

  // ── WRITE — Checklist (2) ─────────────────────────────────────
  create_checklist_evento: createChecklistEvento,
  update_checklist_evento: updateChecklistEvento,

  // ── WRITE — Seguros (2) ───────────────────────────────────────
  create_seguro: createSeguro,
  update_seguro: updateSeguro,

  // ── WRITE — Financiamentos (2) ────────────────────────────────
  create_financiamento: createFinanciamento,
  update_financiamento: updateFinanciamento,

  // ── WRITE — Regras, Ocorrências, Finanças (12) ────────────────
  create_regra_manutencao: createRegraManutencao,
  update_regra_manutencao: updateRegraManutencao,
  delete_regra_manutencao: deleteRegraManutencao,
  create_ocorrencia: createOcorrencia,
  update_ocorrencia: updateOcorrencia,
  delete_ocorrencia: deleteOcorrencia,
  update_payment_status: updatePaymentStatus,
  create_recebimento: createRecebimento,
  delete_recebimento: deleteRecebimento,
  delete_financiamento: deleteFinanciamento,
  update_parcela_seguro: updateParcelaSeguro,
  create_hodometro: createHodometro,
  update_ipva: updateIpva,
  update_licenciamento: updateLicenciamento,
  update_multa: updateMulta,

  // ── READ + WRITE — Sala ATR (14) ──────────────────────────────
  list_sala_atr_agendamentos: listSalaAtrAgendamentos,
  get_sala_atr_agendamento: getSalaAtrAgendamento,
  list_sala_atr_despesas: listSalaAtrDespesas,
  list_sala_atr_pacotes: listSalaAtrPacotes,
  check_disponibilidade_sala: checkDisponibilidadeSala,
  relatorio_ocupacao_sala: relatorioOcupacaoSala,
  create_sala_atr_agendamento: createSalaAtrAgendamento,
  update_sala_atr_agendamento: updateSalaAtrAgendamento,
  delete_sala_atr_agendamento: deleteSalaAtrAgendamento,
  create_sala_atr_despesa: createSalaAtrDespesa,
  update_sala_atr_despesa: updateSalaAtrDespesa,
  delete_sala_atr_despesa: deleteSalaAtrDespesa,
  create_sala_atr_pacote: createSalaAtrPacote,
  update_sala_atr_pacote: updateSalaAtrPacote,
  delete_sala_atr_pacote: deleteSalaAtrPacote,

  // ── READ + WRITE — Lazer ATR (9) ──────────────────────────────
  list_lazer_eventos: listLazerEventos,
  list_lazer_despesas: listLazerDespesas,
  relatorio_lazer: relatorioLazer,
  create_lazer_evento: createLazerEvento,
  update_lazer_evento: updateLazerEvento,
  delete_lazer_evento: deleteLazerEvento,
  create_lazer_despesa: createLazerDespesa,
  update_lazer_despesa: updateLazerDespesa,
  delete_lazer_despesa: deleteLazerDespesa,
};

export const TOOL_DEFINITIONS: ToolDefinition[] = Object.values(TOOLS_REGISTRY).map((t) => ({
  name: t.name,
  description: t.description,
  input_schema: t.input_schema,
}));
