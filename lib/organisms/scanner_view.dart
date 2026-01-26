// organisms/scanner_view.dart - Versión simplificada
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class ScannerView extends StatefulWidget {
  final Function(String) onCodeScanned;
  final Function(String) onError;
  
  const ScannerView({
    required this.onCodeScanned,
    required this.onError,
    super.key,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  MobileScannerController? _controller;
  Timer? _debounceTimer;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }
  
  void _initializeScanner() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return MobileScanner(
      controller: _controller!,
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        if (barcodes.isEmpty) return;
        
        final barcode = barcodes.first;
        if (barcode.rawValue == null) return;
        
        final String code = barcode.rawValue!;
        
        // Evitar escanear el mismo código múltiples veces
        if (_lastScannedCode == code) return;
        _lastScannedCode = code;
        
        print('📷 Código detectado en ScannerView: $code');
        
        // Usar debouncer
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
          // Usar post-frame para evitar setState durante build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              widget.onCodeScanned(code);
            } catch (e) {
              widget.onError('Error procesando código: $e');
            }
          });
        });
      },
    );
  }
}