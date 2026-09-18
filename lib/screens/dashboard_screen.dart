import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'doctor_selection_screen.dart';

/// Pantalla principal del espacio de trabajo activo.
///
/// Punto de partida hacia el detector postural, las personas registradas
/// y el historial de análisis.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final tenantId = tenant.tenantId;
    final displayName = tenant.workspaceName ??
        (tenantId != null ? tenantLabel(tenantId) : 'Dashboard');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _renameWorkspace(context);
              if (value == 'switch') _logout(context);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Renombrar espacio'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Cambiar de espacio'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detector de postura',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Toma una foto de espalda para analizar la alineación '
                'postural, o revisa el seguimiento de una persona.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedInk,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _ActionCard(
                icon: Icons.accessibility_new_rounded,
                title: 'Nuevo análisis',
                subtitle: 'Analiza una foto de espalda al instante',
                color: AppColors.primary,
                onTap: () => Navigator.pushNamed(context, '/home'),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.people_outline_rounded,
                title: 'Personas',
                subtitle: 'Agrega o revisa a quién le haces seguimiento',
                color: const Color(0xFF3E7CB1),
                onTap: () => Navigator.pushNamed(context, '/patients'),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.history_rounded,
                title: 'Historial',
                subtitle: 'Todos los análisis guardados en este espacio',
                color: const Color(0xFF8A5FB0),
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameWorkspace(BuildContext context) async {
    final tenant = context.read<TenantProvider>();
    final tenantId = tenant.tenantId;
    if (tenantId == null) return;

    final controller = TextEditingController(
      text: tenant.workspaceName == tenantLabel(tenantId)
          ? ''
          : tenant.workspaceName,
    );

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar espacio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: tenantLabel(tenantId),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;

    await _db.renameWorkspace(tenantId, name.isEmpty ? null : name);
    if (!mounted) return;
    tenant.updateWorkspaceName(name.isEmpty ? tenantLabel(tenantId) : name);
  }

  void _logout(BuildContext context) {
    context.read<TenantProvider>().clearTenant();
    Navigator.pushReplacementNamed(context, '/');
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: FlatCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.mutedInk.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
