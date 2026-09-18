import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workspace.dart';
import '../providers/tenant_provider.dart';
import '../services/database_helper.dart';
import '../services/database_seeder.dart';
import '../theme/app_theme.dart';

/// Etiqueta visible de respaldo para un espacio de trabajo sin nombre propio.
String tenantLabel(int tenantId) => 'Espacio $tenantId';

/// Pantalla de selección de espacio de trabajo (sin login real).
///
/// Cada "espacio" guarda sus propias personas y análisis, de forma
/// aislada. La lista de espacios es dinámica: se puede crear, renombrar
/// (mantener presionado) o eliminar uno en cualquier momento.
class DoctorSelectionScreen extends StatefulWidget {
  const DoctorSelectionScreen({super.key});

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final DatabaseSeeder _seeder = DatabaseSeeder();

  List<Workspace> _workspaces = [];
  bool _isLoadingList = true;
  int? _busyTenantId;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    final workspaces = await _db.getWorkspaces();
    if (!mounted) return;
    setState(() {
      _workspaces = workspaces;
      _isLoadingList = false;
    });
  }

  bool get _isBusy => _busyTenantId != null || _isCreating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.accessibility_new_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Anatomic AI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Detector de postura · elige tu espacio de trabajo',
                  style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (_isLoadingList)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  for (final workspace in _workspaces) ...[
                    _WorkspaceCard(
                      workspace: workspace,
                      isLoading: _busyTenantId == workspace.id,
                      disabled: _isBusy,
                      onTap: () => _selectTenant(context, workspace.id),
                      onLongPress: () => _openWorkspaceMenu(workspace),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _AddWorkspaceCard(
                    isLoading: _isCreating,
                    disabled: _isBusy,
                    onTap: _createWorkspace,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectTenant(BuildContext context, int tenantId) async {
    setState(() => _busyTenantId = tenantId);

    // Primer ingreso a este espacio: precargar datos de ejemplo en silencio,
    // para no arrancar con la app vacía.
    final hasData = await _seeder.hasSeededData(tenantId);
    if (!hasData) {
      await _seeder.seed(tenantId);
    }

    if (!mounted) return;
    final workspace = _workspaces.firstWhere((w) => w.id == tenantId);
    context
        .read<TenantProvider>()
        .setTenant(tenantId, name: workspace.displayName);
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  Future<void> _createWorkspace() async {
    final name = await _promptForName(
      title: 'Nuevo espacio',
      hint: 'Ej: Consultorio Norte (opcional)',
      confirmLabel: 'Crear',
    );
    if (name == null) return; // canceló

    setState(() => _isCreating = true);

    // Un espacio nuevo arranca vacío, sin datos de prueba: es para
    // seguimiento real o para empezar a agregar personas desde cero.
    final newId = await _db.addWorkspace(name: name.isEmpty ? null : name);

    if (!mounted) return;
    final displayName = name.isEmpty ? tenantLabel(newId) : name;
    context.read<TenantProvider>().setTenant(newId, name: displayName);
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  Future<void> _openWorkspaceMenu(Workspace workspace) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(workspace.displayName),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'rename'),
            child: const Row(
              children: [
                Icon(Icons.edit_rounded, size: 20, color: AppColors.ink),
                SizedBox(width: 12),
                Text('Renombrar'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Row(
              children: [
                Icon(Icons.delete_rounded, size: 20, color: AppColors.danger),
                SizedBox(width: 12),
                Text('Eliminar', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );

    if (action == 'rename') {
      await _renameWorkspace(workspace);
    } else if (action == 'delete') {
      await _deleteWorkspace(workspace);
    }
  }

  Future<void> _renameWorkspace(Workspace workspace) async {
    final name = await _promptForName(
      title: 'Renombrar espacio',
      hint: tenantLabel(workspace.id),
      confirmLabel: 'Guardar',
      initialValue: workspace.name ?? '',
    );
    if (name == null) return;

    await _db.renameWorkspace(workspace.id, name.isEmpty ? null : name);
    await _loadWorkspaces();
  }

  Future<void> _deleteWorkspace(Workspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${workspace.displayName}"?'),
        content: const Text(
          'Se perderán todas sus personas y análisis guardados. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _db.deleteWorkspace(workspace.id);
    await _loadWorkspaces();
  }

  /// Diálogo genérico para pedir el nombre de un espacio. Retorna `null` si
  /// se canceló, o el texto (puede ser vacío = "sin nombre propio").
  Future<String?> _promptForName({
    required String title,
    required String hint,
    required String confirmLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: hint,
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _WorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _WorkspaceCard({
    required this.workspace,
    required this.isLoading,
    required this.disabled,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(workspace.displayName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        onLongPress: disabled ? null : onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled && !isLoading ? 0.5 : 1,
          child: FlatCard(
            padding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: color,
                          ),
                        )
                      : Text(
                          '${workspace.id}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Personas y análisis propios',
                        style: TextStyle(
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
      ),
    );
  }
}

/// Tarjeta para crear un nuevo espacio de trabajo, con estilo punteado
/// para distinguirla de los espacios ya existentes.
class _AddWorkspaceCard extends StatelessWidget {
  final bool isLoading;
  final bool disabled;
  final VoidCallback onTap;

  const _AddWorkspaceCard({
    required this.isLoading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled && !isLoading ? 0.5 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.mutedInk.withValues(alpha: 0.35),
                width: 1.4,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  const Icon(Icons.add_rounded, color: AppColors.mutedInk),
                const SizedBox(width: 10),
                Text(
                  isLoading ? 'Creando espacio...' : 'Agregar espacio',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
