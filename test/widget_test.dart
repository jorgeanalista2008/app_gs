import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Colores Corporativos
  static const primaryColor = Color(0xFF01579B);
  static const secondaryColor = Color(0xFF0288D1);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grupo Solsumed Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 2)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// PANTALLA 1: LOGIN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

    setState(() { _isLoading = true; });

    try {
      final url = Uri.parse('https://app.grupo-solsumed.com/admin/index.php?action=mlogin');
      final response = await http.post(url, body: jsonEncode({'email': usuario, 'password': password}), headers: {'Content-Type': 'application/json'});

      setState(() { _isLoading = false; });

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          final data = responseData['data'];
          prefs.setString('user_role', data['rol'].toString());
          prefs.setString('user_name', data['nombre']);
          prefs.setString('user_photo', data['foto'] ?? '');

          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['message'] ?? 'Error de login'), backgroundColor: Colors.red));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión')));
      }
    } catch (e) {
      setState(() { _isLoading = false; });
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
              Image.asset('assets/logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.business, size: 120, color: MyApp.primaryColor)),
              const SizedBox(height: 20),
              const Text('Grupo Solsumed, CA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                child: Column(
                  children: [
                    TextField(controller: _userController, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 20),
                    TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock))),
                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _login, style: ElevatedButton.styleFrom(backgroundColor: _isLoading ? Colors.grey : MyApp.primaryColor), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('INGRESAR'))),
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

// ==========================================
// PANTALLA 2: HOME (DASHBOARD + MENU)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  String? _userRole;
  String? _userPhoto;

  @override
  void initState() { super.initState(); _loadUserData(); }
  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _userRole = prefs.getString('user_role');
      _userPhoto = prefs.getString('user_photo');
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _goToScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: MyApp.primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            accountName: Text(_userName ?? 'Cargando...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text("Rol: ${_getRoleName(_userRole)}"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: _userPhoto != null && _userPhoto!.isNotEmpty
                  ? ClipOval(child: Image.network(_userPhoto!, fit: BoxFit.cover))
                  : Text(_userName != null ? _userName![0].toUpperCase() : 'U', style: const TextStyle(fontSize: 40, color: MyApp.primaryColor)),
            ),
            decoration: const BoxDecoration(color: MyApp.primaryColor),
          ),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard'), onTap: () { Navigator.pop(context); }), // Actualiza la vista actual si quisieras
          ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('Escanear Códigos'), onTap: () { Navigator.pop(context); _goToScanner(); }),
          if (_userRole == '1' || _userRole == '3') ListTile(leading: const Icon(Icons.assessment), title: const Text('Reportes'), onTap: () { Navigator.pop(context); }),
          if (_userRole == '5') ListTile(leading: const Icon(Icons.local_shipping), title: const Text('Mis Rutas'), onTap: () { Navigator.pop(context); }),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _logout(); }),
        ]),
      ),
      body: _buildDashboardContent(),
    );
  }

  // --- CONSTRUCTOR DEL DASHBOARD ---
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saludo
          Text('Hola, $_userName 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Resumen de actividad', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 30),

          // Grid de Estadísticas (Placeholders de datos reales)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.9, // Aspecto rectangular vertical
            children: [
              _buildStatCard('Pedidos Pendientes', '12', Icons.inventory_2, Colors.orangeAccent),
              _buildStatCard('Rutas Hoy', '3', Icons.local_shipping, Colors.greenAccent),
            ],
          ),
          
          const SizedBox(height: 30),

          // ACCIÓN PRINCIPAL: ESCÁNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15)],
            ),
            child: Column(
              children: [
                const Text('Acciones Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _goToScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Text('ESCANEAR CÓDIGO DE BARRAS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyApp.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color, size: 30)),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case '1': return 'Administrador';
      case '2': return 'Vendedor';
      case '3': return 'Gerente';
      case '5': return 'Chofer';
      default: return 'Usuario';
    }
  }
}

// ==========================================
// PANTALLA 3: ESCÁNER (PANTALLA INDIVIDUAL)
// ==========================================
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
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
      // MODO CÁMARA
      return Scaffold(
        appBar: AppBar(
          title: const Text('Escanear Pedido'),
          backgroundColor: MyApp.primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
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
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
          child: const Text('Apunte al código de barras', style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      );
    } else {
      // MODO WEBVIEW
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Producto'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => scannedData = null); // Volver a escanear
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: webController),
            if (isLoading) const Center(child: CircularProgressIndicator(color: MyApp.primaryColor)),
          ],
        ),
      );
    }
  }
}