// pages/scanner_page.dart - VERSIÓN CON CONTROLES MEJORADOS
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/lot_model.dart';
import '../services/location_service.dart';
import '../repositories/lot_repository.dart';
import '../molecules/scanner_controls.dart'; // Importamos el nuevo componente
import 'dart:async';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // Variables de estado actualizadas
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
  
  Timer? _debounceTimer;
  String? _lastScannedCode;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controlador con configuración inicial
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _currentCamera,
      torchEnabled: _isFlashOn,
      formats: [BarcodeFormat.qrCode],
      returnImage: false,
    );
    _initializeApp();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }
  
  // Método para reinicializar el scanner con nueva configuración
  void _reinitializeScanner() {
    _scannerController.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _currentCamera,
      torchEnabled: _isFlashOn,
      formats: [BarcodeFormat.qrCode],
      returnImage: false,
    );
    setState(() {}); // Forzar rebuild del scanner
  }
  
  // Alternar flash
  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _scannerController.toggleTorch();
    print('🔦 Flash: ${_isFlashOn ? 'ON' : 'OFF'}');
  }
  
  // Alternar cámara
  void _toggleCamera() {
    setState(() {
      _currentCamera = _currentCamera == CameraFacing.back 
          ? CameraFacing.front 
          : CameraFacing.back;
    });
    _reinitializeScanner();
    print('📷 Cámara cambiada a: ${_currentCamera == CameraFacing.back ? 'trasera' : 'frontal'}');
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
        print('❌ Error: User ID inválido');
        setState(() {
          errorMessage = 'No se encontró el ID de usuario válido. Vuelve a iniciar sesión.';
        });
      } else {
        print('✅ User ID válido: $userId');
      }
    } catch (e) {
      print('❌ Error en inicialización: $e');
      setState(() {
        errorMessage = 'Error inicializando: $e';
        isLoadingUser = false;
      });
    }
  }

  Future<void> _loadLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      print('📍 Ubicación obtenida');
      
      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('⚠️ Error cargando ubicación: $e');
    }
  }

  // Manejar detección de código
  void _handleBarcodeDetected(BarcodeCapture capture) {
    if (_isPaused || isLoading || currentLot != null) return;
    
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
      print('📡 Consultando API para código: $code');
      
      final Map<String, dynamic> apiResponse = await LotRepository().getLotDetails(
        lotId: code,
        userId: userId!,
        lat: currentPosition?.latitude,
        lng: currentPosition?.longitude,
      );
      
      print('📥 Respuesta recibida: success=${apiResponse['success']}');
      
      if (apiResponse['success'] == true) {
        final List<LotModel> paquetes = await _parsePaquetesFromApiResponse(apiResponse, code);
        
        print('✅ Paquetes parseados: ${paquetes.length}');
        
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
          print('🔄 Seleccionando único paquete automáticamente');
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            currentLot = paquetes.first;
          });
        }
        
      } else {
        final errorMsg = apiResponse['message'] ?? 'Error desconocido del servidor';
        print('❌ Error API: $errorMsg');
        
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
          _isPaused = false;
        });
        
        _showSnackbar(errorMsg, Colors.red);
      }
      
    } catch (e, stackTrace) {
      print('❌ Error procesando código: $e');
      print('📋 Stack trace: $stackTrace');
      
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
    String scannedCode
  ) async {
    final List<LotModel> paquetes = [];
    
    try {
      print('🔧 Parseando respuesta...');
      
      final data = apiResponse['data'];
      
      if (data == null) {
        print('⚠️ Data es null');
        return paquetes;
      }
      
      print('📊 Tipo de data: ${data.runtimeType}');
      
      if (data is Map<String, dynamic>) {
        print('📄 Data es un Map con keys: ${data.keys.join(', ')}');
        
        if (data.containsKey('paquetes') && data['paquetes'] is List) {
          final List paquetesData = data['paquetes'] as List;
          print('📦 Encontrados ${paquetesData.length} paquetes');
          
          for (var i = 0; i < paquetesData.length; i++) {
            final paqueteData = paquetesData[i];
            
            if (paqueteData is Map<String, dynamic>) {
              print('📦 Procesando paquete $i: ${paqueteData['id']}');
              
              List<String> facturasList = [];
              String facturasTexto = '';
              
              if (paqueteData['facturas'] is List) {
                facturasList = List<String>.from(
                  paqueteData['facturas'].map((f) => f.toString())
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
              print('✅ Paquete añadido: ${lot.cliente}');
            }
          }
        } else {
          print('⚠️ No se encontró array "paquetes" en la data');
        }
      } else if (data is List) {
        print('📄 Data es una List con ${data.length} elementos');
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            paquetes.add(LotModel(
              id: item['id']?.toString() ?? '0',
              loteId: item['co_lote']?.toString() ?? scannedCode,
              cliente: item['cli_des']?.toString()?.trim() ?? 'Cliente no especificado',
              direccion: 'Dirección por confirmar',
              telefono: 'Teléfono no disponible',
              producto: 'Producto general',
              cantidad: item['numero_paquete'] != null 
                  ? int.tryParse(item['numero_paquete'].toString()) ?? 1 
                  : 1,
              estado: item['estatus']?.toString() == '1' ? 'Pendiente' : 'Procesado',
              fechaEntrega: item['fecha_despacho']?.toString(),
              latitud: currentPosition?.latitude,
              longitud: currentPosition?.longitude,
              observaciones: item['facturas_texto']?.toString() ?? '',
            ));
          }
        }
      } else {
        print('⚠️ Tipo de data no reconocido: ${data.runtimeType}');
      }
      
    } catch (e) {
      print('❌ Error en parsePaquetesFromApiResponse: $e');
      print('📦 Respuesta completa: $apiResponse');
      
      paquetes.add(LotModel(
        id: '0',
        loteId: scannedCode,
        cliente: 'Error al procesar datos',
        direccion: 'Contacte al administrador',
        telefono: 'N/A',
        producto: 'Error en datos',
        cantidad: 0,
        estado: 'Error',
        fechaEntrega: null,
        latitud: currentPosition?.latitude,
        longitud: currentPosition?.longitude,
        observaciones: 'Error de parseo: $e',
      ));
    }
    
    print('📊 Total de paquetes parseados: ${paquetes.length}');
    return paquetes;
  }

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
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/login', 
      (route) => false
    );
  }

  void _returnToScanner() {
    setState(() {
      currentLot = null;
      paquetesEncontrados.clear();
      errorMessage = null;
      _lastScannedCode = null;
      _isPaused = false;
    });
  }

  void _selectPaquete(LotModel paquete) {
    setState(() {
      currentLot = paquete;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentLot != null) {
      return _buildDetailView();
    }
    
    if (paquetesEncontrados.isNotEmpty) {
      return _buildPackageSelectionView();
    }
    
    if (isLoadingUser) {
      return _buildLoadingView('Inicializando aplicación...');
    }
    
    if (userId == null || userId!.isEmpty || userId == '0') {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear QR')),
        body: _buildNoUserIdView(),
      );
    }
    
    return _buildScannerView();
  }

  Widget _buildLoadingView(String message) {
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

  Widget _buildScannerView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        actions: [
          
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
          ),
          
          // Controles del scanner en la parte superior
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ScannerControls(
                isFlashOn: _isFlashOn,
                onToggleFlash: _toggleFlash,
                onToggleCamera: _toggleCamera,
              ),
            ),
          ),
          
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Consultando paquetes...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          
          // Mensaje de ayuda en la parte inferior
          if (!isLoading && !_isPaused)
            Positioned(
              bottom: 100, // Subido un poco para dejar espacio a más controles
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _buildHelpMessage(),
                  const SizedBox(height: 20),
                  // Botones adicionales en la parte inferior
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBottomButton(
                          icon: Icons.info_outline,
                          label: 'Instrucciones',
                          onPressed: _showInstructions,
                        ),
                        _buildBottomButton(
                          icon: Icons.history,
                          label: 'Historial',
                          onPressed: _showHistory,
                        ),
                        _buildBottomButton(
                          icon: Icons.settings,
                          label: 'Ajustes',
                          onPressed: _showSettings,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Información de debug
          if (userId != null && !isLoading)
            Positioned(
              top: 80, // Bajado para no interferir con controles
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'User: ${userId!.substring(0, min(3, userId!.length))}...',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    if (currentPosition != null)
                      Text(
                        '📍 ${currentPosition!.latitude.toStringAsFixed(2)}, '
                        '${currentPosition!.longitude.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 8),
                      ),
                    Text(
                      _isPaused ? '⏸️ Pausado' : '▶️ Activo',
                      style: TextStyle(
                        color: _isPaused ? Colors.orange : Colors.green,
                        fontSize: 8,
                      ),
                    ),
                    Text(
                      'Cámara: ${_currentCamera == CameraFacing.back ? 'Trasera' : 'Frontal'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.6),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instrucciones de Escaneo'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Asegúrate de tener buena iluminación'),
              SizedBox(height: 8),
              Text('2. Mantén el código QR estable'),
              SizedBox(height: 8),
              Text('3. Acerca la cámara lo suficiente'),
              SizedBox(height: 8),
              Text('4. Usa el flash en ambientes oscuros'),
              SizedBox(height: 8),
              Text('5. Espera el sonido de confirmación'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    _showSnackbar('Función de historial en desarrollo', Colors.blue);
  }

  void _showSettings() {
    _showSnackbar('Función de ajustes en desarrollo', Colors.blue);
  }

  Widget _buildPackageSelectionView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToScanner,
        ),
        title: Text('${paquetesEncontrados.length} Paquete${paquetesEncontrados.length > 1 ? 's' : ''} Encontrados'),
      ),
      body: paquetesEncontrados.isEmpty
          ? const Center(child: Text('No se encontraron paquetes'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: paquetesEncontrados.length,
              itemBuilder: (context, index) {
                final paquete = paquetesEncontrados[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: paquete.estado == 'Pendiente' 
                          ? Colors.orange 
                          : Colors.green,
                      child: Text(
                        (index + 1).toString(),
                        style: const TextStyle(color: Colors.white),
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
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectPaquete(paquete),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHelpMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            'Apunte al código QR del paquete',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Use el flash en ambientes oscuros',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
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
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Usuario no autenticado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
    if (currentLot == null) return _buildScannerView();
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToScanner,
        ),
        title: Text('Paquete ${currentLot!.cantidad} - ${currentLot!.cliente}'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (currentLot != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lote: ${currentLot!.loteId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (currentLot!.codigoCliente != null)
                      _buildInfoRow('Código Cliente', currentLot!.codigoCliente!),
                    _buildInfoRow('Cliente', currentLot!.cliente),
                    if (currentLot!.fechaEntrega != null)
                      _buildInfoRow('Fecha de embarque', currentLot!.fechaEntrega!),
                    _buildInfoRow('Bultos', currentLot!.producto),
                    _buildInfoRow('Estado', currentLot!.estado),
                    if (currentLot!.observaciones.isNotEmpty)
                      _buildInfoRow('Facturas', currentLot!.observaciones),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _verifyDelivery(),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirmar Entrega'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información de sesión:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Usuario ID: $userId'),
                      if (currentPosition != null)
                        Text(
                          '📍 Ubicación: ${currentPosition!.latitude.toStringAsFixed(4)}, '
                          '${currentPosition!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _returnToScanner,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Escanear otro código'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

// En scanner_page.dart - Método simplificado y robusto
Future<void> _verifyDelivery() async {
  if (userId == null || userId!.isEmpty) {
    _showSnackbar('Usuario no autenticado', Colors.red);
    return;
  }
  
  if (currentLot == null) {
    _showSnackbar('No hay paquete seleccionado', Colors.red);
    return;
  }
  
  // Verificar estado
  if (_isDelivered(currentLot!.estado)) {
    _showSnackbar('Este paquete ya fue entregado', Colors.orange);
    return;
  }
  
  // Diálogo simple de confirmación
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // Mostrar loading
  setState(() => isLoading = true);
  
  try {
    print('🔄 Enviando confirmación de entrega...');
    
    // Usar el método alternativo que es más seguro
    bool success = await LotRepository().verifyDeliveryAlt(
      lotId: currentLot!.loteId,
      userId: userId!,
      lat: currentPosition?.latitude ?? 0.0,
      lng: currentPosition?.longitude ?? 0.0,
      observations: currentLot!.observaciones,
      paqueteId: currentLot!.id,
    );
    
    if (success) {
      print('✅ Entrega confirmada!');
      
      setState(() {
        currentLot = currentLot!.copyWith(estado: 'entregado');
        isLoading = false;
      });
      
      _showSnackbar('✅ Entrega confirmada exitosamente', Colors.green);
      
      // Volver al scanner después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _returnToScanner();
      });
      
    } else {
      setState(() => isLoading = false);
      _showSnackbar('Error al confirmar la entrega', Colors.red);
    }
    
  } catch (e) {
    print('❌ Error: $e');
    setState(() => isLoading = false);
    _showSnackbar('Error: ${e.toString().split(':').first}', Colors.red);
  }
}

bool _isDelivered(String estado) {
  final estadoLower = estado.toLowerCase();
  return estadoLower.contains('entregado') || 
         estadoLower.contains('procesado') || 
         estadoLower == '1'; // También verificar si es "1" (que podría ser el estado en BD)
}

bool _isAlreadyDelivered(String estado) {
  final estadoLower = estado.toLowerCase();
  return estadoLower.contains('entregado') || 
         estadoLower.contains('procesado') || 
         estadoLower.contains('completado');
}

Widget _buildDeliveryInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

String _truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

String _getErrorMessage(dynamic e) {
  final error = e.toString();
  if (error.contains('timeout')) return 'Tiempo de espera agotado';
  if (error.contains('SocketException')) return 'Error de conexión';
  if (error.contains('Failed host lookup')) return 'No hay conexión a internet';
  return 'Error: ${e.toString().split(':').first}';
}

void _showDeliverySuccessScreen() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Entrega Confirmada!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lote: ${currentLot!.loteId}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Paquete: ${currentLot!.producto}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 24),
                  SizedBox(height: 8),
                  Text(
                    'La entrega ha sido registrada en el sistema.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _returnToScanner();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Siguiente'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Aquí podrías navegar a un historial si lo implementas
              },
              child: const Text('Ver Historial'),
            ),
          ],
        ),
      ),
    ),
  );
}
}

int min(int a, int b) => a < b ? a : b;