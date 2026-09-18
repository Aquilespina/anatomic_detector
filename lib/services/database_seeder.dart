import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/analysis_record.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'database_helper.dart';

/// Genera datos de demostración para probar el historial y comparación.
///
/// Crea registros de ejemplo con una imagen de referencia (ilustración
/// minimalista de espalda + columna) en vez de fotos reales.
class DatabaseSeeder {
  final DatabaseHelper _db = DatabaseHelper();

  static const List<String> _resultLabels = [
    'Saludable',
    'Posible escoliosis',
    'Indeterminado',
  ];

  /// Los registros demo que se insertarán para el doctor indicado.
  List<_DemoRecord> _demoRecords(int tenantId) {
    return [
      _DemoRecord(
        tenantId: tenantId,
        patientName: 'María García',
        resultLabel: 'Posible escoliosis',
        confidence: 0.82,
        description:
            'Se detectó una desviación lateral en la columna. Se recomienda consulta con especialista.',
        landmarksDetected: 17,
        daysAgo: 60,
        label: 'Análisis inicial',
      ),
      _DemoRecord(
        tenantId: tenantId,
        patientName: 'María García',
        resultLabel: 'Posible escoliosis',
        confidence: 0.71,
        description:
            'Se detectó una desviación lateral en la columna. Ligera mejora respecto a medición anterior.',
        landmarksDetected: 19,
        daysAgo: 30,
        label: 'Seguimiento · 1 mes',
      ),
      _DemoRecord(
        tenantId: tenantId,
        patientName: 'María García',
        resultLabel: 'Saludable',
        confidence: 0.68,
        description:
            'Postura dentro de parámetros normales. Continuar con ejercicios de fortalecimiento.',
        landmarksDetected: 20,
        daysAgo: 7,
        label: 'Seguimiento · 2 meses',
      ),
      _DemoRecord(
        tenantId: tenantId,
        patientName: 'Carlos López',
        resultLabel: 'Saludable',
        confidence: 0.91,
        description: 'Postura saludable. Sin indicios de escoliosis.',
        landmarksDetected: 21,
        daysAgo: 45,
        label: 'Evaluación única',
      ),
      _DemoRecord(
        tenantId: tenantId,
        patientName: 'Ana Rodríguez',
        resultLabel: 'Posible escoliosis',
        confidence: 0.76,
        description:
            'Se observa asimetría en hombros. Derivar a evaluación especializada.',
        landmarksDetected: 18,
        daysAgo: 14,
        label: 'Primera consulta',
      ),
    ];
  }

  /// Verifica si ya se cargaron datos demo para este doctor.
  Future<bool> hasSeededData(int tenantId) async {
    final count = await _db.countByTenant(tenantId);
    return count > 0;
  }

  /// Carga los datos demo para el doctor indicado, incluyendo el registro
  /// de cada paciente de ejemplo en la tabla de pacientes.
  /// Retorna la cantidad de análisis insertados.
  Future<int> seed(int tenantId) async {
    final demos = _demoRecords(tenantId);
    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${appDir.path}/analysis_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    final seenPatients = <String>{};
    int inserted = 0;
    for (final demo in demos) {
      final now = DateTime.now();
      final createdAt = now.subtract(Duration(days: demo.daysAgo));
      final timestamp = createdAt.millisecondsSinceEpoch;
      final imagePath = '${imgDir.path}/demo_$timestamp.png';
      final color = AppColors.forResultLabel(demo.resultLabel);

      await _generateReferenceImage(
        imagePath,
        color,
        demo.resultLabel,
        demo.label,
      );

      final record = AnalysisRecord(
        tenantId: demo.tenantId,
        patientName: demo.patientName,
        imagePath: imagePath,
        resultLabel: demo.resultLabel,
        confidence: demo.confidence,
        description: demo.description,
        landmarksDetected: demo.landmarksDetected,
        createdAt: createdAt,
      );

      await _db.insertRecord(record);
      inserted++;

      if (seenPatients.add(demo.patientName)) {
        if (!await _db.patientExists(tenantId, demo.patientName)) {
          await _db.insertPatient(Patient(
            tenantId: tenantId,
            name: demo.patientName,
            createdAt: createdAt,
            isTestPatient: true,
          ));
        }
      }
    }

    return inserted;
  }

  /// Crea un único paciente de prueba con un análisis de ejemplo, para que
  /// el usuario pueda agregar más "personas" al set de datos de prueba
  /// (p. ej. "Pedro") sin tener que tomar una foto real.
  Future<void> seedForPatient(int tenantId, String patientName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${appDir.path}/analysis_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    final random = Random();
    final resultLabel = _resultLabels[random.nextInt(_resultLabels.length)];
    final confidence = 0.65 + random.nextDouble() * 0.3;
    final color = AppColors.forResultLabel(resultLabel);

    final createdAt = DateTime.now();
    final timestamp = createdAt.millisecondsSinceEpoch;
    final imagePath = '${imgDir.path}/demo_$timestamp.png';

    await _generateReferenceImage(
      imagePath,
      color,
      resultLabel,
      'Registro de prueba',
    );

    final record = AnalysisRecord(
      tenantId: tenantId,
      patientName: patientName,
      imagePath: imagePath,
      resultLabel: resultLabel,
      confidence: confidence,
      description: 'Registro de ejemplo generado para pruebas de la app.',
      landmarksDetected: 17 + random.nextInt(5),
      createdAt: createdAt,
    );

    await _db.insertRecord(record);
  }

