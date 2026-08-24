import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../core/app_colors.dart';

class BiometricLoginPage extends StatefulWidget {
  const BiometricLoginPage({Key? key}) : super(key: key);

  @override
  State<BiometricLoginPage> createState() => _BiometricLoginPageState();
}

class _BiometricLoginPageState extends State<BiometricLoginPage> {
  late BiometricService _bioService;
  bool _isAuthenticating = false;
  String? _statusMessage;
  String? _biometricDescription;
  int _failureCount = 0;
  static const int _maxFailures = 3;

  @override
  void initState() {
    super.initState();
    _bioService = BiometricService.instance;
    _initializeBiometric();
  }

  Future<void> _initializeBiometric() async {
    try {
      // Verificar disponibilidad
      final canUse = await _bioService.canUseBiometrics;
      if (!canUse) {
        _updateStatus(
          '⚠️ Biometría no disponible en este dispositivo',
          isError: true,
        );
        return;
      }

      // Obtener descripción
      final description = await _bioService.getBiometricDescription();
      setState(() => _biometricDescription = description);

      // Obtener username guardado
      final username = await _bioService.getSavedBiometricUsername();
      if (username != null) {
        _updateStatus('👤 Login de: $username', isError: false);
      }
    } catch (e) {
      print('❌ Error inicializando biometric: $e');
      _updateStatus('Error inicializando', isError: true);
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    _updateStatus('🔐 Autenticando...', isError: false);

    try {
      // Intentar login biométrico
      final success = await _bioService.loginWithBiometric();

      if (success) {
        _updateStatus('✅ Login exitoso', isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      } else {
        _failureCount++;
        if (_failureCount >= _maxFailures) {
          _updateStatus(
            '❌ Máximo de intentos fallidos (${_failureCount}/$_maxFailures)\nVolver a login tradicional',
            isError: true,
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          _updateStatus(
            '❌ Autenticación fallida\nIntento $_failureCount/$_maxFailures',
            isError: true,
          );
        }
      }
    } catch (e) {
      print('❌ Error autenticando: $e');
      _updateStatus('❌ Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _updateStatus(String message, {required bool isError}) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login con Biometría'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Header
              Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      size: 60,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Autenticación Biométrica',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_biometricDescription != null)
                    Text(
                      _biometricDescription!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),

              // Status Message
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusMessage!.startsWith('❌')
                        ? Colors.red[50]
                        : (_statusMessage!.startsWith('✅')
                            ? Colors.green[50]
                            : Colors.blue[50]),
                    border: Border.all(
                      color: _statusMessage!.startsWith('❌')
                          ? Colors.red[300]!
                          : (_statusMessage!.startsWith('✅')
                              ? Colors.green[300]!
                              : Colors.blue[300]!),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _statusMessage!.startsWith('❌')
                          ? Colors.red[700]
                          : (_statusMessage!.startsWith('✅')
                              ? Colors.green[700]
                              : Colors.blue[700]),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Authenticate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _isAuthenticating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(
                    _isAuthenticating
                        ? 'Autenticando...'
                        : 'Autenticar con Biometría',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Información',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Usa tu huella dactilar o reconocimiento facial para acceder rápidamente a tu cuenta.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Si falla múltiples veces, regresa a login tradicional con contraseña.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
