import { AtrTool, ToolDefinition } from "../types.ts";

import { listVehicles } from "./list_vehicles.ts";
import { getVehicleDetails } from "./get_vehicle_details.ts";
import { listMaintenances } from "./list_maintenances.ts";
import { listContracts } from "./list_contracts.ts";
import { getFinancingStatus } from "./get_financing_status.ts";
import { getCostsSummary } from "./get_costs_summary.ts";
import { listDrivers } from "./list_drivers.ts";
import { createMaintenance } from "./create_maintenance.ts";
import { createExpense } from "./create_expense.ts";
import { updateVehicleMileage } from "./update_vehicle_mileage.ts";
import { extractInvoiceData } from "./extract_invoice_data.ts";
import { createMaintenancesBatch } from "./create_maintenances_batch.ts";

export const TOOLS_REGISTRY: Record<string, AtrTool> = {
  list_vehicles: listVehicles,
  get_vehicle_details: getVehicleDetails,
  list_maintenances: listMaintenances,
  list_contracts: listContracts,
  get_financing_status: getFinancingStatus,
  get_costs_summary: getCostsSummary,
  list_drivers: listDrivers,
  create_maintenance: createMaintenance,
  create_expense: createExpense,
  update_vehicle_mileage: updateVehicleMileage,
  extract_invoice_data: extractInvoiceData,
  create_maintenances_batch: createMaintenancesBatch,
};

export const TOOL_DEFINITIONS: ToolDefinition[] = Object.values(TOOLS_REGISTRY).map((t) => ({
  name: t.name,
  description: t.description,
  input_schema: t.input_schema,
}));
