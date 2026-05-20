import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'encuestas_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla de encuestas pendientes
        await db.execute('''
          CREATE TABLE encuestas_pendientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            visit_id TEXT NOT NULL,
            customer_name TEXT,
            respuestas TEXT NOT NULL,
            lat REAL,
            lng REAL,
            foto1_path TEXT,
            foto2_path TEXT,
            fecha_creacion TEXT NOT NULL,
            sincronizado INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Guarda una encuesta localmente
  Future<int> guardarEncuesta({
    required String visitId,
    String? customerName,
    required String respuestasJson,
    double? lat,
    double? lng,
    String? foto1Path,
    String? foto2Path,
  }) async {
    final db = await database;
    return await db.insert('encuestas_pendientes', {
      'visit_id': visitId,
      'customer_name': customerName,
      'respuestas': respuestasJson,
      'lat': lat,
      'lng': lng,
      'foto1_path': foto1Path,
      'foto2_path': foto2Path,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'sincronizado': 0,
    });
  }

  /// Obtiene todas las encuestas pendientes de sincronizar
  Future<List<Map<String, dynamic>>> getPendientes() async {
    final db = await database;
    return await db.query(
      'encuestas_pendientes',
      where: 'sincronizado = ?',
      whereArgs: [0],
      orderBy: 'fecha_creacion ASC',
    );
  }

  /// Marca una encuesta como sincronizada
  Future<int> marcarSincronizado(int id) async {
    final db = await database;
    return await db.update(
      'encuestas_pendientes',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina una encuesta
  Future<int> eliminarEncuesta(int id) async {
    final db = await database;
    return await db.delete(
      'encuestas_pendientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cuenta encuestas pendientes
  Future<int> contarPendientes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM encuestas_pendientes WHERE sincronizado = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Obtiene todas las encuestas (para debug)
  Future<List<Map<String, dynamic>>> getTodas() async {
    final db = await database;
    return await db.query('encuestas_pendientes', orderBy: 'fecha_creacion DESC');
  }
}