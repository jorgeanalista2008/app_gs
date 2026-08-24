import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:sqflite/sqflite.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Servicio de autenticación biométrica (huella, cara, PIN)
/// Detecta métodos disponibles y gestiona fallback a contraseña
class BiometricService {
  static final BiometricService instance = BiometricService._();
  BiometricService._();

  final _localAuth = LocalAuthentication();
  static const _bioStorageKey = '_biometric_enabled';

  /// Verifica si dispositivo soporta biometría
  Future<bool> get canUseBiometrics async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('⚠️  [BiometricService] Error verificando biometría: $e');
      return false;
    }
  }

  /// Obtiene lista de métodos biométricos disponibles
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      if (!await canUseBiometrics) return [];
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('⚠️  [BiometricService] Error obteniendo biometría disponible: $e');
      return [];
    }
  }

  /// Verifica si el usuario ha habilitado login biométrico previamente
  Future<bool> isBiometricLoginEnabled() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'biometric_settings',
        where: 'key = ?',
        whereArgs: [_bioStorageKey],
      );
      return result.isNotEmpty && result.first['value'] == '1';
    } catch (e) {
      print('⚠️  [BiometricService] Error verificando si biometric habilitado: $e');
      return false;
    }
  }

  /// Habilita login biométrico para este usuario
  Future<void> enableBiometricLogin(String username) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'biometric_settings',
        {
          'key': _bioStorageKey,
          'username': username,
          'value': '1',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ [BiometricService] Login biométrico habilitado para $username');
    } catch (e) {
      print('❌ [BiometricService] Error habilitando biometric: $e');
    }
  }

  /// Deshabilita login biométrico
  Future<void> disableBiometricLogin() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'biometric_settings',
        where: 'key = ?',
        whereArgs: [_bioStorageKey],
      );
      print('✅ [BiometricService] Login biométrico deshabilitado');
    } catch (e) {
      print('⚠️  [BiometricService] Error deshabilitando biometric: $e');
    }
  }

  /// Autentica usando biometría (huella, cara, PIN)
  /// Retorna username si éxito, null si falla
  Future<String?> authenticateWithBiometric() async {
    try {
      // 1. Verificar disponibilidad
      if (!await canUseBiometrics) {
        print('⚠️  [BiometricService] Biometría no disponible');
        return null;
      }

      // 2. Obtener username guardado
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'biometric_settings',
        where: 'key = ?',
        whereArgs: [_bioStorageKey],
      );

      if (result.isEmpty) {
        print('⚠️  [BiometricService] No hay usuario con biometric habilitado');
        return null;
      }

      final username = result.first['username']?.toString();
      if (username == null) {
        print('⚠️  [BiometricService] Username nulo en biometric_settings');
        return null;
      }

      // 3. Intentar autenticar
      print('🔐 [BiometricService] Autenticando con biometría...');
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentica para acceder a tu cuenta',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        print('✅ [BiometricService] Autenticación biométrica exitosa: $username');
        return username;
      } else {
        print('❌ [BiometricService] Autenticación biométrica cancelada');
        return null;
      }
    } on Exception catch (e) {
      if (e.toString().contains(auth_error.notAvailable)) {
        print('⚠️  [BiometricService] Biometría no disponible en este momento');
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        print('⚠️  [BiometricService] Sin biometría registrada en el dispositivo');
      } else if (e.toString().contains(auth_error.lockedOut)) {
        print('⚠️  [BiometricService] Demasiados intentos fallidos');
      } else if (e.toString().contains(auth_error.permanentlyLockedOut)) {
        print('⚠️  [BiometricService] Biometría bloqueada permanentemente');
      } else {
        print('❌ [BiometricService] Error autenticando: $e');
      }
      return null;
    }
  }

  /// Completa login biométrico: valida username + biometría
  /// Retorna true si login exitoso
  Future<bool> loginWithBiometric() async {
    try {
      // 1. Autenticar biométricamente
      final username = await authenticateWithBiometric();
      if (username == null) {
        print('❌ [BiometricService] Autenticación biométrica fallida');
        return false;
      }

      // 2. Obtener usuario local (sin validar contraseña)
      final userLocal = await DatabaseHelper.instance.getUsuario(username);
      if (userLocal == null) {
        print('❌ [BiometricService] Usuario $username no encontrado');
        return false;
      }

      // 3. Guardar sesión en AuthService
      await AuthService.instance.setUserSession(
        userId: username,
        username: username,
        role: userLocal['role']?.toString() ?? 'vendedor',
      );

      print('✅ [BiometricService] Login biométrico completado: $username');
      return true;
    } catch (e) {
      print('❌ [BiometricService] Error en loginWithBiometric: $e');
      return false;
    }
  }

  /// Obtiene el username guardado para login biométrico
  Future<String?> getSavedBiometricUsername() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'biometric_settings',
        where: 'key = ?',
        whereArgs: [_bioStorageKey],
      );
      return result.isNotEmpty ? result.first['username']?.toString() : null;
    } catch (e) {
      print('⚠️  [BiometricService] Error obteniendo username guardado: $e');
      return null;
    }
  }

  /// Obtiene descripción legible de métodos biométricos disponibles
  Future<String> getBiometricDescription() async {
    try {
      final biometrics = await availableBiometrics;
      if (biometrics.isEmpty) return 'Sin biometría disponible';

      final descriptions = <String>[];
      for (final bio in biometrics) {
        if (bio == BiometricType.fingerprint) {
          descriptions.add('Huella dactilar');
        } else if (bio == BiometricType.face) {
          descriptions.add('Reconocimiento facial');
        } else if (bio == BiometricType.iris) {
          descriptions.add('Iris');
        } else if (bio == BiometricType.strong) {
          descriptions.add('Biometría fuerte');
        } else if (bio == BiometricType.weak) {
          descriptions.add('Biometría débil');
        }
      }

      return descriptions.isEmpty
          ? 'Sin biometría disponible'
          : descriptions.join(' + ');
    } catch (e) {
      return 'Error detectando biometría';
    }
  }
}
