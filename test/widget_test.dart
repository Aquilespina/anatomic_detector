// Smoke test del dashboard.
//
// No se prueba DoctorSelectionScreen aquí: su initState consulta SQLite
// (workspaces) y ese plugin no está mockeado en un test de widgets puro,
// lo que tira `Bad state: databaseFactory not initialized`. DashboardScreen
// no toca la base de datos en su build, así que sirve como smoke test real
// sin necesitar un fake de sqflite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:escoliosis_detector/providers/tenant_provider.dart';
import 'package:escoliosis_detector/screens/dashboard_screen.dart';
import 'package:escoliosis_detector/theme/app_theme.dart';

void main() {
  testWidgets('El dashboard muestra el espacio activo y las acciones principales',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TenantProvider()..setTenant(1, name: 'Espacio 1'),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DashboardScreen(),
        ),
      ),
    );

    expect(find.text('Espacio 1'), findsOneWidget);
    expect(find.text('Nuevo análisis'), findsOneWidget);
    expect(find.text('Personas'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
  });
}
