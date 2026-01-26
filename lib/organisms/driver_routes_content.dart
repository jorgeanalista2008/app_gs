import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../models/shipment_model.dart';
import '../molecules/shipment_row.dart';
import '../pages/login_page.dart'; // Importa la pantalla de Login (ajusta la ruta según tu estructura de carpetas)

class DriverRoutesContent extends StatefulWidget {
  const DriverRoutesContent({super.key});

  @override
  State<DriverRoutesContent> createState() => _DriverRoutesContentState();
}

class _DriverRoutesContentState extends State<DriverRoutesContent> {
  List<ShipmentModel> shipments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    // 1. Obtener el ID del Chofer (Guardado en el Login)
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id'); // Asegúrate de que en `login_page.dart` guardamos 'user_id' como te indiqué antes.

    if (userId == null) {
      setState(() {
        errorMessage = "No se encontró el ID del chofer. Por favor vuelve a iniciar sesión.";
        isLoading = false;
      });
      return;
    }
    try {
      // 2. Llamar a tu PHP nuevo
      final response = await http.get(
        Uri.parse('https://app.grupo-solsumed.com/admin/index.php?action=embarco&tipo=1&accion=2&datos=8&c=VehiculoData&a=1&t=carga&co_chofer=$userId'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> jsonList = jsonResponse['data'] ?? [];
          
          setState(() {
            shipments = jsonList.map((e) => ShipmentModel.fromJson(e)).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonResponse['message'];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Error de conexión al servidor.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Método para refrescar la lista (ej: si se acaba de entregar un envío nuevo)
  Future<void> refreshRoutes() async {
    await _loadRoutes();
    
    // Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lista actualizada'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (errorMessage != null && shipments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(errorMessage!, style: const TextStyle(fontSize: 16),
        ),
      ));
    }

    if (shipments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No tienes envíos asignados.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            ElevatedButton(
              onPressed: () {
                 // OPCIONAL: Aquí podrías poner un botón para que refrescar manualmente o volver al Login
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()), // Asegúrate de importar tu página de Login aquí
              );
            },
              child: const Text('Volver a Login'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(15), // Padding global
        itemCount: shipments.length,
        itemBuilder: (context, index) {
          return ShipmentRow(shipment: shipments[index]);
        },
      ),
    );
  }
}