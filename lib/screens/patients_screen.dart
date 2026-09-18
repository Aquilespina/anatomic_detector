import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../models/workspace.dart';
import '../providers/tenant_provider.dart';
import '../services/database_helper.dart';
import '../services/database_seeder.dart';
import '../theme/app_theme.dart';

/// Pantalla de pacientes del perfil activo.
///
/// Permite ver quiénes ya tienen análisis y agregar más personas al set
/// de datos (reales o de prueba) sin necesidad de tomar una foto primero.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final DatabaseSeeder _seeder = DatabaseSeeder();

  List<Patient> _patients = [];
  Map<int, int> _analysisCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null) return;

    setState(() => _isLoading = true);
    final patients = await _db.getPatientsByTenant(tenantId);
    final counts = <int, int>{};
    for (final patient in patients) {
      if (patient.id != null) {
        counts[patient.id!] =
            await _db.countByPatient(tenantId, patient.name);
      }
    }

    if (!mounted) return;
    setState(() {
      _patients = patients;
      _analysisCounts = counts;
      _isLoading = false;
    });
  }

  Future<void> _addPatient() async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null) return;

    final controller = TextEditingController();
    bool addSampleAnalysis = true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agregar persona'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Pedro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: addSampleAnalysis,
                onChanged: (v) =>
                    setDialogState(() => addSampleAnalysis = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Incluir un análisis de ejemplo',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Útil para probar historial y comparación sin tomar una foto.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == null || result.isEmpty) return;

    if (await _db.patientExists(tenantId, result)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$result" ya existe en esta lista.')),
        );
      }
      return;
    }

    await _db.insertPatient(Patient(
      tenantId: tenantId,
      name: result,
      createdAt: DateTime.now(),
      isTestPatient: addSampleAnalysis,
    ));

    if (addSampleAnalysis) {
      await _seeder.seedForPatient(tenantId, result);
    }

    await _load();
  }

  /// Elimina a la persona de la lista de "Personas". Por defecto conserva
  /// su historial en el Historial general (solo deja de tener una fila
  /// propia acá); con la casilla marcada, borra también sus análisis e
  /// imágenes, de forma permanente.
  Future<void> _deletePatient(Patient patient) async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null || patient.id == null) return;

    bool alsoDeleteHistory = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('¿Eliminar a "${patient.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dejará de aparecer en Personas. Sus análisis guardados se '
                'conservan en el Historial general, salvo que elijas '
                'borrarlos también.',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: alsoDeleteHistory,
                onChanged: (v) =>
                    setDialogState(() => alsoDeleteHistory = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'También borrar su historial de análisis',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Permanente: borra sus análisis e imágenes guardadas.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            ],
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
      ),
    );

    if (confirmed != true) return;

    await _db.deletePatient(patient.id!);
    if (alsoDeleteHistory) {
      await _db.deleteRecordsByPatient(tenantId, patient.name);
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminó a "${patient.name}".')),
      );
    }
  }

  /// Trae una persona (con su historial de análisis) desde otro espacio,
  /// para tenerla también aquí sin perder lo que ya tiene este espacio.
  Future<void> _importFromAnotherWorkspace() async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null) return;

    final otherWorkspaces = (await _db.getWorkspaces())
        .where((w) => w.id != tenantId)
        .toList();

    if (otherWorkspaces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay otros espacios todavía.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final source = await showDialog<Workspace>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Importar desde...'),
        children: otherWorkspaces
            .map((w) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, w),
                  child: Text(w.displayName),
                ))
            .toList(),
      ),
    );
    if (source == null) return;
    final sourceId = source.id;

    final sourcePatients = await _db.getPatientsByTenant(sourceId);
    if (sourcePatients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${source.displayName} no tiene personas todavía.'),
          ),
        );
      }
      return;
    }

    final selected = <String>{};
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Personas en ${source.displayName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: sourcePatients.map((patient) {
                return CheckboxListTile(
                  value: selected.contains(patient.name),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(patient.name);
                    } else {
                      selected.remove(patient.name);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(patient.name),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed:
                  selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected.isEmpty) return;

    for (final name in selected) {
      await _db.copyPatientToTenant(
        sourceTenantId: sourceId,
        targetTenantId: tenantId,
        patientName: name,
      );
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron ${selected.length} persona${selected.length == 1 ? '' : 's'} '
            'desde ${source.displayName}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.input_rounded),
            tooltip: 'Importar de otro espacio',
            onPressed: _importFromAnotherWorkspace,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Agregar persona'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: AppColors.mutedInk.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay personas registradas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega una persona para empezar a guardar sus análisis, '
              'o para tener datos de prueba mientras exploras la app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final patient = _patients[index];
          final count = _analysisCounts[patient.id] ?? 0;
          final color = avatarColorFor(patient.name);
          final initials = patient.name.trim().isNotEmpty
              ? patient.name.trim()[0].toUpperCase()
              : '?';

          return FlatCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                '/history',
                arguments: patient.name,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 0
                              ? 'Sin análisis todavía'
                              : '$count análisis registrado${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (patient.isTestPatient)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mutedInk.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'prueba',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: AppColors.mutedInk.withValues(alpha: 0.7)),
                    onSelected: (value) {
                      if (value == 'delete') _deletePatient(patient);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 20, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Eliminar persona',
                                style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
