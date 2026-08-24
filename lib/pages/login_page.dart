import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/location_tracking_service.dart';
import 'home_page.dart';
import 'biometric_login_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;
  bool _canUseBiometrics = false;
  String _biometricMethod = '';

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
    _checkBiometricAvailability();
  }

  /// Verifica si el device tiene biometría disponible y qué método usa
  Future<void> _checkBiometricAvailability() async {
    try {
      final bioService = BiometricService.instance;
      final canUse = await bioService.canUseBiometrics;

      if (canUse) {
        // Obtener descripción del método biométrico
        final description = await bioService.getBiometricDescription();
        if (mounted) {
          setState(() {
            _canUseBiometrics = true;
            _biometricMethod = description;
          });
        }
        print('✅ [LoginPage] Biometría disponible: $description');
      } else {
        if (mounted) {
          setState(() => _canUseBiometrics = false);
        }
        print('⚠️  [LoginPage] Biometría no disponible en este device');
      }
    } catch (e) {
      print('⚠️  [LoginPage] Error verificando biometría: $e');
    }
  }

  /// Intenta restaurar sesión guardada
  Future<void> _tryAutoLogin() async {
    final loggedIn = await _authService.tryAutoLogin();
    if (loggedIn) {
      LocationTrackingService.instance.start();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Future<void> _checkBiometricAndNavigate() async {
    try {
      final bioService = BiometricService.instance;
      final canUse = await bioService.canUseBiometrics;

      if (!canUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Biometría no disponible en este dispositivo'),
            ),
          );
        }
        return;
      }

      // Navegar a BiometricLoginPage
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BiometricLoginPage()),
        );
      }
    } catch (e) {
      print('❌ Error verificando biometría: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al verificar biometría')),
        );
      }
    }
  }

  void _login() async {
    String usuario = _userController.text.trim();
    String password = _passController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingrese usuario y contraseña.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exito = await _authService.login(usuario, password);

      setState(() => _isLoading = false);

      if (exito) {
        print('=== LOGIN EXITOSO ===');
        print('Usuario: ${_authService.userName}');
        print('Rol: ${_authService.userRole}');
        print('=====================');

        LocationTrackingService.instance.start();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Usuario o contraseña incorrectos.'),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 60,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nombre de la empresa
              const Text(
                'Grupo Solsumed, CA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              // Subtítulo
              Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),

              // Card del formulario
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Campo de usuario
                    AppTextField(
                      controller: _userController,
                      labelText: 'Usuario',
                      hintText: 'Ingresa tu usuario',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.text,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 20),

                    // Campo de contraseña
                    AppTextField(
                      controller: _passController,
                      labelText: 'Contraseña',
                      hintText: '••••••••',
                      obscureText: true,
                      icon: Icons.lock_outline,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 30),

                    // Botón de login
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'INGRESAR',
                        onPressed: _login,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Divider + Biometric Button (solo si hay biometría)
              if (_canUseBiometrics) ...[
                // Divider con texto
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'O',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Botón de Biometric Login
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _checkBiometricAndNavigate,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppColors.primaryColor, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.fingerprint,
                            size: 24,
                            color: AppColors.primaryColor,
                          ),
                          label: const Text(
                            'LOGIN CON BIOMETRÍA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Badge del método biométrico
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '📱 Disponible: $_biometricMethod',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],

              // Footer
              Text(
                '© ${DateTime.now().year} Grupo Solsumed, CA',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}