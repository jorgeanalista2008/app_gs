import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'database_helper.dart';
import 'device_identity_service.dart';
import 'sync_queue_service.dart';

/// Registra la ubicación del usuario cada 1 minuto mientras haya sesión.
/// - Android: usa `getPositionStream` con un servicio en primer plano
///   para seguir emitiendo con la app en segundo plano o cerrada.
/// - iOS: usa `AppleSettings.allowBackgroundLocationUpdates` (requiere el
///   modo `location` en Info.plist + permiso `always`).
/// - Web / desktop: fallback con `Timer.periodic` + `getCurrentPosition`.
///
/// Cada muestra se persiste en la tabla `ubicaciones` y se encola para push
/// (`POST /ubicaciones`) vía [SyncQueueService].
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  static const Duration interval = Duration(minutes: 1);
  static const String _syncEndpoint = '/ubicaciones';
  static const String _entityType = 'ubicacion';

  final _uuid = const Uuid();
  StreamSubscription<Position>? _sub;
  Timer? _fallbackTimer;
  bool _starting = false;
  DateTime? _lastSavedAt;

  bool get isRunning => _sub != null || _fallbackTimer != null;

  /// Registra handler para marcar la ubicación como sincronizada tras push OK.
  /// Llamar una vez en main.dart al arrancar la app.
  static void registerSyncHandlers() {
    SyncQueueService.instance.registerSuccessHandler(
      _entityType,
      _onUbicacionPushSuccess,
    );
  }

  static Future<void> _onUbicacionPushSuccess(
    Map<String, dynamic> operation,
    String responseBody,
  ) async {
    final localId = operation['entity_local_id']?.toString();
    if (localId == null) return;
    String? serverId;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        serverId = data['id']?.toString();
      }
    } catch (_) {}
    try {
      await DatabaseHelper.instance
          .marcarUbicacionSincronizada(localId, serverId: serverId);
    } catch (e) {
      print('❌ [LocationTracking] no se pudo marcar sync: $e');
    }
  }

  Future<void> start() async {
    if (isRunning || _starting) return;
    _starting = true;
    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        print('📍 [LocationTracking] permisos insuficientes, no se inicia');
        return;
      }

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _sub = Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(),
        ).listen(
          _onPosition,
          onError: (e) => print('❌ [LocationTracking] stream error: $e'),
          cancelOnError: false,
        );
        print('📍 [LocationTracking] stream iniciado (intervalo ${interval.inMinutes}m)');
      } else {
        _fallbackTimer = Timer.periodic(interval, (_) async {
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            await _onPosition(pos);
          } catch (e) {
            print('❌ [LocationTracking] fallback error: $e');
          }
        });
        print('📍 [LocationTracking] timer fallback iniciado');
      }
    } finally {
      _starting = false;
    }
  }

  /// Captura la posición actual y la persiste marcada como lugar de visita.
  /// Se dispara desde eventos puntuales (inicio de encuesta, toma de foto),
  /// aparte del muestreo periódico. Devuelve la posición usada o null si
  /// no se pudo capturar.
  Future<Position?> registrarLugarVisita({
    required String visitId,
    String? note,
  }) async {
    final ok = await _ensurePermissions();
    if (!ok) {
      print('📍 [LocationTracking] permisos insuficientes para lugar de visita');
      return null;
    }
    final userId = await _resolveUserId();
    final deviceId = await DeviceIdentityService.instance.deviceId();
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
      final id = _uuid.v4();
      final recordedAt = pos.timestamp ?? DateTime.now();
      await DatabaseHelper.instance.insertarUbicacion(
        id: id,
        userId: userId,
        deviceId: deviceId,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        speed: pos.speed,
        heading: pos.heading,
        recordedAt: recordedAt,
        lugarVisita: true,
        visitId: visitId,
        locationSource: 'lugar_visita',
      );
      await SyncQueueService.instance.enqueue(
        entityType: _entityType,
        entityLocalId: id,
        operation: 'create',
        httpMethod: 'POST',
        endpoint: _syncEndpoint,
        payload: {
          'id': id,
          if (userId != null) 'user_id': userId,
          'device_id': deviceId,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'altitude': pos.altitude,
          'speed': pos.speed,
          'heading': pos.heading,
          'recorded_at': recordedAt.toUtc().toIso8601String(),
          'lugar_visita': true,
          'visit_id': visitId,
          'location_source': 'lugar_visita',
          if (note != null) 'note': note,
        },
      );
      print('📍 [LocationTracking] lugar de visita $visitId → '
          '${pos.latitude},${pos.longitude} (±${pos.accuracy.toStringAsFixed(0)}m)');
      unawaited(SyncQueueService.instance.drain(force: false));
      return pos;
    } catch (e) {
      print('❌ [LocationTracking] error capturando lugar de visita: $e');
      return null;
    }
  }

  /// Guarda una muestra de ubicación explícita (foto, prospecto, etc.).
  /// Devuelve el id local de la ubicación insertada.
  Future<String?> registrarUbicacionEvento({
    required Position pos,
    required DateTime capturedAt,
    required String source,
    String? visitId,
    String? contextId,
  }) async {
    try {
      final userId = await _resolveUserId();
      final deviceId = await DeviceIdentityService.instance.deviceId();
      final id = _uuid.v4();
      await DatabaseHelper.instance.insertarUbicacion(
        id: id,
        userId: userId,
        deviceId: deviceId,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        speed: pos.speed,
        heading: pos.heading,
        recordedAt: capturedAt,
        lugarVisita: source == 'foto' || source == 'lugar_visita',
        visitId: visitId,
        locationSource: source,
      );
      await SyncQueueService.instance.enqueue(
        entityType: _entityType,
        entityLocalId: id,
        operation: 'create',
        httpMethod: 'POST',
        endpoint: _syncEndpoint,
        payload: {
          'id': id,
          if (userId != null) 'user_id': userId,
          'device_id': deviceId,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'altitude': pos.altitude,
          'speed': pos.speed,
          'heading': pos.heading,
          'recorded_at': capturedAt.toUtc().toIso8601String(),
          'lugar_visita': source == 'foto' || source == 'lugar_visita',
          if (visitId != null) 'visit_id': visitId,
          if (contextId != null) 'context_id': contextId,
          'location_source': source,
        },
      );
      unawaited(SyncQueueService.instance.drain(force: false));
      return id;
    } catch (e) {
      print('❌ [LocationTracking] error registrarUbicacionEvento($source): $e');
      return null;
    }
  }

  Future<String?> _resolveUserId() async {
    final active = AuthService.instance.userId;
    if (active != null) return active;
    return DeviceIdentityService.instance.lastKnownUserId();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _lastSavedAt = null;
    print('📍 [LocationTracking] detenido');
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Grupo Solsumed',
          notificationText: 'Registrando ubicación en segundo plano',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<bool> _ensurePermissions() async {
    if (kIsWeb) return true;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      print('📍 [LocationTracking] servicio de ubicación desactivado');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    // whileInUse alcanza para foreground; en Android >= 10, para background
    // real hace falta pedir `always` explícitamente.
    if (perm == LocationPermission.whileInUse && !kIsWeb && Platform.isAndroid) {
      try {
        await Geolocator.requestPermission();
      } catch (_) {}
    }
    return true;
  }

  Future<void> _onPosition(Position pos) async {
    // Geolocator puede emitir varias muestras por intervalo (Android usa
    // intervalDuration como hint, no como garantía). Filtramos a 1/min.
    final now = DateTime.now();
    if (_lastSavedAt != null &&
        now.difference(_lastSavedAt!) <
            interval - const Duration(seconds: 5)) {
      return;
    }

    final userId = await _resolveUserId();
    final deviceId = await DeviceIdentityService.instance.deviceId();

    final id = _uuid.v4();
    final recordedAt = pos.timestamp ?? now;

    try {
      await DatabaseHelper.instance.insertarUbicacion(
        id: id,
        userId: userId,
        deviceId: deviceId,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        speed: pos.speed,
        heading: pos.heading,
        recordedAt: recordedAt,
        locationSource: 'tracking',
      );
      _lastSavedAt = now;

      await SyncQueueService.instance.enqueue(
        entityType: _entityType,
        entityLocalId: id,
        operation: 'create',
        httpMethod: 'POST',
        endpoint: _syncEndpoint,
        payload: {
          'id': id,
          if (userId != null) 'user_id': userId,
          'device_id': deviceId,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'altitude': pos.altitude,
          'speed': pos.speed,
          'heading': pos.heading,
          'recorded_at': recordedAt.toUtc().toIso8601String(),
          'lugar_visita': false,
          'location_source': 'tracking',
        },
      );

      print('📍 [LocationTracking] guardado ${pos.latitude},${pos.longitude} '
          '(±${pos.accuracy.toStringAsFixed(0)}m)');

      // Push inmediato: sin esperar los 2 min del timer periódico.
      // fire-and-forget para no bloquear el stream de posiciones.
      unawaited(SyncQueueService.instance.drain(force: false));
    } catch (e) {
      print('❌ [LocationTracking] error al guardar: $e');
    }
  }
}
