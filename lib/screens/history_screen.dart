import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/analysis_record.dart';
import '../providers/tenant_provider.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';

/// Pantalla de historial de análisis posturales.
///
/// Muestra una línea de tiempo con todos los registros del doctor activo.
/// Permite seleccionar 2 registros para comparar, editar y eliminar.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<AnalysisRecord> _records = [];
  bool _isLoading = true;
  String? _patientFilter;

  // Selección para comparación
  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _patientFilter = args;

    setState(() => _isLoading = true);
    var records = await _db.getRecordsByTenant(tenantId);
    if (_patientFilter != null) {
      records =
          records.where((r) => r.patientName == _patientFilter).toList();
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  void _toggleSelection(int recordId) {
    if (_selectedIds.contains(recordId)) {
      setState(() {
        _selectedIds.remove(recordId);
        _isSelectionMode = _selectedIds.isNotEmpty;
      });
      return;
    }

    if (_selectedIds.length >= 2) return;

    // Solo se puede comparar el seguimiento de la MISMA persona: no tiene
    // sentido comparar el análisis de María contra el de Ana.
    if (_selectedIds.isNotEmpty) {
      final firstRecord =
          _records.firstWhere((r) => r.id == _selectedIds.first);
      final candidate = _records.firstWhere((r) => r.id == recordId);
      if (firstRecord.patientName != candidate.patientName) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solo puedes comparar análisis de la misma persona '
              '(ya seleccionaste uno de "${firstRecord.patientName}").',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    setState(() {
      _selectedIds.add(recordId);
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _navigateToComparison() {
    if (_selectedIds.length != 2) return;

    final ids = _selectedIds.toList();
    final record1 = _records.firstWhere((r) => r.id == ids[0]);
    final record2 = _records.firstWhere((r) => r.id == ids[1]);

    // Ordenar por fecha: el más antiguo primero
    final sorted = [record1, record2]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    Navigator.pushNamed(
      context,
      '/comparison',
      arguments: sorted,
    );

    _clearSelection();
  }

  Future<void> _deleteRecord(AnalysisRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          '¿Eliminar el análisis de "${record.patientName}" '
          'del ${DateFormat('dd/MM/yyyy').format(record.createdAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && record.id != null) {
      await _db.deleteRecord(record.id!);

      // Eliminar imagen guardada
      final file = File(record.imagePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro eliminado')),
        );
      }
    }
  }

  Future<void> _editPatientName(AnalysisRecord record) async {
    final controller = TextEditingController(text: record.patientName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre del paciente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del paciente',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != record.patientName) {
      final updated = record.copyWith(patientName: newName);
      await _db.updateRecord(updated);
      await _loadRecords();
    }

    controller.dispose();
  }

  Color _colorForLabel(String label) => AppColors.forResultLabel(label);

  IconData _iconForLabel(String label) => AppColors.iconForResultLabel(label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? '${_selectedIds.length} seleccionados'
            : (_patientFilter ?? 'Historial de análisis')),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: 'Cancelar selección',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordsList(),

      // FAB para comparar cuando hay 2 seleccionados
      floatingActionButton: _selectedIds.length == 2
          ? FloatingActionButton.extended(
              onPressed: _navigateToComparison,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Comparar'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Sin análisis registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los análisis posturales aparecerán aquí\npara seguimiento y comparación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return Column(
      children: [
        // Tip de selección
        if (!_isSelectionMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Mantén presionado para seleccionar y comparar',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

        // Lista de registros
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecords,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _records.length,
              itemBuilder: (context, index) =>
                  _buildRecordCard(_records[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(AnalysisRecord record) {
    final isSelected = _selectedIds.contains(record.id);
    final color = _colorForLabel(record.resultLabel);
    final dateStr = DateFormat('dd MMM yyyy · HH:mm', 'es').format(record.createdAt);

    return GestureDetector(
      onLongPress: () => _toggleSelection(record.id!),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(record.id!);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox de selección o miniatura
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    size: 28,
                  ),
                )
              else
                // Miniatura de la imagen
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: _buildThumbnail(record.imagePath),
                  ),
                ),

              const SizedBox(width: 12),

              // Info del registro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del paciente
                    Text(
                      record.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Resultado con color
                    Row(
                      children: [
                        Icon(_iconForLabel(record.resultLabel),
                            size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          record.resultLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(record.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Fecha
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              // Menú de acciones
              if (!_isSelectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editPatientName(record);
                    if (value == 'delete') _deleteRecord(record);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Editar nombre'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded,
                              size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String path) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
