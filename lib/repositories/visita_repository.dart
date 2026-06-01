import '../models/visita_model.dart';
import 'generic_repository.dart';

class VisitaRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene todas las visitas guardadas localmente sin filtros
  Future<List<VisitaModel>> getVisitasLocales() async {
    final db = await _repo.getListLocal<VisitaModel>(
      table: 'visitas',
      orderBy: 'visit_date_from ASC',
      fromJson: (json) => VisitaModel.fromJson(json),
    );
    return db;
  }

  /// Obtiene las visitas guardadas localmente con filtro de fechas
  Future<List<VisitaModel>> getMisVisitas({
    required String dateFrom,
    required String dateTo,
    int page = 1,
    int limit = 25,
  }) async {
    final db = await _repo.rawQuery(
      '''SELECT * FROM visitas 
         WHERE visit_date_from >= ? 
         AND visit_date_to <= ? 
         ORDER BY visit_date_from ASC 
         LIMIT ? OFFSET ?''',
      [dateFrom, dateTo, limit, (page - 1) * limit],
    );
    return db.map((row) => VisitaModel.fromJson(row)).toList();
  }

  /// Obtiene las visitas del mes actual
  Future<List<VisitaModel>> getVisitasMesActual() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    return getMisVisitas(
      dateFrom: _formatDate(firstDay),
      dateTo: _formatDate(lastDay),
    );
  }

  /// Obtiene una visita por ID
  Future<VisitaModel?> getVisitaById(String id) async {
    return _repo.getById<VisitaModel>(
      table: 'visitas',
      id: id,
      fromJson: (json) => VisitaModel.fromJson(json),
    );
  }

  /// Guarda una lista de visitas en SQLite
  Future<void> guardarVisitas(List<VisitaModel> visitas) async {
    for (var visita in visitas) {
      await _repo.insert(
        table: 'visitas',
        data: visita.toJson(),
        id: visita.id,
      );
    }
  }

  /// Obtiene visitas por estado (PENDING, COMPLETED)
  Future<List<VisitaModel>> getVisitasPorEstado(String estado) async {
    return _repo.getList<VisitaModel>(
      table: 'visitas',
      where: 'status = ?',
      whereArgs: [estado],
      orderBy: 'visit_date_from ASC',
      fromJson: (json) => VisitaModel.fromJson(json),
    );
  }

  /// Cuenta visitas pendientes
  Future<int> contarVisitasPendientes() async {
    final result = await _repo.rawQuery(
      "SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'",
    );
    return result.isNotEmpty ? (result.first['total'] as int?) ?? 0 : 0;
  }

  /// Cuenta visitas completadas
  Future<int> contarVisitasCompletadas() async {
    final result = await _repo.rawQuery(
      "SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'",
    );
    return result.isNotEmpty ? (result.first['total'] as int?) ?? 0 : 0;
  }

  /// Actualiza el estado de una visita
  Future<bool> actualizarEstado(String id, String estado) async {
    final result = await _repo.update(
      table: 'visitas',
      data: {
        'status': estado,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  /// Elimina visitas completadas
  Future<int> limpiarCompletadas() async {
    return await _repo.delete(
      table: 'visitas',
      where: "status = 'COMPLETED'",
      whereArgs: [],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}