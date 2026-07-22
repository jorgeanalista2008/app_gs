// Centraliza la URL base de la API.
//
// El valor por defecto apunta a la API de producción
// (https://movil.grupo-solsumed.com). Para apuntar a otro backend (ej. local
// durante desarrollo) sin tocar este archivo, compila/corre con:
//
//   flutter run --dart-define=API_BASE_URL=http://192.168.0.128:3000
//   flutter build apk --dart-define=API_BASE_URL=http://192.168.0.128:3000
//
// Si se omite --dart-define, se usa el valor por defecto de producción.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://movil.grupo-solsumed.com',
  );
}
