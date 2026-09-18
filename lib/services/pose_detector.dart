import 'dart:math' as math;
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

  /// Si la imagen (ya sin marco) es más chica que esto de lado mayor, se
  /// agranda antes de analizar para no perder puntos por falta de detalle.
  static const int _minUsableDimension = 256;

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
      final trimmed = _trimLightBorder(image);
      final resized = _ensureMinimumSize(trimmed);
      final letterbox = _letterboxResize(resized, _inputSize);

      var input = _imageToInputTensor(letterbox.image);
      var output = _runInference(input);
      var landmarks = _processOutput(output, letterbox);

      print('🎯 Puntos detectados: ${landmarks.length}');
      return landmarks;
    } catch (e) {
      print('❌ Error en detección de pose: $e');
      rethrow;
    }
  }

  /// Recorta un marco claro y uniforme (borde blanco de foto, mate, etc.)
  /// alrededor de la imagen. Si no encuentra uno, o el recorte sería
  /// demasiado agresivo (probablemente una foto genuinamente muy clara,
  /// no un marco), devuelve la imagen sin tocar.
  img.Image _trimLightBorder(img.Image image) {
    const int borderBrightness = 235; // 0-255: qué tan claro cuenta como "marco"
    const int borderTolerance = 12; // variación máxima entre canales R/G/B
    const double maxTrimFraction = 0.35; // nunca recortar más de esto por lado
    const int rowColSamples = 12;

    bool isBorderPixel(int x, int y) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final minC = math.min(r, math.min(g, b));
      final maxC = math.max(r, math.max(g, b));
      return minC >= borderBrightness - borderTolerance &&
          (maxC - minC) <= borderTolerance;
    }

    bool isBorderRow(int y) {
      final step = (image.width ~/ rowColSamples).clamp(1, image.width);
      var borderCount = 0, total = 0;
      for (int x = 0; x < image.width; x += step) {
        total++;
        if (isBorderPixel(x, y)) borderCount++;
      }
      return total > 0 && borderCount / total > 0.9;
    }

    bool isBorderColumn(int x) {
      final step = (image.height ~/ rowColSamples).clamp(1, image.height);
      var borderCount = 0, total = 0;
      for (int y = 0; y < image.height; y += step) {
        total++;
        if (isBorderPixel(x, y)) borderCount++;
      }
      return total > 0 && borderCount / total > 0.9;
    }

    final maxTrimY = (image.height * maxTrimFraction).round();
    final maxTrimX = (image.width * maxTrimFraction).round();

    int top = 0;
    while (top < maxTrimY && isBorderRow(top)) {
      top++;
    }

    int bottom = image.height - 1;
    final minBottom = math.max(top, image.height - 1 - maxTrimY);
    while (bottom > minBottom && isBorderRow(bottom)) {
      bottom--;
    }

    int left = 0;
    while (left < maxTrimX && isBorderColumn(left)) {
      left++;
    }

    int right = image.width - 1;
    final minRight = math.max(left, image.width - 1 - maxTrimX);
    while (right > minRight && isBorderColumn(right)) {
      right--;
    }

    final noBorderFound =
        top == 0 && bottom == image.height - 1 && left == 0 && right == image.width - 1;
    if (noBorderFound) return image;

    final trimmedWidth = right - left + 1;
    final trimmedHeight = bottom - top + 1;
    final tooAggressive =
        trimmedWidth < image.width * 0.5 || trimmedHeight < image.height * 0.5;
    if (tooAggressive) return image;

    return img.copyCrop(image, x: left, y: top, width: trimmedWidth, height: trimmedHeight);
  }

  /// Agranda la imagen si su lado mayor es más chico que [_minUsableDimension],
  /// para no perder puntos clave por falta de detalle en fotos pequeñas.
  img.Image _ensureMinimumSize(img.Image image) {
    final maxDim = math.max(image.width, image.height);
    if (maxDim >= _minUsableDimension) return image;

    final scale = _minUsableDimension / maxDim;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Redimensiona manteniendo la proporción original (sin estirar el
  /// cuerpo) y rellena el resto del cuadro cuadrado que espera el modelo
  /// con gris neutro, centrado. Guarda la escala/offset usados para poder
  /// des-normalizar los puntos detectados de vuelta a la imagen real.
  _LetterboxInfo _letterboxResize(img.Image image, int targetSize) {
    final scale = math.min(targetSize / image.width, targetSize / image.height);
    final scaledWidth = (image.width * scale).round().clamp(1, targetSize);
    final scaledHeight = (image.height * scale).round().clamp(1, targetSize);

    final scaledImage = img.copyResize(image, width: scaledWidth, height: scaledHeight);

    final canvas = img.Image(width: targetSize, height: targetSize);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    final offsetX = (targetSize - scaledWidth) ~/ 2;
    final offsetY = (targetSize - scaledHeight) ~/ 2;
    img.compositeImage(canvas, scaledImage, dstX: offsetX, dstY: offsetY);

    return _LetterboxInfo(
      image: canvas,
      offsetX: offsetX,
      offsetY: offsetY,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
    );
  }

  List<List<List<List<int>>>> _imageToInputTensor(img.Image letterboxedImage) {
    var input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0))));

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        var pixel = letterboxedImage.getPixel(x, y);
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
      _LetterboxInfo letterbox,
      ) {
    List<PoseLandmark> landmarks = [];

    for (int i = 0; i < _numKeypoints; i++) {
      double rawY = output[0][0][i][0];
      double rawX = output[0][0][i][1];
      double confidence = output[0][0][i][2];

      if (confidence >= _minConfidence) {
        // El modelo devuelve coordenadas normalizadas relativas al cuadro
        // 192x192 CON el relleno gris incluido. Se "des-normalizan" para
        // que queden relativas solo al contenido real de la foto.
        final x = ((rawX * _inputSize - letterbox.offsetX) / letterbox.scaledWidth)
            .clamp(0.0, 1.0);
        final y = ((rawY * _inputSize - letterbox.offsetY) / letterbox.scaledHeight)
            .clamp(0.0, 1.0);

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

/// Metadata del letterbox (escala + relleno) necesaria para mapear los
/// puntos que devuelve el modelo de vuelta a la imagen real, sin el
/// relleno gris.
class _LetterboxInfo {
  final img.Image image;
  final int offsetX;
  final int offsetY;
  final int scaledWidth;
  final int scaledHeight;

  _LetterboxInfo({
    required this.image,
    required this.offsetX,
    required this.offsetY,
    required this.scaledWidth,
    required this.scaledHeight,
  });
}
