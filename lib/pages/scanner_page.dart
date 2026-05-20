// pages/scanner_page.dart - VERSIÓN ACTUALIZADA CON DISEÑO ESTÉTICO
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/lot_model.dart';
import '../services/location_service.dart';
import '../services/image_qr_service.dart';
import '../repositories/lot_repository.dart';
import '../molecules/scanner_controls.dart';
import '../molecules/image_scan_fab.dart';
import '../core/app_colors.dart';
import 'dart:async';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // Variables de estado
  LotModel? currentLot;
  List<LotModel> paquetesEncontrados = [];
  bool isLoading = false;
  bool isLoadingUser = true;
  Position? currentPosition;
  String? userId;
  String? errorMessage;

  // Controlador del scanner
  late MobileScannerController _scannerController;

  // Variables para controles
  bool _isFlashOn = false;
  CameraFacing _currentCamera = CameraFacing.back;

  // Variables para debounce
  Timer? _debounceTimer;
  String? _lastScannedCode;
  bool _isPaused = false;

  // Servicio de escaneo desde imagen
  final ImageQrService _imageQrService = ImageQrService();
  bool _isProcessingImage = false;
  String? _lastProcessedImagePath;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _currentCamera,
      torchEnabled: _isFlashOn,
    );
    _initializeApp();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _reinitializeScanner() {
    _scannerController.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _currentCamera,
      torchEnabled: _isFlashOn,
    );
    setState(() {});
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _scannerController.toggleTorch();
    print('🔦 Flash: ${_isFlashOn ? 'ON' : 'OFF'}');
  }

  void _toggleCamera() {
    setState(() {
      _currentCamera = _currentCamera == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
    _reinitializeScanner();
    print('📷 Cámara cambiada');
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedUserId = prefs.getString('user_id');

      print('📱 User ID cargado: $loadedUserId');

      _loadLocation();

      setState(() {
        userId = loadedUserId;
        isLoadingUser = false;
      });

      if (userId == null || userId!.isEmpty || userId == '0') {
        setState(() {
          errorMessage = 'No se encontró el ID de usuario válido. Vuelve a iniciar sesión.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error inicializando: $e';
        isLoadingUser = false;
      });
    }
  }

  Future<void> _loadLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('⚠️ Error cargando ubicación: $e');
    }
  }

  // ==================== ESCANEO EN TIEMPO REAL ====================

  void _handleBarcodeDetected(BarcodeCapture capture) {
    if (_isPaused || isLoading || currentLot != null || _isProcessingImage) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    final String code = barcode.rawValue!;

    if (_lastScannedCode == code) return;
    _lastScannedCode = code;

    print('📷 Código detectado: $code');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _isPaused || isLoading || currentLot != null) return;
      _processScannedCode(code);
    });
  }

  // ==================== ESCANEO DESDE IMAGEN ====================

  Future<void> _scanFromCamera() async {
    if (_isProcessingImage || isLoading) return;

    setState(() => _isProcessingImage = true);

    try {
      final result = await _imageQrService.takePhotoAndScan();
      _handleImageScanResult(result);
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  Future<void> _scanFromGallery() async {
    if (_isProcessingImage || isLoading) return;

    setState(() => _isProcessingImage = true);

    try {
      final result = await _imageQrService.pickFromGalleryAndScan();
      _handleImageScanResult(result);
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  void _handleImageScanResult(QrScanResult result) {
    switch (result.status) {
      case QrScanStatus.success:
        print('✅ QR desde imagen: ${result.code}');
        _lastProcessedImagePath = result.imagePath;
        _showSnackbar('QR detectado desde imagen', Colors.green);
        _processScannedCode(result.code!);
        break;

      case QrScanStatus.noQrFound:
        _showNoQrFoundDialog(result.imagePath);
        break;

      case QrScanStatus.cancelled:
        // Usuario canceló
        break;

      case QrScanStatus.error:
        _showSnackbar('Error: ${result.errorMessage}', Colors.red);
        break;
    }
  }

  void _showNoQrFoundDialog(String? imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('QR no detectado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(
                        imagePath,
                        height: 150,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(imagePath),
                        height: 150,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'No se encontró ningún código QR en esta imagen.\n\n'
              'Asegúrate de que:\n'
              '• El QR esté bien enfocado\n'
              '• Tenga buena iluminación\n'
              '• No esté recortado',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _scanFromCamera();
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Intentar de nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROCESAMIENTO DE CÓDIGO ====================

  Future<void> _processScannedCode(String code) async {
    if (userId == null || userId!.isEmpty || userId == '0') {
      _showSnackbar('Usuario no autenticado. Vuelve a iniciar sesión.', Colors.red);
      return;
    }

    if (code.isEmpty || code.length < 3) {
      _showSnackbar('Código escaneado inválido', Colors.orange);
      return;
    }

    print('🔄 Procesando código: $code');

    _isPaused = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
      paquetesEncontrados.clear();
    });

    try {
      final Map<String, dynamic> apiResponse = await LotRepository().getLotDetails(
        lotId: code,
        userId: userId!,
        lat: currentPosition?.latitude,
        lng: currentPosition?.longitude,
      );

      if (apiResponse['success'] == true) {
        final List<LotModel> paquetes = await _parsePaquetesFromApiResponse(apiResponse, code);

        if (paquetes.isEmpty) {
          _showSnackbar('No se encontraron paquetes para este código', Colors.orange);
          setState(() {
            isLoading = false;
            _isPaused = false;
          });
          return;
        }

        setState(() {
          paquetesEncontrados = paquetes;
          isLoading = false;
        });

        if (paquetes.length == 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            currentLot = paquetes.first;
          });
        }

      } else {
        final errorMsg = apiResponse['message'] ?? 'Error desconocido del servidor';
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
          _isPaused = false;
        });
        _showSnackbar(errorMsg, Colors.red);
      }

    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        _isPaused = false;
      });
      _showSnackbar('Error al consultar: $e', Colors.red);
    }
  }

  Future<List<LotModel>> _parsePaquetesFromApiResponse(
    Map<String, dynamic> apiResponse,
    String scannedCode,
  ) async {
    final List<LotModel> paquetes = [];

    try {
      final data = apiResponse['data'];

      if (data is Map<String, dynamic> && data.containsKey('paquetes')) {
        final List paquetesData = data['paquetes'] as List;

        for (var paqueteData in paquetesData) {
          if (paqueteData is Map<String, dynamic>) {
            List<String> facturasList = [];
            String facturasTexto = '';

            if (paqueteData['facturas'] is List) {
              facturasList = List<String>.from(
                paqueteData['facturas'].map((f) => f.toString()),
              );
              facturasTexto = facturasList.join(', ');
            } else if (paqueteData['facturas_texto'] != null) {
              facturasTexto = paqueteData['facturas_texto'].toString();
              facturasList = facturasTexto.split(', ').where((f) => f.isNotEmpty).toList();
            }

            String cliente = 'Cliente no especificado';
            if (paqueteData['cli_des'] != null) {
              cliente = paqueteData['cli_des'].toString().trim();
            }

            final lot = LotModel(
              id: paqueteData['id']?.toString() ?? '0',
              loteId: paqueteData['co_lote']?.toString() ?? scannedCode,
              cliente: cliente,
              direccion: 'Dirección por confirmar',
              telefono: 'Teléfono no disponible',
              producto: paqueteData['numero_paquete']?.toString() ?? '0000',
              cantidad: paqueteData['numero_paquete'] != null
                  ? int.tryParse(paqueteData['numero_paquete'].toString()) ?? 1
                  : 1,
              estado: paqueteData['estatus']?.toString() == '1' ? 'Pendiente' : 'Procesado',
              fechaEntrega: paqueteData['fecha_despacho']?.toString(),
              latitud: currentPosition?.latitude,
              longitud: currentPosition?.longitude,
              observaciones: facturasTexto,
              codigoCliente: paqueteData['co_cli']?.toString(),
              codigoVendedor: paqueteData['co_ven']?.toString(),
              qrData: paqueteData['qr_data']?.toString(),
              facturas: facturasList,
              numeroPaquete: paqueteData['numero_paquete']?.toString(),
            );

            paquetes.add(lot);
          }
        }
      }
    } catch (e) {
      print('❌ Error parseando paquetes: $e');
    }

    return paquetes;
  }

  // ==================== UI HELPERS ====================

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _returnToScanner() {
    setState(() {
      currentLot = null;
      paquetesEncontrados.clear();
      errorMessage = null;
      _lastScannedCode = null;
      _lastProcessedImagePath = null;
      _isPaused = false;
    });
  }

  void _selectPaquete(LotModel paquete) {
    setState(() {
      currentLot = paquete;
    });
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (currentLot != null) {
      return _buildDetailView();
    }

    if (paquetesEncontrados.isNotEmpty) {
      return _buildPackageSelectionView();
    }

    if (isLoadingUser) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Inicializando aplicación...'),
            ],
          ),
        ),
      );
    }

    if (userId == null || userId!.isEmpty || userId == '0') {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear QR')),
        body: _buildNoUserIdView(),
      );
    }

    return _buildScannerView();
  }

  Widget _buildScannerView() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Escanear QR',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Historial',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner de cámara (fondo)
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
          ),

          // Gradiente superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Controles del scanner (flash, cámara)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Center(
              child: ScannerControls(
                isFlashOn: _isFlashOn,
                onToggleFlash: _toggleFlash,
               // onToggleCamera: _toggleCamera,
              ),
            ),
          ),

          // Marco de escaneo
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Esquinas decorativas
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildCorner(Alignment.topLeft),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCorner(Alignment.topRight),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCorner(Alignment.bottomLeft),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCorner(Alignment.bottomRight),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      'Consultando paquetes...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Gradiente inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ✅ BOTÓN FLOTANTE CON MENÚ (diseño estético)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            right: 20,
            child: ImageScanFab(
              onCameraTap: _scanFromCamera,
              onGalleryTap: _scanFromGallery,
              isProcessing: _isProcessingImage,
            ),
          ),

          // Mensaje de ayuda
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 0,
            right: 0,
            child: _buildHelpMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    double rotation;
    switch (alignment) {
      case Alignment.topLeft:
        rotation = 0;
        break;
      case Alignment.topRight:
        rotation = 1.5708; // 90 degrees
        break;
      case Alignment.bottomRight:
        rotation = 3.14159; // 180 degrees
        break;
      case Alignment.bottomLeft:
        rotation = 4.71239; // 270 degrees
        break;
      default:
        rotation = 0;
    }

    return Transform.rotate(
      angle: rotation,
      child: ClipRRect(
        child: CustomPaint(
          size: const Size(30, 30),
          painter: CornerPainter(color: AppColors.primaryColor),
        ),
      ),
    );
  }

  Widget _buildHelpMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, color: Colors.white70, size: 20),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Apunta al código QR del paquete',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSelectionView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToScanner,
        ),
        title: Text('${paquetesEncontrados.length} Paquete${paquetesEncontrados.length > 1 ? 's' : ''}'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paquetesEncontrados.length,
        itemBuilder: (context, index) {
          final paquete = paquetesEncontrados[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: paquete.estado == 'Pendiente' ? Colors.orange : Colors.green,
                child: Text(
                  (index + 1).toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                'Paquete ${paquete.cantidad}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Cliente: ${paquete.cliente}'),
                  Text('Estado: ${paquete.estado}'),
                  if (paquete.fechaEntrega != null)
                    Text('Fecha: ${paquete.fechaEntrega!.substring(0, 10)}'),
                  if (paquete.observaciones.isNotEmpty)
                    Text('Facturas: ${paquete.observaciones}'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _selectPaquete(paquete),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoUserIdView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Usuario no autenticado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'No se pudo obtener el ID de usuario.\nPor favor, vuelve a iniciar sesión.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _goToLogin,
              icon: const Icon(Icons.login),
              label: const Text('Ir al Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    if (currentLot == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToScanner,
        ),
        title: Text('Paquete ${currentLot!.cantidad}'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicador si vino de foto
                  if (_lastProcessedImagePath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_camera, color: Colors.blue, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Escaneado desde fotografía',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text(
                    currentLot!.cliente,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lote: ${currentLot!.loteId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildInfoRow('Código Cliente', currentLot!.codigoCliente ?? '-'),
                  _buildInfoRow('Bultos', currentLot!.producto),
                  _buildInfoRow('Estado', currentLot!.estado),
                  if (currentLot!.fechaEntrega != null)
                    _buildInfoRow('Fecha', currentLot!.fechaEntrega!.substring(0, 10)),
                  if (currentLot!.observaciones.isNotEmpty)
                    _buildInfoRow('Facturas', currentLot!.observaciones),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _verifyDelivery(),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirmar Entrega'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _returnToScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear otro código'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIRMAR ENTREGA ====================

  Future<void> _verifyDelivery() async {
    if (userId == null || userId!.isEmpty) {
      _showSnackbar('Usuario no autenticado', Colors.red);
      return;
    }

    if (currentLot == null) {
      _showSnackbar('No hay paquete seleccionado', Colors.red);
      return;
    }

    if (_isDelivered(currentLot!.estado)) {
      _showSnackbar('Este paquete ya fue entregado', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Confirmar entrega de este paquete?'),
            const SizedBox(height: 16),
            Text('Lote: ${currentLot!.loteId}'),
            Text('Paquete: ${currentLot!.producto}'),
            Text('Cliente: ${currentLot!.cliente}'),
            if (currentLot!.observaciones.isNotEmpty)
              Text('Facturas: ${currentLot!.observaciones}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      bool success = await LotRepository().verifyDeliveryAlt(
        lotId: currentLot!.loteId,
        userId: userId!,
        lat: currentPosition?.latitude ?? 0.0,
        lng: currentPosition?.longitude ?? 0.0,
        observations: currentLot!.observaciones,
        paqueteId: currentLot!.id,
      );

      if (success) {
        setState(() {
          currentLot = currentLot!.copyWith(estado: 'entregado');
          isLoading = false;
        });

        _showSnackbar('✅ Entrega confirmada exitosamente', Colors.green);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _returnToScanner();
        });
      } else {
        setState(() => isLoading = false);
        _showSnackbar('Error al confirmar la entrega', Colors.red);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackbar('Error: ${e.toString().split(':').first}', Colors.red);
    }
  }

  bool _isDelivered(String estado) {
    final estadoLower = estado.toLowerCase();
    return estadoLower.contains('entregado') ||
        estadoLower.contains('procesado') ||
        estadoLower == '1';
  }
}

// Painter para las esquinas del marco de escaneo
class CornerPainter extends CustomPainter {
  final Color color;

  CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CornerPainter oldDelegate) => oldDelegate.color != color;
}
