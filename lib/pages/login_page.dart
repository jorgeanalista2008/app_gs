import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import 'home_page.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

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
      final loginResponse = await _authService.login(usuario, password);
      
      setState(() => _isLoading = false);

      // Debug
      print('=== LOGIN EXITOSO ===');
      print('Token: ${loginResponse.accessToken}');
      print('Usuario: ${loginResponse.user.fullName}');
      print('Rol: ${loginResponse.user.role.name}');
      print('Menús: ${loginResponse.user.menus.length}');
      print('=====================');

      // Navegar sin verificar status
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String mensaje = e.toString().replaceFirst('Exception: ', '');
      
      if (mensaje.contains('invalid credentials') || mensaje.contains('incorrectos')) {
        mensaje = 'Usuario o contraseña incorrectos.';
      } else if (mensaje.contains('desactivado') || mensaje.contains('disabled')) {
        mensaje = 'Su cuenta está desactivada.';
      } else if (mensaje.contains('SocketException') || mensaje.contains('timeout')) {
        mensaje = 'Error de conexión. Verifique su internet.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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
      backgroundColor: AppColors.backgroundColor ?? Colors.grey[100],
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
                    color: AppColors.primaryColor.withOpacity(0.1),
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
                      color: Colors.black.withOpacity(0.05),
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
                      hintText: 'Ingresa tu usuario o email',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
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