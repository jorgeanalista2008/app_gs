// Centraliza la URL base de la API.
//
// El valor por defecto apunta a la API de producción vía HTTPS.
// Importante: NO usar http:// para movil.grupo-solsumed.com porque
// Cloudflare responde 301 → HTTPS y el paquete `http` de Flutter no
// sigue redirects en POST, dejando el login colgado silenciosamente.
//
// Para apuntar a otro backend (ej. local en dev) sin tocar este archivo:
//   flutter run       --dart-define=API_BASE_URL=http://192.168.0.128:3000
//   flutter build apk --dart-define=API_BASE_URL=http://192.168.0.128:3000
//
// El valor SIEMPRE debe incluir el esquema (http:// o https://). Sin él,
// Uri.parse revienta con "Scheme not starting with alphabetic character"
// y toda petición falla — la app queda inutilizable.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.128:3000',
  );
}
