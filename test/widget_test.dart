// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fleet_app/main.dart';
import 'package:fleet_app/core/services/auth_service.dart';
import 'package:fleet_app/features/maintenance/maintenance_provider.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const ATRApp(),
      ),
    );

    // Wait for any async operations
    await tester.pumpAndSettle();

    // Verify that the app builds
    expect(find.byType(ATRApp), findsOneWidget);
  });
}
