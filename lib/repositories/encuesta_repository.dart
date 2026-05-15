import '../models/encuesta_model.dart';
import 'generic_repository.dart';

class EncuestaRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene las preguntas de una visita
  Future<EncuestaModel?> getEncuesta(String visitaId) async {
    return _repo.getById<EncuestaModel>(
      path: '/salesperson/me/schedules/$visitaId/with-questions',
      fromJson: (json) => EncuestaModel.fromJson(json),
    );
  }
}