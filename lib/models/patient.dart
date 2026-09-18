/// Modelo de un paciente registrado por un tenant (perfil).
///
/// Existe independientemente de los análisis: permite tener pacientes
/// (reales o de prueba) sin que aún tengan un análisis guardado.
class Patient {
  final int? id;
  final int tenantId;
  final String name;
  final DateTime createdAt;
  final bool isTestPatient;

  Patient({
    this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.isTestPatient = false,
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isTestPatient: (map['is_test_patient'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_test_patient': isTestPatient ? 1 : 0,
    };
  }
}
