import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  final String description;
  final List<double> probabilities;

  ClassificationResult({
    required this.label,
    required this.confidence,
    required this.description,
    required this.probabilities,
  });

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class PostureClassifier {
  static const String _modelPath = 'assets/models/classifier_model.tflite';
  late Interpreter _interpreter;
  bool _isInitialized = false;

  // --- ¡DATOS FINALES! Usando los últimos datos del Scaler de 10 características ---
  static final List<double> SCALER_MEANS = [0.4500264969, 0.2289130788, 0.5047006579, 0.3357790272, 86.6145860539, 86.6564841769, 0.0653664574, 0.1210933462, 0.1235517037, 0.4953928731];
  static final List<double> SCALER_SCALE = [0.1905683511, 0.1146526123, 0.2332062238, 0.2867966640, 20.5922031057, 32.0608291642, 0.0871725412, 0.0831964267, 0.0884731600, 0.1704761973];

  static const List<String> _classLabels = ['Saludable', 'Posible escoliosis'];

  static const Map<String, String> _classDescriptions = {
    'Saludable': 'Postura dentro de parámetros normales. No se detectan asimetrías clínicamente significativas.',
    'Posible escoliosis': 'Se detectan asimetrías que sugieren una posible escoliosis. Se recomienda encarecidamente consultar con un especialista.',
  };

  Future<void> initialize() async {
    try {
      print('🧠 Cargando modelo Especialista v3 (10 feats)...');
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isInitialized = true;
      print('✅ Modelo Especialista v3 cargado.');
    } catch (e) {
      print('❌ Error fatal al cargar el modelo Especialista v3: $e');
      rethrow;
    }
  }

  List<double> _normalizeFeatures(List<double> features) {
    List<double> normalized = [];
    for (int i = 0; i < features.length; i++) {
      normalized.add((features[i] - SCALER_MEANS[i]) / SCALER_SCALE[i]);
    }
    return normalized;
  }

  Future<ClassificationResult> classifyPosture(List<double> features) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (features.length != 10) {
        throw ArgumentError('Se esperaban 10 características, pero se recibieron ${features.length}');
    }

    try {
      final normalizedFeatures = _normalizeFeatures(features);
      var input = [normalizedFeatures];
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

      _interpreter.run(input, output);

      double scoliosisProbability = output[0][0];
      String label = (scoliosisProbability > 0.5) ? _classLabels[1] : _classLabels[0];
      double confidence = (scoliosisProbability > 0.5) ? scoliosisProbability : 1.0 - scoliosisProbability;

      return ClassificationResult(
        label: label,
        confidence: confidence,
        description: _classDescriptions[label] ?? '',
        probabilities: [1.0 - scoliosisProbability, scoliosisProbability],
      );
    } catch (e) {
      print('❌ Error durante la clasificación con IA Especialista v3: $e');
      return ClassificationResult(
        label: 'Error',
        confidence: 0,
        description: 'No se pudo procesar el análisis con el modelo Especialista v3.',
        probabilities: [],
      );
    }
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
      print('🔒 Clasificador de IA liberado.');
    }
  }
}
