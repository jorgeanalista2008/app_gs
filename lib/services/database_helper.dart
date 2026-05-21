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
    final path = join(dbPath, 'solsumed_offline.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS usuarios');
          await db.execute('DROP TABLE IF EXISTS encuestas');
          await db.execute('DROP TABLE IF EXISTS preguntas');
          await db.execute('DROP TABLE IF EXISTS clientes');
          await db.execute('DROP TABLE IF EXISTS visitas');
          await db.execute('DROP TABLE IF EXISTS encuestas_visita');
          await db.execute('DROP TABLE IF EXISTS respuestas_pendientes');
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {


      // Tabla de usuarios
  await db.execute('''
    CREATE TABLE IF NOT EXISTS usuarios (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      full_name TEXT,
      role TEXT DEFAULT 'vendedor',
      activo INTEGER DEFAULT 1,
      fecha_creacion TEXT
    )
  ''');

  // Tabla de encuestas (plantillas)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS encuestas (
      id TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      descripcion TEXT,
      created_by TEXT,
      fecha_creacion TEXT
    )
  ''');

  // Tabla de preguntas
  await db.execute('''
    CREATE TABLE IF NOT EXISTS preguntas (
      id TEXT PRIMARY KEY,
      encuesta_id TEXT NOT NULL,
      descripcion TEXT NOT NULL,
      tipo TEXT NOT NULL,
      es_requerida INTEGER DEFAULT 0,
      opciones TEXT,
      orden INTEGER DEFAULT 0,
      FOREIGN KEY (encuesta_id) REFERENCES encuestas(id)
    )
  ''');
    // Tabla de clientes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code_client_profit TEXT,
        tax_id TEXT,
        telefono TEXT,
        email TEXT,
        direccion TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_sync TEXT
      )
    ''');

    // Tabla de visitas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS visitas (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        customer_name TEXT,
        address TEXT,
        city TEXT,
        code_client_profit TEXT,
        tax_id TEXT,
        visit_date_from TEXT,
        visit_date_to TEXT,
        notes TEXT,
        priority INTEGER DEFAULT 1,
        status TEXT DEFAULT 'PENDING',
        completed_at TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_sync TEXT
      )
    ''');

    // Tabla de encuestas/preguntas de visita
    await db.execute('''
      CREATE TABLE IF NOT EXISTS encuestas_visita (
        id TEXT PRIMARY KEY,
        visit_id TEXT NOT NULL,
        salesperson_id TEXT,
        customer_id TEXT,
        questions_json TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_sync TEXT
      )
    ''');

    // Tabla de respuestas pendientes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS respuestas_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_id TEXT NOT NULL,
        customer_name TEXT,
        respuestas_json TEXT NOT NULL,
        lat REAL,
        lng REAL,
        foto1_path TEXT,
        foto2_path TEXT,
        fecha_creacion TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');
  }

  // ═══════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════

  Future<void> guardarClientes(List<Map<String, dynamic>> clientes) async {
    final db = await database;
    final batch = db.batch();
    for (var cliente in clientes) {
      batch.insert('clientes', {
        'id': cliente['id'],
        'name': cliente['name'],
        'code_client_profit': cliente['code_client_profit'],
        'tax_id': cliente['tax_id'],
        'sincronizado': 1,
        'fecha_sync': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getClientes() async {
    final db = await database;
    return await db.query('clientes', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> buscarClientes(String query) async {
    final db = await database;
    return await db.query(
      'clientes',
      where: 'name LIKE ? OR code_client_profit LIKE ? OR tax_id LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
  }

  // ═══════════════════════════════════════════
  // VISITAS
  // ═══════════════════════════════════════════

  Future<void> guardarVisitas(List<Map<String, dynamic>> visitas) async {
    final db = await database;
    final batch = db.batch();
    for (var visita in visitas) {
      batch.insert('visitas', {
        'id': visita['id']?.toString(),
        'customer_id': visita['customer_id'],
        'customer_name': visita['customer_name'],
        'address': visita['address'],
        'city': visita['city'],
        'code_client_profit': visita['code_client_profit'],
        'tax_id': visita['tax_id'],
        'visit_date_from': visita['visit_date_from'],
        'visit_date_to': visita['visit_date_to'],
        'notes': visita['notes'],
        'priority': visita['priority'] ?? 1,
        'status': visita['status'] ?? 'PENDING',
        'completed_at': visita['completed_at'],
        'sincronizado': 1,
        'fecha_sync': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getVisitas({
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (dateFrom != null) {
      conditions.add('visit_date_from >= ?');
      args.add(dateFrom);
    }
    if (dateTo != null) {
      conditions.add('visit_date_to <= ?');
      args.add(dateTo);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    return await db.query(
      'visitas',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'visit_date_from ASC',
    );
  }

  Future<void> actualizarEstadoVisita(String id, String status) async {
    final db = await database;
    await db.update(
      'visitas',
      {'status': status, 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════
  // ENCUESTAS (Preguntas)
  // ═══════════════════════════════════════════

  Future<void> guardarEncuestaPreguntas({
    required String id,
    required String visitId,
    String? salespersonId,
    String? customerId,
    required String questionsJson,
  }) async {
    final db = await database;
    await db.insert('encuestas_visita', {
      'id': id,
      'visit_id': visitId,
      'salesperson_id': salespersonId,
      'customer_id': customerId,
      'questions_json': questionsJson,
      'sincronizado': 1,
      'fecha_sync': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getEncuestaByVisitaId(String visitId) async {
    final db = await database;
    final results = await db.query(
      'encuestas_visita',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ═══════════════════════════════════════════
  // RESPUESTAS PENDIENTES
  // ═══════════════════════════════════════════

  Future<int> guardarRespuesta({
    required String visitId,
    String? customerName,
    required String respuestasJson,
    double? lat,
    double? lng,
    String? foto1Path,
    String? foto2Path,
  }) async {
    final db = await database;
    return await db.insert('respuestas_pendientes', {
      'visit_id': visitId,
      'customer_name': customerName,
      'respuestas_json': respuestasJson,
      'lat': lat,
      'lng': lng,
      'foto1_path': foto1Path,
      'foto2_path': foto2Path,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'sincronizado': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getRespuestasPendientes() async {
    final db = await database;
    return await db.query(
      'respuestas_pendientes',
      where: 'sincronizado = 0',
      orderBy: 'fecha_creacion ASC',
    );
  }

  Future<int> marcarRespuestaSincronizada(int id) async {
    final db = await database;
    return await db.update(
      'respuestas_pendientes',
      {'sincronizado': 1, 'fecha_sync': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> contarRespuestasPendientes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM respuestas_pendientes WHERE sincronizado = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ═══════════════════════════════════════════
  // LIMPIEZA POST-SINCRONIZACIÓN
  // ═══════════════════════════════════════════

  /// Elimina respuestas ya sincronizadas
  Future<int> eliminarRespuestasSincronizadas() async {
    final db = await database;
    return await db.delete(
      'respuestas_pendientes',
      where: 'sincronizado = 1',
    );
  }

  /// Elimina una visita específica (cuando se completó y sincronizó)
  Future<int> eliminarVisita(String id) async {
    final db = await database;
    // Eliminar encuesta asociada
    await db.delete('encuestas_visita', where: 'visit_id = ?', whereArgs: [id]);
    // Eliminar visita
    return await db.delete('visitas', where: 'id = ?', whereArgs: [id]);
  }

  /// Elimina visitas completadas y sincronizadas
  Future<int> limpiarVisitasCompletadas() async {
    final db = await database;
    return await db.delete(
      'visitas',
      where: 'status = ?',
      whereArgs: ['COMPLETED'],
    );
  }

  /// Limpia datos antiguos (más de 7 días)
  Future<void> limpiarDatosAntiguos() async {
    final db = await database;
    final limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete('respuestas_pendientes', where: 'fecha_creacion < ? AND sincronizado = 1', whereArgs: [limite]);
    await db.delete('visitas', where: 'completed_at < ? AND status = ?', whereArgs: [limite, 'COMPLETED']);
  }

  /// Verifica si hay datos offline
  Future<bool> tieneDatosOffline() async {
    final pendientes = await contarRespuestasPendientes();
    return pendientes > 0;
  }

  /// Obtiene estadísticas
  Future<Map<String, int>> getEstadisticas() async {
    final db = await database;
    final clientes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM clientes')) ?? 0;
    final visitas = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM visitas')) ?? 0;
    final pendientes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM respuestas_pendientes WHERE sincronizado = 0')) ?? 0;
    return {'clientes': clientes, 'visitas': visitas, 'pendientes': pendientes};
  }


  // ═══════════════════════════════════════════
  // AUTENTICACIÓN LOCAL
  // ═══════════════════════════════════════════

  /// Inserta el usuario maestro por defecto (se llama al iniciar la app)
  Future<void> insertarUsuarioMaestro() async {
    final db = await database;
    // Verificar si ya existe
    final existente = await db.query('usuarios', where: 'username = ?', whereArgs: ['admin']);
    if (existente.isEmpty) {
      await db.insert('usuarios', {
        'id': 'admin-001',
        'username': 'admin',
        'password': 'admin123',
        'full_name': 'Administrador',
        'role': 'admin',
        'activo': 1,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      print('✅ Usuario maestro creado');
    }

    final vendedorExistente = await db.query('usuarios', where: 'username = ?', whereArgs: ['vendedor@solsumed']);
    if (vendedorExistente.isEmpty) {
      await db.insert('usuarios', {
        'id': 'vendedor-001',
        'username': 'vendedor@solsumed',
        'password': '123456',
        'full_name': 'Vendedor Principal',
        'role': 'vendedor',
        'activo': 1,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      print('✅ Usuario vendedor creado');
    }
  }

  /// Verifica credenciales de login
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final results = await db.query(
      'usuarios',
      where: 'username = ? AND password = ? AND activo = 1',
      whereArgs: [username, password],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Inserta un nuevo usuario (vendedor)
  Future<int> crearUsuario({
    required String username,
    required String password,
    required String fullName,
    String role = 'vendedor',
  }) async {
    final db = await database;
    final userId = 'usr_${DateTime.now().microsecondsSinceEpoch}';
    return await db.insert('usuarios', {
      'id': userId,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role,
      'activo': 1,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene todos los usuarios
  Future<List<Map<String, dynamic>>> getUsuarios() async {
    final db = await database;
    return await db.query('usuarios', orderBy: 'fecha_creacion DESC');
  }

  /// Obtiene un usuario por ID
  Future<Map<String, dynamic>?> getUsuario(String id) async {
    final db = await database;
    final results = await db.query('usuarios', where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  /// Elimina un usuario
  Future<int> eliminarUsuario(String id) async {
    final db = await database;
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════
  // ADMINISTRACIÓN DE ENCUESTAS (PLANTILLAS)
  // ═══════════════════════════════════════════

  /// Obtiene todas las plantillas de encuestas
  Future<List<Map<String, dynamic>>> getPlantillasEncuestas() async {
    final db = await database;
    return await db.query('encuestas', orderBy: 'fecha_creacion DESC');
  }

  /// Guarda una plantilla de encuesta (crear o editar)
  Future<void> guardarPlantillaEncuesta({
    required String id,
    required String titulo,
    String? descripcion,
  }) async {
    final db = await database;
    await db.insert('encuestas', {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'created_by': 'admin',
      'fecha_creacion': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Elimina una plantilla de encuesta y todas sus preguntas asociadas
  Future<void> eliminarPlantillaEncuesta(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('preguntas', where: 'encuesta_id = ?', whereArgs: [id]);
      await txn.delete('encuestas', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Obtiene las preguntas de una plantilla
  Future<List<Map<String, dynamic>>> getPreguntasByEncuestaId(String encuestaId) async {
    final db = await database;
    return await db.query(
      'preguntas',
      where: 'encuesta_id = ?',
      whereArgs: [encuestaId],
      orderBy: 'orden ASC',
    );
  }

  /// Guarda una pregunta en la plantilla
  Future<void> guardarPreguntaTemplate({
    required String id,
    required String encuestaId,
    required String descripcion,
    required String tipo,
    int esRequerida = 0,
    String? opciones,
    int orden = 0,
  }) async {
    final db = await database;
    await db.insert('preguntas', {
      'id': id,
      'encuesta_id': encuestaId,
      'descripcion': descripcion,
      'tipo': tipo,
      'es_requerida': esRequerida,
      'opciones': opciones,
      'orden': orden,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Elimina una pregunta de una plantilla
  Future<void> eliminarPreguntaTemplate(String id) async {
    final db = await database;
    await db.delete('preguntas', where: 'id = ?', whereArgs: [id]);
  }
}