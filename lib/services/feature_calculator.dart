import 'dart:math';
import 'pose_detector.dart';

/// Calculadora de características a prueba de fallos para el modelo "Especialista".
class FeatureCalculator {
  // IDs de los puntos clave de MoveNet
  static const int leftShoulder = 5, rightShoulder = 6;
  static const int leftElbow = 7, rightElbow = 8;
  static const int leftWrist = 9, rightWrist = 10;
  static const int leftHip = 11, rightHip = 12;

  static List<double> calculatePostureFeatures(List<PoseLandmark> landmarks) {
    final landmarksMap = {for (var l in landmarks) l.id: l};
    
    // Función auxiliar para obtener un landmark de forma segura
    PoseLandmark? get(int id) => landmarksMap[id];

    // --- CÁLCULO DE LAS 10 CARACTERÍSTICAS (A PRUEBA DE FALLOS) ---
    // Si un punto no se encuentra, se usa un valor por defecto (0,0) que resultará en 0 para la medición.

    final pLS = get(leftShoulder) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pRS = get(rightShoulder) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pLH = get(leftHip) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pRH = get(rightHip) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pLE = get(leftElbow) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pRE = get(rightElbow) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pLW = get(leftWrist) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);
    final pRW = get(rightWrist) ?? PoseLandmark(id: -1, x: 0, y: 0, confidence: 0);

    return [
      (pLS.y - pRS.y).abs(),
      (pLH.y - pRH.y).abs(),
      (pLE.y - pRE.y).abs(),
      (pLW.y - pRW.y).abs(),
      _calculateAngle(pLS, pRS),
      _calculateAngle(pLH, pRH),
      ((pLE.x - ((pLH.x + pRH.x) / 2)).abs() - (pRE.x - ((pLH.x + pRH.x) / 2)).abs()).abs(),
      (_calculateDistance(pLS, pLE) + _calculateDistance(pLE, pLW)) - (_calculateDistance(pRS, pRE) + _calculateDistance(pRE, pRW)).abs(),
      (pLS.x - pRS.x).abs(),
      (pLH.x - pRH.x).abs(),
    ];
  }

  static double _calculateAngle(PoseLandmark p1, PoseLandmark p2) {
    if (p1.confidence == 0 || p2.confidence == 0) return 0.0; // No calcular si el punto es falso
    return atan2(p2.y - p1.y, p2.x - p1.x) * (180 / pi);
  }

  static double _calculateDistance(PoseLandmark p1, PoseLandmark p2) {
    if (p1.confidence == 0 || p2.confidence == 0) return 0.0; // No calcular si el punto es falso
    return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
  }
}
