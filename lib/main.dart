import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

// Importar los servicios de IA REALES
import 'services/pose_detector.dart';
import 'services/feature_calculator.dart';
import 'services/classifier.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anatomic AI: Detector Postural',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
    print("--- INICIANDO ANÁLISIS CON MODELO ESPECIALISTA v3 ---");

    try {
      final imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        _showError('No se pudo decodificar la imagen.');
        return;
      }

      final landmarks = await _poseDetector.detectPose(image);

      // --- FILTRO INTELIGENTE Y FLEXIBLE ---
      // Solo exigimos los 4 puntos más críticos para el diagnóstico de espalda.
      final requiredLandmarkIds = {5, 6, 11, 12}; // Hombros y Caderas
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
    } catch (e) {
      _showError('Ocurrió un error durante el análisis: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
      _isAnalyzing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        // --- TÍTULO CORREGIDO ---
        title: const Text('Anatomic AI: Detector Postural'),
        actions: [
          if (_imageFile != null && !_isAnalyzing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Reiniciar',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50),
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.contain)
                  : const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
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
              )),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_classificationResult != null)
              _buildResultCard(_classificationResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ClassificationResult result) {
    Color cardColor = Colors.grey;
    if (result.label == 'Saludable') cardColor = Colors.green;
    if (result.label == 'Posible escoliosis') cardColor = Colors.orange;
    if (result.label == 'Indeterminado') cardColor = Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.label.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            Text(
              result.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Puntos anatómicos detectados: ${_detectedLandmarks.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
