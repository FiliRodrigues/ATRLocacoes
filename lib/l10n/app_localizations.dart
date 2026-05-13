import 'package:flutter/material.dart';

/// Localizacoes manuais (sem code-gen).
/// Os arquivos .arb em lib/l10n/ sao a fonte de verdade para tradutores.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const _pt = <String, String>{
    'appTitle': 'ATR Locações',
    'loading': 'Carregando...',
    'save': 'Salvar',
    'cancel': 'Cancelar',
    'delete': 'Excluir',
    'edit': 'Editar',
    'new': 'Novo',
    'search': 'Buscar',
    'export': 'Exportar',
    'confirm': 'Confirmar',
    'error': 'Erro',
    'success': 'Sucesso',
    'yes': 'Sim',
    'no': 'Não',
    'back': 'Voltar',
    'vehicles': 'Veículos',
    'drivers': 'Motoristas',
    'contracts': 'Contratos',
    'costs': 'Custos',
    'reports': 'Relatórios',
    'settings': 'Configurações',
    'logout': 'Sair',
    'dashboard': 'Dashboard',
    'maintenance': 'Manutenção',
    'fuel': 'Combustível',
    'expenses': 'Despesas',
    'statusPending': 'Pendente',
    'statusPaid': 'Pago',
    'statusActive': 'Ativo',
    'statusInactive': 'Inativo',
    'noData': 'Nenhum dado disponível',
    'confirmDelete': 'Tem certeza que deseja excluir?',
    'saveSuccess': 'Salvo com sucesso',
    'saveError': 'Erro ao salvar',
    'requiredField': 'Campo obrigatório',
    'plate': 'Placa',
    'model': 'Modelo',
    'year': 'Ano',
    'km': 'KM',
    'value': 'Valor',
    'date': 'Data',
  };

  static const _en = <String, String>{
    'appTitle': 'ATR Rentals',
    'loading': 'Loading...',
    'save': 'Save',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'edit': 'Edit',
    'new': 'New',
    'search': 'Search',
    'export': 'Export',
    'confirm': 'Confirm',
    'error': 'Error',
    'success': 'Success',
    'yes': 'Yes',
    'no': 'No',
    'back': 'Back',
    'vehicles': 'Vehicles',
    'drivers': 'Drivers',
    'contracts': 'Contracts',
    'costs': 'Costs',
    'reports': 'Reports',
    'settings': 'Settings',
    'logout': 'Logout',
    'dashboard': 'Dashboard',
    'maintenance': 'Maintenance',
    'fuel': 'Fuel',
    'expenses': 'Expenses',
    'statusPending': 'Pending',
    'statusPaid': 'Paid',
    'statusActive': 'Active',
    'statusInactive': 'Inactive',
    'noData': 'No data available',
    'confirmDelete': 'Are you sure you want to delete?',
    'saveSuccess': 'Saved successfully',
    'saveError': 'Error saving',
    'requiredField': 'Required field',
    'plate': 'License Plate',
    'model': 'Model',
    'year': 'Year',
    'km': 'Mileage',
    'value': 'Value',
    'date': 'Date',
  };

  Map<String, String> get _strings =>
      locale.languageCode == 'en' ? _en : _pt;

  String get(String key) => _strings[key] ?? key;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['pt', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
