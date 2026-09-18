import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Multitenant
import 'providers/tenant_provider.dart';
import 'screens/doctor_selection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/comparison_screen.dart';
import 'screens/patients_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => TenantProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anatomic AI: Detector Postural',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // La app arranca en la selección de espacio de trabajo
      initialRoute: '/',
      routes: {
        '/': (context) => const DoctorSelectionScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const HistoryScreen(),
        '/comparison': (context) => const ComparisonScreen(),
        '/patients': (context) => const PatientsScreen(),
      },
    );
  }
}
