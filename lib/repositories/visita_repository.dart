import '../models/visita_model.dart';
import 'generic_repository.dart';

class VisitaRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene las visitas del vendedor logueado
  /// [dateFrom] - Fecha inicio (YYYY-MM-DD)
  /// [dateTo] - Fecha fin (YYYY-MM-DD)
  /// [page] - Página
  /// [limit] - Cantidad por página
  Future<List<VisitaModel>> getMisVisitas({
    required String dateFrom,
    required String dateTo,
    int page = 1,
    int limit = 25,
  }) async {
    return _repo.getList<VisitaModel>(
      path: '/salesperson/me/schedules',
      queryParams: {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'page': page.toString(),
        'limit': limit.toString(),
      },
      nestedKey: 'data',
      fromJson: (json) => VisitaModel.fromJson(json),
    );
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}