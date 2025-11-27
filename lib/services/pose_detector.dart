import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PoseLandmark {
  final int id;
  final double x;
  final double y;
  final double confidence;
  final String label;

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
      print('   - Input: ${inputTensors[0].shape}, Tipo: ${inputTensors[0].type}');
      print('   - Output: ${outputTensors[0].shape}');

      _isInitialized = true;
    } catch (e) {
      print('❌ Error inicializando modelo de pose: $e');
      rethrow;
    }
  }

  Future<List<PoseLandmark>> detectPose(img.Image image) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      var input = _preprocessImage(image);
      var output = _runInference(input);
      var landmarks = _processOutput(output, image.width, image.height);

      print('🎯 Puntos detectados: ${landmarks.length}');
      return landmarks;
    } catch (e) {
      print('❌ Error en detección de pose: $e');
      rethrow;
    }
  }

  // --- Corregido: Preprocesamiento a Uint8 ---
  List<List<List<List<int>>>> _preprocessImage(img.Image image) {
    var resizedImage = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
    );

    var input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0))));

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r.toInt();
        input[0][y][x][1] = pixel.g.toInt();
        input[0][y][x][2] = pixel.b.toInt();
      }
    }
    return input;
  }

  // --- Corregido: Tipo de entrada para el modelo ---
  List<dynamic> _runInference(List<List<List<List<int>>>> input) {
    var output = List.filled(1 * 1 * _numKeypoints * 3, 0.0).reshape([1, 1, _numKeypoints, 3]);
    _interpreter.run(input, output);
    return output;
  }

  List<PoseLandmark> _processOutput(
      List<dynamic> output,
      int originalWidth,
      int originalHeight,
      ) {
    List<PoseLandmark> landmarks = [];

    for (int i = 0; i < _numKeypoints; i++) {
      double y = output[0][0][i][0];
      double x = output[0][0][i][1];
      double confidence = output[0][0][i][2];

      if (confidence >= _minConfidence) {
        var landmark = PoseLandmark(
          id: i,
          x: x,
          y: y,
          confidence: confidence,
          label: _getLandmarkLabel(i),
        );
        landmarks.add(landmark);
      }
    }

    return landmarks;
  }


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

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
      print('🔒 Modelo de pose liberado');
    }
  }
}