  /// Genera una ilustración de referencia minimalista: silueta de espalda
  /// con la curva de columna resaltada, en el color del resultado.
  Future<void> _generateReferenceImage(
    String path,
    Color color,
    String resultLabel,
    String caption,
  ) async {
    final recorder = ui.PictureRecorder();
    const width = 400.0;
    const height = 480.0;
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width, height),
    );

    // Fondo plano.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF6F7F5),
    );

    // Silueta de torso (línea limpia, sin relleno saturado).
    final torsoPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final torsoOutline = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final headCenter = const Offset(width / 2, 110);
    canvas.drawCircle(headCenter, 34, torsoPaint);
    canvas.drawCircle(headCenter, 34, torsoOutline);

    final shoulderY = 160.0;
    final hipY = 340.0;
    final torsoPath = Path()
      ..moveTo(width / 2 - 70, shoulderY)
      ..lineTo(width / 2 + 70, shoulderY)
      ..quadraticBezierTo(width / 2 + 85, (shoulderY + hipY) / 2,
          width / 2 + 50, hipY)
      ..lineTo(width / 2 - 50, hipY)
      ..quadraticBezierTo(
          width / 2 - 85, (shoulderY + hipY) / 2, width / 2 - 70, shoulderY)
      ..close();
    canvas.drawPath(torsoPath, torsoPaint);
    canvas.drawPath(torsoPath, torsoOutline);

    // Guías horizontales de hombros/caderas (referencia de alineación).
    final guidePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(width / 2 - 100, shoulderY),
        Offset(width / 2 + 100, shoulderY), guidePaint);
    canvas.drawLine(
        Offset(width / 2 - 100, hipY), Offset(width / 2 + 100, hipY), guidePaint);

    // Curva de columna: recta si "Saludable", con desviación si no.
    final spinePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final spinePath = Path()..moveTo(width / 2, shoulderY + 6);
    if (resultLabel == 'Saludable') {
      spinePath.lineTo(width / 2, hipY - 6);
    } else {
      final drift = resultLabel == 'Posible escoliosis' ? 22.0 : 12.0;
      spinePath.quadraticBezierTo(
          width / 2 + drift, (shoulderY + hipY) / 2, width / 2, hipY - 6);
    }
    canvas.drawPath(spinePath, spinePaint);

    // Vértebras (puntos) sobre la curva, look "landmarks" sin ser clínico.
    final dotPaint = Paint()..color = color;
    for (int i = 0; i <= 8; i++) {
      final t = i / 8;
      final pos = _quadPointOnPath(
        Offset(width / 2, shoulderY + 6),
        resultLabel == 'Saludable'
            ? Offset(width / 2, hipY - 6)
            : Offset(width / 2 + (resultLabel == 'Posible escoliosis' ? 22 : 12),
                (shoulderY + hipY) / 2),
        Offset(width / 2, hipY - 6),
        t,
      );
      canvas.drawCircle(pos, 3, dotPaint);
    }

    // Etiqueta de resultado.
    final resultParagraph = _buildParagraph(
      resultLabel,
      18,
      color,
      FontWeight.w600,
      width - 40,
    );
    canvas.drawParagraph(resultParagraph, const Offset(20, 388));

    // Caption secundario.
    final captionParagraph = _buildParagraph(
      caption,
      13,
      Colors.grey.shade600,
      FontWeight.w400,
      width - 40,
    );
    canvas.drawParagraph(captionParagraph, const Offset(20, 416));

    // Marca de "referencia" (no es una foto real del paciente).
    final refParagraph = _buildParagraph(
      'IMAGEN DE REFERENCIA · DATOS DE PRUEBA',
      10,
      Colors.grey.shade400,
      FontWeight.w500,
      width - 40,
    );
    canvas.drawParagraph(refParagraph, const Offset(20, 448));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
  }

  /// Punto sobre una curva cuadrática de Bézier en el parámetro [t].
  Offset _quadPointOnPath(Offset p0, Offset control, Offset p1, double t) {
    final x = (1 - t) * (1 - t) * p0.dx +
        2 * (1 - t) * t * control.dx +
        t * t * p1.dx;
    final y = (1 - t) * (1 - t) * p0.dy +
        2 * (1 - t) * t * control.dy +
        t * t * p1.dy;
    return Offset(x, y);
  }

  ui.Paragraph _buildParagraph(
    String text,
    double fontSize,
    Color color,
    FontWeight weight,
    double maxWidth,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }
}

class _DemoRecord {
  final int tenantId;
  final String patientName;
  final String resultLabel;
  final double confidence;
  final String description;
  final int landmarksDetected;
  final int daysAgo;
  final String label;

  _DemoRecord({
    required this.tenantId,
    required this.patientName,
    required this.resultLabel,
    required this.confidence,
    required this.description,
    required this.landmarksDetected,
    required this.daysAgo,
    required this.label,
  });
}
