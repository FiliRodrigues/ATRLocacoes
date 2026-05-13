import 'package:intl/intl.dart';
import '../enums/vehicle_status.dart';

// ═══════════════════════════════════════════════════════
// FORMATAÇÃO — extraído de fleet_data.dart (refactor M1)
// ═══════════════════════════════════════════════════════

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
final NumberFormat _thousandsFormatter = NumberFormat.decimalPattern('pt_BR');

String formatDate(DateTime date) {
  return _dateFormatter.format(date);
}

String formatCurrency(double value) {
  final isNeg = value < 0;
  final abs = value.abs();
  final intP = abs.toInt();
  final dec = ((abs - intP) * 100).round().toString().padLeft(2, '0');
  final fmt = _thousandsFormatter.format(intP);
  return '${isNeg ? '-' : ''}R\$ $fmt,$dec';
}

String formatKm(double km) {
  final intKm = km.toInt();
  return '${_thousandsFormatter.format(intKm)} km';
}

const List<VehicleStatus> statusOptions = VehicleStatus.values;
