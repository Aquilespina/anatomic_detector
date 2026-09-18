import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../models/analysis_record.dart';
import '../models/patient.dart';
import '../providers/tenant_provider.dart';
import '../services/classifier.dart';
import '../services/database_helper.dart';
import '../services/feature_calculator.dart';
import '../services/pose_detector.dart';
import '../theme/app_theme.dart';
import '../widgets/posture_guide_card.dart';

/// Pantalla de captura y análisis postural.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imageFile;
  String _statusMessage = 'Selecciona una imagen para analizar tu postura.';
  bool _isAnalyzing = false;

  final PoseDetector _poseDetector = PoseDetector();
  final PostureClassifier _classifier = PostureClassifier();
  final DatabaseHelper _db = DatabaseHelper();

  ClassificationResult? _classificationResult;
  List<PoseLandmark> _detectedLandmarks = [];

  @override
  void initState() {
    super.initState();
    _poseDetector.initialize();
    _classifier.initialize();
  }

  @override
  void dispose() {
    _poseDetector.dispose();
    _classifier.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _statusMessage = 'Analizando imagen...';
          _isAnalyzing = true;
          _classificationResult = null;
          _detectedLandmarks = [];
        });
        await _analyzeImage(_imageFile!);
      }
    } catch (e) {
      _showError('Error al obtener la imagen: $e');
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        _showError('No se pudo decodificar la imagen.');
        return;
      }

      final landmarks = await _poseDetector.detectPose(image);

      // --- FILTRO INTELIGENTE Y FLEXIBLE ---
      // IDs de MoveNet/COCO (17 puntos): 5,6 son hombros | 11,12 son caderas
      final requiredLandmarkIds = {5, 6, 11, 12};
      final detectedIds = landmarks.map((landmark) => landmark.id).toSet();

      if (!detectedIds.containsAll(requiredLandmarkIds)) {
        setState(() {
          _statusMessage =
              'Análisis fallido: No se pudieron detectar los puntos clave de la espalda (hombros y caderas). Asegúrate de que la espalda esté completamente visible.';
          _isAnalyzing = false;
        });
        return;
      }

      final features = FeatureCalculator.calculatePostureFeatures(landmarks);
      final result = await _classifier.classifyPosture(features);

      setState(() {
        _statusMessage = 'Análisis completado.';
        _classificationResult = result;
        _detectedLandmarks = landmarks;
        _isAnalyzing = false;
      });

      // Guardar automáticamente en el historial
      await _saveToHistory(result, landmarks.length);
    } catch (e) {
      _showError('Ocurrió un error durante el análisis: $e');
    }
  }

  /// Pide el nombre del paciente y dónde guardar el análisis:
  /// - Como persona: además de guardar el análisis, la registra en
  ///   "Personas" para poder darle seguimiento después.
  /// - Solo en historial: guarda el análisis pero NO la registra como
  ///   persona (no aparecerá en la sección "Personas").
  Future<void> _saveToHistory(
      ClassificationResult result, int landmarkCount) async {
    final tenantId = context.read<TenantProvider>().tenantId;
    if (tenantId == null || _imageFile == null) return;

    final controller = TextEditingController();
    final saveAsPerson = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar análisis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del paciente',
                hintText: 'Ej: Juan Pérez',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '"Guardar como persona" la deja disponible en Personas para '
              'seguimiento. "Solo historial" guarda el análisis pero no la '
              'registra como persona.',
              style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No guardar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Solo historial'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar como persona'),
          ),
        ],
      ),
    );

    final patientName = controller.text.trim();
    controller.dispose();

    if (saveAsPerson == null || patientName.isEmpty) return;

    try {
      // Copiar imagen a almacenamiento persistente
      final appDir = await getApplicationDocumentsDirectory();
      final savedDir = Directory('${appDir.path}/analysis_images');
      if (!await savedDir.exists()) {
        await savedDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${savedDir.path}/analysis_$timestamp.jpg';
      await _imageFile!.copy(savedPath);

      // Crear y guardar el registro
      final record = AnalysisRecord(
        tenantId: tenantId,
        patientName: patientName,
        imagePath: savedPath,
        resultLabel: result.label,
        confidence: result.confidence,
        description: result.description,
        landmarksDetected: landmarkCount,
        createdAt: DateTime.now(),
      );

      await _db.insertRecord(record);

      if (saveAsPerson && !await _db.patientExists(tenantId, patientName)) {
        await _db.insertPatient(Patient(
          tenantId: tenantId,
          name: patientName,
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saveAsPerson
                ? 'Guardado como persona: "$patientName" ya está disponible en Personas.'
                : 'Guardado solo en historial: "$patientName" no se registró como persona.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar en historial: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
      _isAnalyzing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _statusMessage = 'Selecciona una imagen para analizar tu postura.';
      _isAnalyzing = false;
      _classificationResult = null;
      _detectedLandmarks = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo análisis'),
        actions: [
          if (_imageFile != null && !_isAnalyzing)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reset,
              tooltip: 'Reiniciar',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PostureGuideCard(),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_imageFile!, fit: BoxFit.contain),
                    )
                  : Center(
                      child: Icon(Icons.image_outlined,
                          size: 50,
                          color: AppColors.mutedInk.withValues(alpha: 0.5)),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isAnalyzing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
            if (_classificationResult != null)
              _buildResultCard(_classificationResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ClassificationResult result) {
    final cardColor = AppColors.forResultLabel(result.label);

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: FlatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppColors.iconForResultLabel(result.label),
                    color: cardColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  result.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
            const Divider(height: 24),
            Text(
              result.description,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Puntos anatómicos detectados: ${_detectedLandmarks.length}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.mutedInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
