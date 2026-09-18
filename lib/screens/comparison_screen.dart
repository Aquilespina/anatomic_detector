import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analysis_record.dart';
import '../theme/app_theme.dart';

/// Pantalla de comparación lado a lado de dos análisis posturales.
///
/// Recibe una lista de 2 [AnalysisRecord] ordenados por fecha (antiguo primero).
/// Muestra las imágenes, resultados y un indicador de progresión.
class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records =
        ModalRoute.of(context)!.settings.arguments as List<AnalysisRecord>;
    final older = records[0];
    final newer = records[1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparación'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Indicador de progresión
            _buildProgressionBanner(older, newer),

            const SizedBox(height: 16),

            // Comparación lado a lado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registro anterior
                  Expanded(child: _buildAnalysisCard(context, older, 'Antes')),
                  const SizedBox(width: 12),
                  // Registro reciente
                  Expanded(child: _buildAnalysisCard(context, newer, 'Después')),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Detalle de la comparación
            _buildDetailComparison(context, older, newer),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionBanner(AnalysisRecord older, AnalysisRecord newer) {
    final progression = _calculateProgression(older, newer);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      color: progression.color.withValues(alpha: 0.08),
      child: Column(
        children: [
          Icon(progression.icon, size: 40, color: progression.color),
          const SizedBox(height: 8),
          Text(
            progression.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: progression.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progression.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedInk,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            newer.patientName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
      BuildContext context, AnalysisRecord record, String label) {
    final color = _colorForLabel(record.resultLabel);
    final dateStr = DateFormat('dd/MM/yyyy', 'es').format(record.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Etiqueta "Antes" / "Después"
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),

          // Imagen
          ClipRRect(
            child: SizedBox(
              height: 180,
              child: _buildImage(record.imagePath),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  record.resultLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(record.confidence * 100).toStringAsFixed(0)}% confianza',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailComparison(
      BuildContext context, AnalysisRecord older, AnalysisRecord newer) {
    final daysDiff = newer.createdAt.difference(older.createdAt).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalle de la comparación',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const Divider(height: 24),
          _buildComparisonRow(
              'Tiempo entre análisis', '$daysDiff días'),
          _buildComparisonRow(
              'Resultado anterior', older.resultLabel),
          _buildComparisonRow(
              'Resultado actual', newer.resultLabel),
          _buildComparisonRow(
              'Confianza anterior',
              '${(older.confidence * 100).toStringAsFixed(1)}%'),
          _buildComparisonRow(
              'Confianza actual',
              '${(newer.confidence * 100).toStringAsFixed(1)}%'),
          _buildComparisonRow(
              'Puntos detectados (ant.)',
              '${older.landmarksDetected}'),
          _buildComparisonRow(
              'Puntos detectados (act.)',
              '${newer.landmarksDetected}'),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  Color _colorForLabel(String label) => AppColors.forResultLabel(label);

  /// Qué tan hacia el lado "escoliosis" apunta un análisis, en una escala
  /// continua de -1 (muy confiado en "Saludable") a +1 (muy confiado en
  /// "Posible escoliosis"). Así, dos análisis con la misma etiqueta pero
  /// confianza muy distinta ya no se leen como "sin cambio".
  double _severityScore(AnalysisRecord record) {
    switch (record.resultLabel) {
      case 'Saludable':
        return -record.confidence;
      case 'Posible escoliosis':
        return record.confidence;
      default:
        // 'Indeterminado': no hay lectura clara hacia ningún lado.
        return 0.0;
    }
  }

  _Progression _calculateProgression(
      AnalysisRecord older, AnalysisRecord newer) {
    // Un 'Error' es un fallo técnico del análisis, no un resultado clínico:
    // no tiene sentido calcular progreso contra eso.
    if (older.resultLabel == 'Error' || newer.resultLabel == 'Error') {
      return _Progression(
        label: 'No se puede comparar',
        description: 'Uno de los dos análisis no se pudo procesar '
            'correctamente, así que no hay una lectura confiable para '
            'calcular el progreso.',
        icon: Icons.error_outline_rounded,
        color: AppColors.technicalError,
      );
    }

    final oldScore = _severityScore(older);
    final newScore = _severityScore(newer);
    const changeThreshold = 0.08;

    if ((newScore - oldScore).abs() < changeThreshold) {
      return _Progression(
        label: 'Sin cambio',
        description: 'El resultado se mantiene similar respecto al análisis anterior.',
        icon: Icons.trending_flat_rounded,
        color: AppColors.mutedInk,
      );
    } else if (newScore < oldScore) {
      return _Progression(
        label: 'Mejoró',
        description: 'El resultado muestra progreso positivo respecto al análisis anterior.',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      );
    } else {
      return _Progression(
        label: 'Empeoró',
        description: 'El resultado muestra un cambio negativo. Se recomienda consulta especializada.',
        icon: Icons.trending_down_rounded,
        color: AppColors.warning,
      );
    }
  }
}

class _Progression {
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  _Progression({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}
