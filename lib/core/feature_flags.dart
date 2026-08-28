/// Flags de features en desarrollo o pausadas.
///
/// Alternativa a comentar bloques de código para "desactivar temporalmente"
/// una feature — ese patrón (visto en encuesta_page.dart y
/// nuevo_prospecto_page.dart) hace fácil olvidar reactivarla. Cambiar acá
/// en su lugar: un solo punto, buscable, sin código muerto en el medio.
class FeatureFlags {
  FeatureFlags._();

  /// Sección "Evidencias fotográficas" al completar una visita.
  static const bool fotosVisitaHabilitadas = true;

  /// Sección "Evidencias fotográficas" al crear un prospecto.
  static const bool fotosProspectoHabilitadas = true;
}
