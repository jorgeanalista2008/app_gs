import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../models/lote_model.dart'; // Necesitas crear este modelo
import '../molecules/lote_verify_card.dart';

class DriverScannerPage extends StatefulWidget {
  const DriverScannerPage({super.key});

  @override
  State<DriverScannerPage> createState() => _DriverScannerState();
}

class _DriverScannerState extends State<DriverScannerPage> {
  LoteModel? currentLote;
  bool isLoadingLote = false;
  bool isVerified = false;
  String currentLocation = "Buscando GPS...";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Lotes'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. ESCÁNER DE CÓDIGOS
          MobileScanner(
            onDetect: (BarcodeCapture capture) async {
              final String code = capture.barcodes.first.rawValue ?? '';
              if (code.isNotEmpty) {
                _fetchLoteDetails(code);
              }
            },
          ),
          
          // 2. OVERLAY DE VERIFICACIÓN (SOLO SI HAY UN LOTE)
          if (currentLote != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54, // Fondo oscuro semitransparente
                child: ListView(
                  padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // TARJETA DE VERIFICACIÓN
                    LoteVerifyCard(
                      lote: currentLote!,
                      isVerified: isVerified,
                      onVerify: _verifyLote,
                    ),

                    const SizedBox(height: 30),
                    
                    // DETALLES
                    // Text("Ubicación registrada", style: TextStyle(fontSize: 14, color: Colors.white70)),
                    Text(currentLocation, style: TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // FUNCIÓN RECIBIR DATOS Y VERIFICAR
  Future<void> _fetchLoteDetails(String code) async {
    setState(() => isLoadingLote = true);
    try {
      final response = await http.get(
        Uri.parse('https://app.grupo-solsumed.com/api/get_lote_details.php?loteId=$code'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            currentLote = LoteModel.fromJson(jsonResponse['data']);
            isLoadingLote = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonResponse['message'] ?? 'Lote no encontrado'),
            backgroundColor: Colors.redAccent,
          ));

          setState(() => isLoadingLote = false);
        }
      }
    } catch (e) {
      setState(() => isLoadingLote = false);
      // print(e);
    }
  }

  // --- LA FUNCIÓN QUE TE DABA EL ERROR (AHORA ASEGÚRATE QUE EXISTA)
  
  // Función para obtener posición actual
  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // --- LÓGICA DE VERIFICACIÓN ---

  void _verifyLote() async {
    // 1. Obtener Ubicación
    final position = await _getCurrentPosition();
    
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación GPS')),
      );
      return;
    }

    // 2. Guardar Datos Localmente (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    
    // Formateamos la hora actual
    final timeNow = DateTime.now();
    final timeStr = "${timeNow.hour}:${timeNow.minute.toString().padLeft(2, '0')}";

    // Creamos el objeto de datos
    final verificationData = {
      'loteId': currentLote!.id,
      'loteTitle': currentLote!.title,
      'lat': position.latitude,
      'lng': position.longitude,
      'verifiedAt': timeStr
    };

    // Guardamos para enviarlo luego a tu PHP
    await prefs.setString('last_verified_lote', jsonEncode(verificationData));

    // 3. Actualizar la UI (Muestra check verde y ubicación)
    setState(() {
      isVerified = true;
      currentLocation = "Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}";
    });
  }
}