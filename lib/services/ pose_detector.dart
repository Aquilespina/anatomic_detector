import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;


class PoseDetector {
  static const String _modelPath = 'assets/models/pose_model.tflite';

  late Interpreter _interpreter;
  bool _isInitialized = false;


  static const int _inputSize = 192;
  static const int _numKeypoints = 17;
  static const double _minConfidence = 0.3;

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();

        _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

          var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();

      print('✅ Modelo de pose cargado:');
      print('   - Input: ${inputTensors[0].shape}');
      print('   - Output: ${outputTensors[0].shape}');

      _isInitialized = true;
    } catch (e) {
      print('❌ Error inicializando modelo de pose: $e');
      rethrow;
    }
  }

  /// Representa un punto anatómico detectado
  class PoseLandmark {
  final int id;
  final double x;        // Coordenada X normalizada (0-1)
  final double y;        // Coordenada Y normalizada (0-1)
  final double confidence; // Confianza de la detección (0-1)
  final String label;    // Etiqueta del punto (opcional)

  PoseLandmark({
  required this.id,
  required this.x,
  required this.y,
  required this.confidence,
  this.label = '',
  });

  @override
  String toString() {
  return 'Landmark$id: ($x, $y) - ${(confidence * 100).toStringAsFixed(1)}%';
  }
  }

  /// Detectar puntos anatómicos en una imagen
  Future<List<PoseLandmark>> detectPose(img.Image image) async {
  if (!_isInitialized) {
  await initialize();
  }

  try {
  // 1. Preprocesar imagen para el modelo
  var input = _preprocessImage(image);

  // 2. Ejecutar inferencia
  var output = _runInference(input);

  // 3. Procesar resultados
  var landmarks = _processOutput(output, image.width, image.height);

  print('🎯 Puntos detectados: ${landmarks.length}');
  return landmarks;

  } catch (e) {
  print('❌ Error en detección de pose: $e');
  rethrow;
  }
  }

  /// Preprocesar imagen para el modelo TFLite
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
  // Redimensionar imagen al tamaño esperado por el modelo
  var resizedImage = img.copyResize(
  image,
  width: _inputSize,
  height: _inputSize
  );

  // Crear tensor de entrada [1, 192, 192, 3]
  var input = List.filled(
  1 * _inputSize * _inputSize * 3,
  0.0
  ).reshape([1, _inputSize, _inputSize, 3]);

  // Convertir imagen a tensor normalizado (0-1)
  for (int y = 0; y < _inputSize; y++) {
  for (int x = 0; x < _inputSize; x++) {
  var pixel = resizedImage.getPixel(x, y);

  // Normalizar canales RGB a [0, 1]
  input[0][y][x][0] = img.getRed(pixel) / 255.0;   // R
  input[0][y][x][1] = img.getGreen(pixel) / 255.0; // G
  input[0][y][x][2] = img.getBlue(pixel) / 255.0;  // B
  }
  }

  return input;
  }

  /// Ejecutar inferencia del modelo
  List<List<double>> _runInference(List<List<List<List<double>>>> input) {
  // Preparar tensor de salida [1, 17, 3]
  var output = List.filled(
  1 * _numKeypoints * 3,
  0.0
  ).reshape([1, _numKeypoints, 3]);

  // Ejecutar modelo
  _interpreter.run(input, output);

  return output;
  }

  /// Procesar salida del modelo y convertir a landmarks
  List<PoseLandmark> _processOutput(
  List<List<double>> output,
  int originalWidth,
  int originalHeight
  ) {
  List<PoseLandmark> landmarks = [];

  for (int i = 0; i < _numKeypoints; i++) {
  double y = output[0][i][0]; // Coordenada Y en espacio del modelo
  double x = output[0][i][1]; // Coordenada X en espacio del modelo
  double confidence = output[0][i][2]; // Confianza

  // Filtrar por confianza mínima
  if (confidence >= _minConfidence) {
  // Convertir coordenadas al espacio original de la imagen
  double originalX = (x / _inputSize) * originalWidth;
  double originalY = (y / _inputSize) * originalHeight;

  // Normalizar coordenadas (0-1)
  double normalizedX = originalX / originalWidth;
  double normalizedY = originalY / originalHeight;

  var landmark = PoseLandmark(
  id: i,
  x: normalizedX,
  y: normalizedY,
  confidence: confidence,
  label: _getLandmarkLabel(i),
  );

  landmarks.add(landmark);
  }
  }

  return landmarks;
  }

  /// Obtener etiqueta descriptiva para cada punto
  String _getLandmarkLabel(int id) {
  const labels = {
  0: 'Nariz',
  1: 'Ojo izquierdo',
  2: 'Ojo derecho',
  3: 'Oreja izquierda',
  4: 'Oreja derecha',
  5: 'Hombro izquierdo',
  6: 'Hombro derecho',
  7: 'Codo izquierdo',
  8: 'Codo derecho',
  9: 'Muñeca izquierda',
  10: 'Muñeca derecha',
  11: 'Cadera izquierda',
  12: 'Cadera derecha',
  13: 'Rodilla izquierda',
  14: 'Rodilla derecha',
  15: 'Tobillo izquierdo',
  16: 'Tobillo derecho',
  };

  return labels[id] ?? 'Punto $id';
  }

  /// Calcular métricas de postura a partir de los landmarks
  Map<String, double> calculatePostureMetrics(List<PoseLandmark> landmarks) {
  var metrics = <String, double>{};

  try {
  // 1. Asimetría de hombros
  if (_hasLandmarks(landmarks, [5, 6])) {
  var leftShoulder = landmarks.firstWhere((l) => l.id == 5);
  var rightShoulder = landmarks.firstWhere((l) => l.id == 6);
  metrics['shoulder_asymmetry'] = (leftShoulder.y - rightShoulder.y).abs();
  }

  // 2. Asimetría de caderas
  if (_hasLandmarks(landmarks, [11, 12])) {
  var leftHip = landmarks.firstWhere((l) => l.id == 11);
  var rightHip = landmarks.firstWhere((l) => l.id == 12);
  metrics['hip_asymmetry'] = (leftHip.y - rightHip.y).abs();
  }

  // 3. Inclinación de hombros
  if (_hasLandmarks(landmarks, [5, 6])) {
  var leftShoulder = landmarks.firstWhere((l) => l.id == 5);
  var rightShoulder = landmarks.firstWhere((l) => l.id == 6);
  metrics['shoulder_tilt'] = _calculateAngle(
  leftShoulder.x, leftShoulder.y,
  rightShoulder.x, rightShoulder.y
  );
  }

  // 4. Distancia entre hombros normalizada
  if (_hasLandmarks(landmarks, [5, 6])) {
  var leftShoulder = landmarks.firstWhere((l) => l.id == 5);
  var rightShoulder = landmarks.firstWhere((l) => l.id == 6);
  var distance = _calculateDistance(
  leftShoulder.x, leftShoulder.y,
  rightShoulder.x, rightShoulder.y
  );
  metrics['shoulder_distance'] = distance;
  }

  } catch (e) {
  print('⚠️ Error calculando métricas: $e');
  }

  return metrics;
  }

  /// Verificar si existen los landmarks requeridos
  bool _hasLandmarks(List<PoseLandmark> landmarks, List<int> requiredIds) {
  return requiredIds.every((id) =>
  landmarks.any((landmark) => landmark.id == id)
  );
  }

  /// Calcular distancia euclidiana entre dos puntos
  double _calculateDistance(double x1, double y1, double x2, double y2) {
  return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
  }

  /// Calcular ángulo entre dos puntos (en grados)
  double _calculateAngle(double x1, double y1, double x2, double y2) {
  var dx = x2 - x1;
  var dy = y2 - y1;
  var angle = Math.atan2(dy, dx) * (180 / Math.pi);
  return angle.abs();
  }

  /// Obtener información del modelo
  Map<String, dynamic> getModelInfo() {
  if (!_isInitialized) {
  return {'error': 'Modelo no inicializado'};
  }

  var inputTensor = _interpreter.getInputTensors()[0];
  var outputTensor = _interpreter.getOutputTensors()[0];

  return {
  'input_shape': inputTensor.shape,
  'output_shape': outputTensor.shape,
  'input_size': _inputSize,
  'num_keypoints': _numKeypoints,
  };
  }

  /// Liberar recursos del modelo
  void dispose() {
  if (_isInitialized) {
  _interpreter.close();
  _isInitialized = false;
  print('🔒 Modelo de pose liberado');
  }
  }
}

// Helper para operaciones matemáticas
class Math {
  static double sqrt(double x) => x < 0 ? 0 : _sqrt(x);
  static double _sqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double pow(double x, double exponent) {
    if (exponent == 0) return 1;
    if (exponent == 1) return x;
    return x * pow(x, exponent - 1);
  }

  static double atan2(double y, double x) {
    if (x > 0) return atan(y / x);
    if (x < 0 && y >= 0) return atan(y / x) + pi;
    if (x < 0 && y < 0) return atan(y / x) - pi;
    if (x == 0 && y > 0) return pi / 2;
    if (x == 0 && y < 0) return -pi / 2;
    return 0; // Indefinido
  }

  static double atan(double x) {
    // Aproximación de arctan
    if (x.abs() > 1) return (pi / 2) - atan(1 / x);
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }

  static const double pi = 3.141592653589793;
}