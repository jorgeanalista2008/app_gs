import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_colors.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String? scannedData;
  late final WebViewController webController;
  bool isLoading = true;

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  @override
  Widget build(BuildContext context) {
    if (scannedData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Escanear Codigo QR'),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: MobileScanner(
          onDetect: (BarcodeCapture capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String code = barcodes.first.rawValue ?? '---';
              if (code.isNotEmpty) {
                final position = await _getCurrentLocation();
                double? latitud = position?.latitude;
                double? longitud = position?.longitude;

                setState(() {
                  scannedData = code;
                  webController = WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..setNavigationDelegate(
                      NavigationDelegate(
                        onPageStarted: (String url) => setState(() => isLoading = true),
                        onPageFinished: (String url) => setState(() => isLoading = false),
                      ),
                    )
                    ..loadRequest(Uri.parse('https://app.grupo-solsumed.com/index.php?view=chofer&loteId=$code&lat=$latitud&lng=$longitud'));
                });
              }
            }
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
          child: const Text('Apunte al código QR', style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Lote'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => scannedData = null),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: webController),
            if (isLoading) const Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
          ],
        ),
      );
    }
  }
}