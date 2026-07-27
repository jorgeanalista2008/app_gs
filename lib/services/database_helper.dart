import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'conflict_resolver.dart';

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
      version: 12,
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
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN activo INTEGER DEFAULT 1');
          } catch (e) {
            print('Column activo already exists in clientes: $e');
          }
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN tipo TEXT');
          } catch (e) {
            print('Column tipo already exists in clientes: $e');
          }
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN lat REAL');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN lng REAL');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE clientes ADD COLUMN coordenadas_actualizadas INTEGER DEFAULT 0');
          } catch (e) {}
          await _createPendingOperationsTable(db);
        }
        if (oldVersion < 6) {
          await _addSyncTimestampColumns(db);
          await _createSyncConflictsTable(db);
        }
        if (oldVersion < 7) {
          await _addProspectColumns(db);
          await _createIdMappingTable(db);
        }
        if (oldVersion < 8) {
          await _addProspectPhotosAndExtraFields(db);
        }
        if (oldVersion < 9) {
          await _addUserIdentifiers(db);
        }
        if (oldVersion < 10) {
          try {
            await db.execute('ALTER TABLE preguntas ADD COLUMN server_id TEXT');
          } catch (_) {}
        }
        if (oldVersion < 11) {
          await _createUbicacionesTable(db);
        }
        if (oldVersion < 12) {
          try {
            await db.execute(
                'ALTER TABLE ubicaciones ADD COLUMN lugar_visita INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE ubicaciones ADD COLUMN visit_id TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_ubicaciones_visit ON ubicaciones(visit_id, lugar_visita)');
          } catch (_) {}
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
      fecha_creacion TEXT,
      tenant_id TEXT,
      company_id TEXT,
      branch_id TEXT
    )
  ''');

  // Tabla de encuestas (plantillas)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS encuestas (
      id TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      descripcion TEXT,
      created_by TEXT,
      fecha_creacion TEXT,
      updated_at TEXT,
      server_updated_at TEXT,
      sincronizado INTEGER DEFAULT 0
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
      updated_at TEXT,
      server_updated_at TEXT,
      sincronizado INTEGER DEFAULT 0,
      server_id TEXT,
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
        activo INTEGER DEFAULT 1,
        tipo TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_sync TEXT,
        updated_at TEXT,
        server_updated_at TEXT,
        is_prospect INTEGER DEFAULT 0,
        server_id TEXT,
        notes TEXT,
        lat REAL,
        lng REAL,
        coordenadas_actualizadas INTEGER DEFAULT 0,
        contact_name TEXT,
        city TEXT,
        zone_code TEXT,
        next_followup_date TEXT,
        photo_1 TEXT,
        photo_2 TEXT
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
        fecha_sync TEXT,
        updated_at TEXT,
        server_updated_at TEXT
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
        fecha_sync TEXT,
        updated_at TEXT,
        server_updated_at TEXT
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
        sincronizado INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await _createPendingOperationsTable(db);
    await _createSyncConflictsTable(db);
    await _createIdMappingTable(db);
    await _createUbicacionesTable(db);
  }

  Future<void> _createUbicacionesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ubicaciones (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        speed REAL,
        heading REAL,
        recorded_at TEXT NOT NULL,
        lugar_visita INTEGER NOT NULL DEFAULT 0,
        visit_id TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        server_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ubicaciones_user_time ON ubicaciones(user_id, recorded_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ubicaciones_pend ON ubicaciones(sincronizado, recorded_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ubicaciones_visit ON ubicaciones(visit_id, lugar_visita)',
    );
  }

  /// Agrega columnas de sync timestamps a tablas existentes (migración v5→v6).
  Future<void> _addSyncTimestampColumns(Database db) async {
    const targets = {
      'clientes': ['updated_at', 'server_updated_at'],
      'visitas': ['updated_at', 'server_updated_at'],
      'encuestas_visita': ['updated_at', 'server_updated_at'],
      'respuestas_pendientes': ['updated_at'],
      'encuestas': ['updated_at', 'server_updated_at', 'sincronizado'],
      'preguntas': ['updated_at', 'server_updated_at', 'sincronizado'],
    };
    for (final entry in targets.entries) {
      for (final col in entry.value) {
        try {
          final type = col == 'sincronizado' ? 'INTEGER DEFAULT 0' : 'TEXT';
          await db.execute('ALTER TABLE ${entry.key} ADD COLUMN $col $type');
        } catch (_) {
          // ya existe
        }
      }
    }
  }

  /// Migración v6→v7: columnas para prospectos + mapeo de IDs.
  Future<void> _addProspectColumns(Database db) async {
    const cols = {
      'is_prospect': 'INTEGER DEFAULT 0',
      'server_id': 'TEXT',
      'notes': 'TEXT',
    };
    for (final entry in cols.entries) {
      try {
        await db.execute(
            'ALTER TABLE clientes ADD COLUMN ${entry.key} ${entry.value}');
      } catch (_) {}
    }
  }

  /// Migración v7→v8: columnas para fotos de prospecto + datos extra.
  Future<void> _addProspectPhotosAndExtraFields(Database db) async {
    const cols = {
      'contact_name': 'TEXT',
      'city': 'TEXT',
      'zone_code': 'TEXT',
      'next_followup_date': 'TEXT',
      'photo_1': 'TEXT',
      'photo_2': 'TEXT',
    };
    for (final entry in cols.entries) {
      try {
        await db.execute(
            'ALTER TABLE clientes ADD COLUMN ${entry.key} ${entry.value}');
      } catch (_) {}
    }
  }

  /// Migración v8→v9: columnas para tenant_id, company_id y branch_id en usuarios.
  Future<void> _addUserIdentifiers(Database db) async {
    const cols = {
      'tenant_id': 'TEXT',
      'company_id': 'TEXT',
      'branch_id': 'TEXT',
    };
    for (final entry in cols.entries) {
      try {
        await db.execute(
            'ALTER TABLE usuarios ADD COLUMN ${entry.key} ${entry.value}');
      } catch (_) {}
    }
  }

  Future<void> _createIdMappingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS id_mapping (
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        server_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (entity_type, local_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_idmap_server ON id_mapping(entity_type, server_id)',
    );
  }

  Future<void> _createSyncConflictsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_updated_at TEXT,
        server_updated_at TEXT,
        resolution TEXT NOT NULL,
        local_snapshot TEXT,
        server_snapshot TEXT,
        resolved_at TEXT NOT NULL,
        reviewed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_conflicts_entity ON sync_conflicts(entity_type, entity_id)',
    );
  }

  Future<void> _createPendingOperationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_local_id TEXT,
        operation TEXT NOT NULL,
        http_method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload_json TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        max_attempts INTEGER NOT NULL DEFAULT 10,
        next_retry_at TEXT NOT NULL,
        last_error TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        server_response TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_status_retry ON pending_operations(status, next_retry_at)',
    );
  }

  // ═══════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════

  Future<void> guardarClientes(List<Map<String, dynamic>> clientes) async {
    final db = await database;
    final resolver = ConflictResolver.instance;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final cliente in clientes) {
      final id = cliente['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final existing = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final localRow = existing.isNotEmpty ? existing.first : null;

      final result = await resolver.resolve(
        entityType: 'customer',
        entityId: id,
        localRow: localRow,
        serverRow: cliente,
      );

      if (result.action == ConflictAction.keepLocal ||
          result.action == ConflictAction.noChange) {
        continue;
      }

      final activeVal = cliente['active'] == true ||
              cliente['active']?.toString() == 'true' ||
              cliente['activo'] == true ||
              cliente['activo']?.toString() == 'true' ||
              cliente['active'] == 1 ||
              cliente['activo'] == 1
          ? 1
          : 0;

      final serverUpdatedAtIso = result.serverUpdatedAt?.toIso8601String();
      await db.insert(
        'clientes',
        {
          'id': id,
          'name': cliente['name'] ?? 'Sin nombre',
          'code_client_profit': cliente['code_client_profit'] ?? '',
          'tax_id': cliente['tax_id'] ?? '',
          'telefono': cliente['phone']?.toString() ?? cliente['telefono']?.toString() ?? '',
          'email': cliente['email']?.toString() ?? '',
          'direccion': cliente['address']?.toString() ?? cliente['direccion']?.toString() ?? '',
          'activo': activeVal,
          'tipo': cliente['type']?.toString() ?? cliente['tipo']?.toString() ?? '',
          'sincronizado': 1,
          'fecha_sync': nowIso,
          'updated_at': serverUpdatedAtIso ?? nowIso,
          'server_updated_at': serverUpdatedAtIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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
    final resolver = ConflictResolver.instance;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final visita in visitas) {
      final id = visita['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final existing = await db.query(
        'visitas',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final localRow = existing.isNotEmpty ? existing.first : null;

      final result = await resolver.resolve(
        entityType: 'visit',
        entityId: id,
        localRow: localRow,
        serverRow: visita,
      );

      if (result.action == ConflictAction.keepLocal ||
          result.action == ConflictAction.noChange) {
        continue;
      }

      final serverUpdatedAtIso = result.serverUpdatedAt?.toIso8601String();
      await db.insert(
        'visitas',
        {
          'id': id,
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
          'fecha_sync': nowIso,
          'updated_at': serverUpdatedAtIso ?? nowIso,
          'server_updated_at': serverUpdatedAtIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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
      {
        'status': status,
        'completed_at': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> marcarVisitaSincronizada(String id) async {
    final db = await database;
    await db.update(
      'visitas',
      {
        'sincronizado': 1,
        'fecha_sync': DateTime.now().toIso8601String(),
      },
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
      {'sincronizado': 1, 'updated_at': DateTime.now().toIso8601String()},
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
        'password': '123456',
        'full_name': 'Administrador',
        'role': 'admin',
        'activo': 1,
        'fecha_creacion': DateTime.now().toIso8601String(),
        'tenant_id': 'A1000000-0000-0000-0000-000000000001',
        'company_id': 'A1000000-0000-0000-0000-000000000001',
        'branch_id': 'E8CCCF7B-F658-4FC4-B348-28EDCB8E229B',
      });
      print('✅ Usuario maestro creado');
    } else {
      await db.update('usuarios', {
        'tenant_id': 'A1000000-0000-0000-0000-000000000001',
        'company_id': 'A1000000-0000-0000-0000-000000000001',
        'branch_id': 'E8CCCF7B-F658-4FC4-B348-28EDCB8E229B',
      }, where: 'username = ?', whereArgs: ['admin']);
    }

    // Ya no se siembra un usuario "vendedor@solsumed.com" local de prueba: los
    // vendedores deben existir en el backend real y su cuenta se cachea
    // localmente la primera vez que inician sesión online (ver AuthService.login).
    // Se elimina la fila si quedó de una instalación previa a este cambio,
    // para que dispositivos ya probados dejen de "loguear" con ella offline.
    await db.delete('usuarios', where: 'username = ?', whereArgs: ['vendedor@solsumed.com']);
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
    String? tenantId,
    String? companyId,
    String? branchId,
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
      'tenant_id': tenantId,
      'company_id': companyId,
      'branch_id': branchId,
    });
  }

  /// Guarda o actualiza los datos de un usuario tras login online exitoso.
  Future<void> guardarOActualizarUsuario({
    required String id,
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? tenantId,
    String? companyId,
    String? branchId,
  }) async {
    final db = await database;
    final existente = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    final userData = {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role,
      'activo': 1,
      'tenant_id': tenantId,
      'company_id': companyId,
      'branch_id': branchId,
    };
    if (existente.isEmpty) {
      await db.insert('usuarios', {
        ...userData,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      print('💾 Nuevo usuario $username guardado en SQLite local');
    } else {
      await db.update('usuarios', userData, where: 'id = ?', whereArgs: [id]);
      print('💾 Usuario $username actualizado en SQLite local');
    }
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
    String? serverId,
    int sincronizado = 0,
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
      'server_id': serverId,
      'sincronizado': sincronizado,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Marca una pregunta local como sincronizada, asociando su id de servidor
  Future<void> marcarPreguntaSincronizada(String localId, String serverId) async {
    final db = await database;
    await db.update(
      'preguntas',
      {
        'server_id': serverId,
        'sincronizado': 1,
        'server_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Devuelve preguntas creadas por el vendedor localmente que aún no fueron
  /// enviadas al servidor (sincronizado = 0 y server_id nulo).
  Future<List<Map<String, dynamic>>> getPreguntasPendientesPush() async {
    final db = await database;
    return await db.query(
      'preguntas',
      where: 'sincronizado = 0 AND (server_id IS NULL OR server_id = \'\')',
      orderBy: 'orden ASC, updated_at ASC',
    );
  }

  /// Elimina una pregunta de una plantilla
  Future<void> eliminarPreguntaTemplate(String id) async {
    final db = await database;
    await db.delete('preguntas', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════
  // HELPERS DE SYNC
  // ═══════════════════════════════════════════

  /// Marca un registro local como modificado sin sincronizar.
  /// Agregar a [data] los campos `updated_at` y `sincronizado = 0` antes de
  /// llamar a insert/update. Usar en cualquier mutación local que deba luego
  /// pushearse al servidor.
  Map<String, dynamic> stampLocalWrite(Map<String, dynamic> data) {
    final stamped = Map<String, dynamic>.from(data);
    stamped['updated_at'] = DateTime.now().toUtc().toIso8601String();
    stamped['sincronizado'] = 0;
    return stamped;
  }

  /// Marca un registro como sincronizado tras éxito de push al servidor.
  /// Llamar después que SyncQueueService confirma 2xx.
  Future<int> markSyncedAfterPush({
    required String table,
    required String idColumn,
    required dynamic id,
    DateTime? serverUpdatedAt,
  }) async {
    final db = await database;
    final iso = (serverUpdatedAt ?? DateTime.now().toUtc()).toIso8601String();
    return db.update(
      table,
      {
        'sincronizado': 1,
        'fecha_sync': DateTime.now().toIso8601String(),
        'server_updated_at': iso,
      },
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════
  // ID MAPPING (local UUID ↔ server ID)
  // ═══════════════════════════════════════════

  Future<void> registrarIdMapping({
    required String entityType,
    required String localId,
    required String serverId,
  }) async {
    final db = await database;
    await db.insert(
      'id_mapping',
      {
        'entity_type': entityType,
        'local_id': localId,
        'server_id': serverId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Resuelve un local_id → server_id. Si no hay mapping retorna null.
  Future<String?> getServerId(String entityType, String localId) async {
    final db = await database;
    final result = await db.query(
      'id_mapping',
      columns: ['server_id'],
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['server_id'] as String?;
  }

  // ═══════════════════════════════════════════
  // UBICACIONES (tracking periódico)
  // ═══════════════════════════════════════════

  Future<int> insertarUbicacion({
    required String id,
    required String userId,
    required double lat,
    required double lng,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    required DateTime recordedAt,
    bool lugarVisita = false,
    String? visitId,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return db.insert('ubicaciones', {
      'id': id,
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'lugar_visita': lugarVisita ? 1 : 0,
      'visit_id': visitId,
      'sincronizado': 0,
      'created_at': nowIso,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUbicacionesPendientes({int limit = 100}) async {
    final db = await database;
    return db.query(
      'ubicaciones',
      where: 'sincronizado = 0',
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
  }

  Future<int> marcarUbicacionSincronizada(String id, {String? serverId}) async {
    final db = await database;
    return db.update(
      'ubicaciones',
      {
        'sincronizado': 1,
        if (serverId != null) 'server_id': serverId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarUbicacionesSincronizadas({Duration olderThan = const Duration(days: 14)}) async {
    final db = await database;
    final threshold = DateTime.now().toUtc().subtract(olderThan).toIso8601String();
    return db.delete(
      'ubicaciones',
      where: 'sincronizado = 1 AND recorded_at < ?',
      whereArgs: [threshold],
    );
  }
}