import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/analysis_record.dart';
import '../models/patient.dart';
import '../models/workspace.dart';

/// Singleton para gestionar la base de datos SQLite local.
///
/// Almacena los registros de análisis posturales y los pacientes,
/// aislados por [tenant_id].
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String _tableName = 'analysis_records';
  static const String _patientsTable = 'patients';
  static const String _workspacesTable = 'workspaces';
  static const int _dbVersion = 4;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'anatomic_detector.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL,
        patient_name TEXT NOT NULL,
        image_path TEXT NOT NULL,
        result_label TEXT NOT NULL,
        confidence REAL NOT NULL,
        description TEXT NOT NULL,
        landmarks_detected INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Índice para consultas rápidas por tenant
    await db.execute(
      'CREATE INDEX idx_tenant ON $_tableName (tenant_id)',
    );

    await _createPatientsTable(db);
    await _createWorkspacesTable(db);
    // Los dos espacios originales, ya usados antes de que existiera esta tabla.
    await db.insert(_workspacesTable, {'id': 1, 'created_at': DateTime.now().toIso8601String()});
    await db.insert(_workspacesTable, {'id': 2, 'created_at': DateTime.now().toIso8601String()});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPatientsTable(db);
    }
    if (oldVersion < 3) {
      // La tabla se crea directamente con la columna `name` (ver abajo),
      // así que no hace falta un ALTER TABLE aparte para oldVersion < 4.
      await _createWorkspacesTable(db);
      // Preservar los espacios 1 y 2 que ya existían implícitamente.
      await db.insert(_workspacesTable, {'id': 1, 'created_at': DateTime.now().toIso8601String()});
      await db.insert(_workspacesTable, {'id': 2, 'created_at': DateTime.now().toIso8601String()});
    } else if (oldVersion < 4) {
      // La tabla ya existía (de la v3) pero sin la columna `name`.
      await db.execute('ALTER TABLE $_workspacesTable ADD COLUMN name TEXT');
    }
  }

  Future<void> _createWorkspacesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_workspacesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        name TEXT
      )
    ''');
  }

  Future<void> _createPatientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_patientsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_test_patient INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_patients_tenant ON $_patientsTable (tenant_id)',
    );
  }

  // ─── CRUD ───────────────────────────────────────────────

  /// Insertar un nuevo registro de análisis.
  Future<int> insertRecord(AnalysisRecord record) async {
    final db = await database;
    return await db.insert(_tableName, record.toMap());
  }

  /// Obtener todos los registros de un doctor, ordenados por fecha descendente.
  Future<List<AnalysisRecord>> getRecordsByTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AnalysisRecord.fromMap(map)).toList();
  }

  /// Actualizar un registro existente (nombre del paciente, notas, etc.).
  Future<int> updateRecord(AnalysisRecord record) async {
    final db = await database;
    return await db.update(
      _tableName,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// Eliminar un registro por ID.
  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Contar registros de un doctor.
  Future<int> countByTenant(int tenantId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE tenant_id = ?',
      [tenantId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─── Pacientes ──────────────────────────────────────────

  /// Registrar un nuevo paciente para un tenant.
  Future<int> insertPatient(Patient patient) async {
    final db = await database;
    return await db.insert(_patientsTable, patient.toMap());
  }

  /// Obtener todos los pacientes de un tenant, más recientes primero.
  Future<List<Patient>> getPatientsByTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query(
      _patientsTable,
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Patient.fromMap(map)).toList();
  }

  /// `true` si ya existe un paciente con ese nombre (sin distinguir mayúsculas).
  Future<bool> patientExists(int tenantId, String name) async {
    final db = await database;
    final result = await db.query(
      _patientsTable,
      where: 'tenant_id = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [tenantId, name],
    );
    return result.isNotEmpty;
  }

  /// Cantidad de análisis guardados para un paciente puntual.
  Future<int> countByPatient(int tenantId, String patientName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE tenant_id = ? AND patient_name = ?',
      [tenantId, patientName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Eliminar un paciente (no elimina sus análisis históricos).
  Future<int> deletePatient(int id) async {
    final db = await database;
    return await db.delete(
      _patientsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Eliminar todo el historial de análisis de una persona puntual, incluidas
  /// sus imágenes guardadas en disco.
  Future<void> deleteRecordsByPatient(int tenantId, String patientName) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'tenant_id = ? AND patient_name = ?',
      whereArgs: [tenantId, patientName],
    );

    for (final map in maps) {
      final imagePath = map['image_path'] as String;
      final file = File(imagePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // No bloquear el borrado del registro por un archivo huérfano.
        }
      }
    }

    await db.delete(
      _tableName,
      where: 'tenant_id = ? AND patient_name = ?',
      whereArgs: [tenantId, patientName],
    );
  }

  // ─── Espacios de trabajo ────────────────────────────────

  /// Todos los espacios de trabajo existentes, en orden de creación.
  Future<List<Workspace>> getWorkspaces() async {
    final db = await database;
    final maps = await db.query(_workspacesTable, orderBy: 'id ASC');
    return maps.map((map) => Workspace.fromMap(map)).toList();
  }

  /// Crea un nuevo espacio de trabajo vacío y retorna su ID.
  Future<int> addWorkspace({String? name}) async {
    final db = await database;
    return await db.insert(_workspacesTable, {
      'created_at': DateTime.now().toIso8601String(),
      'name': (name != null && name.trim().isNotEmpty) ? name.trim() : null,
    });
  }

  /// Cambia el nombre visible de un espacio de trabajo.
  Future<void> renameWorkspace(int id, String? name) async {
    final db = await database;
    await db.update(
      _workspacesTable,
      {'name': (name != null && name.trim().isNotEmpty) ? name.trim() : null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina un espacio de trabajo por completo: sus análisis (con las
  /// imágenes en disco), sus personas, y el espacio mismo. No se puede
  /// deshacer.
  Future<void> deleteWorkspace(int id) async {
    final db = await database;

    final records = await getRecordsByTenant(id);
    for (final record in records) {
      final file = File(record.imagePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // No bloquear el borrado del espacio por un archivo huérfano.
        }
      }
    }

    await db.delete(_tableName, where: 'tenant_id = ?', whereArgs: [id]);
    await db.delete(_patientsTable, where: 'tenant_id = ?', whereArgs: [id]);
    await db.delete(_workspacesTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Copia una persona (y su historial de análisis, con sus imágenes) de un
  /// espacio a otro. Cada espacio queda con su propia copia independiente:
  /// mover un análisis en uno no afecta al otro.
  ///
  /// Si la persona ya tiene historial en el espacio destino, no se vuelve a
  /// copiar (evita duplicar si se repite la importación por error).
  /// Retorna la cantidad de análisis copiados.
  Future<int> copyPatientToTenant({
    required int sourceTenantId,
    required int targetTenantId,
    required String patientName,
  }) async {
    final db = await database;

    if (await countByPatient(targetTenantId, patientName) > 0) {
      return 0;
    }

    if (!await patientExists(targetTenantId, patientName)) {
      final sourcePatientMaps = await db.query(
        _patientsTable,
        where: 'tenant_id = ? AND name = ?',
        whereArgs: [sourceTenantId, patientName],
      );
      final isTest = sourcePatientMaps.isNotEmpty
          ? (sourcePatientMaps.first['is_test_patient'] as int? ?? 0) == 1
          : true;
      await insertPatient(Patient(
        tenantId: targetTenantId,
        name: patientName,
        createdAt: DateTime.now(),
        isTestPatient: isTest,
      ));
    }

    final sourceRecords = await getRecordsByTenant(sourceTenantId);
    final toCopy =
        sourceRecords.where((r) => r.patientName == patientName).toList();
    if (toCopy.isEmpty) return 0;

    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${appDir.path}/analysis_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    var copied = 0;
    for (final record in toCopy) {
      var newImagePath = record.imagePath;
      final sourceFile = File(record.imagePath);
      if (await sourceFile.exists()) {
        final ext = record.imagePath.split('.').last;
        final uniqueSuffix =
            '${DateTime.now().microsecondsSinceEpoch}_$copied';
        newImagePath = '${imgDir.path}/copy_$uniqueSuffix.$ext';
        await sourceFile.copy(newImagePath);
      }

      await insertRecord(AnalysisRecord(
        tenantId: targetTenantId,
        patientName: record.patientName,
        imagePath: newImagePath,
        resultLabel: record.resultLabel,
        confidence: record.confidence,
        description: record.description,
        landmarksDetected: record.landmarksDetected,
        createdAt: record.createdAt,
      ));
      copied++;
    }

    return copied;
  }
}
