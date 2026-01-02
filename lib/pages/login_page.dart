import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    String usuario = _userController.text;
    String password = _passController.text;

    if (usuario.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingrese usuario y contraseña.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://app.grupo-solsumed.com/admin/index.php?action=mlogin');
      final response = await http.post(
        url,
        body: jsonEncode({'email': usuario, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          final data = responseData['data'];
          prefs.setString('user_role', data['rol'].toString());
          prefs.setString('user_name', data['nombre']);
          prefs.setString('user_photo', data['foto'] ?? '');

          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
        } else {
          String mensaje = responseData['message'] ?? 'Error desconocido';
          if (mensaje.contains("desactivado")) mensaje = "Su cuenta está desactivada.";
          if (mensaje.contains("incorrectos")) mensaje = "Usuario o contraseña incorrectos.";
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: AppColors.errorColor));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de comunicación con el servidor.')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.business, size: 120, color: AppColors.primaryColor)),
              const SizedBox(height: 20),
              const Text('Grupo Solsumed, CA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
              const SizedBox(height: 10),
              Text('Iniciar Sesión', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: AppColors.cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  children: [
                    AppTextField(controller: _userController, labelText: 'Usuario', hintText: 'Ingresa tu usuario', icon: Icons.person),
                    const SizedBox(height: 20),
                    AppTextField(controller: _passController, labelText: 'Contraseña', hintText: '••••••••', obscureText: true, icon: Icons.lock),
                    const SizedBox(height: 30),
                    AppButton(text: 'INGRESAR', onPressed: _login, isLoading: _isLoading),
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