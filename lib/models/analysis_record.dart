/// Modelo de datos para un registro de análisis postural.
///
/// Cada registro pertenece a un [tenantId] (doctor) y contiene
/// el resultado del análisis, la ruta de la imagen y el nombre del paciente.
class AnalysisRecord {
  final int? id;
  final int tenantId;
  final String patientName;
  final String imagePath;
  final String resultLabel;
  final double confidence;
  final String description;
  final int landmarksDetected;
  final DateTime createdAt;

  AnalysisRecord({
    this.id,
    required this.tenantId,
    required this.patientName,
    required this.imagePath,
    required this.resultLabel,
    required this.confidence,
    required this.description,
    required this.landmarksDetected,
    required this.createdAt,
  });

  /// Crear un [AnalysisRecord] desde un mapa de la base de datos.
  factory AnalysisRecord.fromMap(Map<String, dynamic> map) {
    return AnalysisRecord(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      patientName: map['patient_name'] as String,
      imagePath: map['image_path'] as String,
      resultLabel: map['result_label'] as String,
      confidence: map['confidence'] as double,
      description: map['description'] as String,
      landmarksDetected: map['landmarks_detected'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convertir a mapa para inserción en la base de datos.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'patient_name': patientName,
      'image_path': imagePath,
      'result_label': resultLabel,
      'confidence': confidence,
      'description': description,
      'landmarks_detected': landmarksDetected,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crear una copia con campos modificados.
  AnalysisRecord copyWith({
    int? id,
    int? tenantId,
    String? patientName,
    String? imagePath,
    String? resultLabel,
    double? confidence,
    String? description,
    int? landmarksDetected,
    DateTime? createdAt,
  }) {
    return AnalysisRecord(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      patientName: patientName ?? this.patientName,
      imagePath: imagePath ?? this.imagePath,
      resultLabel: resultLabel ?? this.resultLabel,
      confidence: confidence ?? this.confidence,
      description: description ?? this.description,
      landmarksDetected: landmarksDetected ?? this.landmarksDetected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
