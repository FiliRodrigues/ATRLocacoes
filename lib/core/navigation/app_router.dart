import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/vehicles/vehicle_dossier_screen.dart';
import '../../features/drivers/drivers_screen.dart';
import '../../features/maintenance/maintenance_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/financial_admin/financial_admin_screen.dart';
import '../../features/login/login_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'vehicles/:plate',
            builder: (context, state) {
              final plate = state.pathParameters['plate'] ?? '';
              return VehicleDossierScreen(plateId: plate);
            },
          ),
          GoRoute(
            path: 'drivers',
            builder: (context, state) => const DriversScreen(),
          ),
          GoRoute(
            path: 'maintenance',
            builder: (context, state) => const MaintenanceScreen(),
          ),
          GoRoute(
            path: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: 'financial-admin',
            builder: (context, state) => const FinancialAdminScreen(),
            routes: [
              GoRoute(
                path: ':index',
                builder: (context, state) {
                  final index = int.tryParse(state.pathParameters['index'] ?? '');
                  return FinancialAdminScreen(vehicleIndex: index);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
