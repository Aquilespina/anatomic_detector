/// Modelo de un espacio de trabajo (antes "doctor").
///
/// Cada espacio aísla sus propias personas y análisis. Puede tener un
/// nombre personalizado; si no, se muestra como "Espacio {id}".
class Workspace {
  final int id;
  final String? name;
  final DateTime createdAt;

  Workspace({
    required this.id,
    this.name,
    required this.createdAt,
  });

  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'Espacio $id';
  }

  factory Workspace.fromMap(Map<String, dynamic> map) {
    return Workspace(
      id: map['id'] as int,
      name: map['name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
