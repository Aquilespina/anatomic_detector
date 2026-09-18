import 'package:flutter/material.dart';

/// Paleta y estilos compartidos de la app.
///
/// Diseño minimalista orientado a postura/bienestar: sin degradados
/// "corporativos" ni iconografía de hospital. Un solo acento (verde
/// azulado) sobre superficies neutras.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF6F7F5);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF1C1E21);
  static const Color mutedInk = Color(0xFF6B7280);
  static const Color border = Color(0xFFE7E9E5);

  static const Color primary = Color(0xFF1F8A70);
  static const Color primaryDark = Color(0xFF166B57);

  static const Color success = Color(0xFF1F8A70);
  static const Color warning = Color(0xFFD98F32);
  static const Color danger = Color(0xFFC65A5A);

  /// Fallo técnico del análisis (p. ej. el modelo de IA no pudo correr):
  /// no es un resultado clínico, así que se distingue del resto a propósito.
  static const Color technicalError = Color(0xFF57606A);

  static Color forResultLabel(String label) {
    switch (label) {
      case 'Saludable':
        return success;
      case 'Posible escoliosis':
        return warning;
      case 'Indeterminado':
        return danger;
      case 'Error':
        return technicalError;
      default:
        return mutedInk;
    }
  }

  static IconData iconForResultLabel(String label) {
    switch (label) {
      case 'Saludable':
        return Icons.check_circle_rounded;
      case 'Posible escoliosis':
        return Icons.warning_rounded;
      case 'Indeterminado':
        return Icons.help_rounded;
      case 'Error':
        return Icons.error_outline_rounded;
      default:
        return Icons.circle;
    }
  }
}

/// Colores estables (determinísticos) para avatares de pacientes.
const List<Color> kAvatarPalette = [
  Color(0xFF1F8A70),
  Color(0xFF3E7CB1),
  Color(0xFFB1743E),
  Color(0xFF8A5FB0),
  Color(0xFFB0503E),
  Color(0xFF4E9B6F),
];

Color avatarColorFor(String seed) {
  final code = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return kAvatarPalette[code % kAvatarPalette.length];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}

/// Tarjeta plana reutilizable (borde sutil, sin sombra dura).
class FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FlatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
