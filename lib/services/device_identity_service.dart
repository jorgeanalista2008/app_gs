import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identidad persistente del dispositivo, independiente de la sesión.
///
/// - `deviceId`: uuid v4 generado una única vez y almacenado en
///   `shared_preferences`. Sobrevive logout / reinstall opcional (no en
///   reinstall, `shared_preferences` se borra). Sirve para asociar
///   ubicaciones registradas sin usuario logueado.
/// - `lastKnownUserId`: último `user_id` que inició sesión. Sirve como
///   respaldo para etiquetar muestras de ubicación después del logout.
class DeviceIdentityService {
  DeviceIdentityService._();
  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const _deviceIdKey = 'device_id';
  static const _lastUserIdKey = 'last_known_user_id';
  static const _trackingConsentKey = 'location_tracking_consent';

  final _uuid = const Uuid();
  String? _deviceIdCache;
  String? _lastKnownUserIdCache;

  Future<String> deviceId() async {
    if (_deviceIdCache != null) return _deviceIdCache!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_deviceIdKey, id);
      print('🆔 [DeviceIdentity] generado nuevo device_id=$id');
    }
    _deviceIdCache = id;
    return id;
  }

  Future<String?> lastKnownUserId() async {
    if (_lastKnownUserIdCache != null) return _lastKnownUserIdCache;
    final prefs = await SharedPreferences.getInstance();
    _lastKnownUserIdCache = prefs.getString(_lastUserIdKey);
    return _lastKnownUserIdCache;
  }

  Future<void> setLastKnownUserId(String userId) async {
    _lastKnownUserIdCache = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUserIdKey, userId);
  }

  Future<bool> hasTrackingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingConsentKey) ?? false;
  }

  Future<void> setTrackingConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingConsentKey, value);
  }
}
