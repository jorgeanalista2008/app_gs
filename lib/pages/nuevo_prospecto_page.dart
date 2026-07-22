import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_colors.dart';
import '../repositories/cliente_repository.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import '../atoms/photo_capture_widget.dart';

class NuevoProspectoPage extends StatefulWidget {
  const NuevoProspectoPage({super.key});

  @override
  State<NuevoProspectoPage> createState() => _NuevoProspectoPageState();
}

class _NuevoProspectoPageState extends State<NuevoProspectoPage> {
  final _formKey = GlobalKey<FormState>();
  final _clienteRepo = ClienteRepository();

  final _nameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _fetchingGps = false;
  DateTime? _nextFollowupDate;
  String? _photo1Base64;
  String? _photo2Base64;
  String? _selectedZoneCode;
  String? _selectedCity;

  static const Map<String, List<String>> _ciudadesPorZona = {
    "VE-AM": ["Puerto Ayacucho", "San Fernando de Atabapo", "Maroa", "San Carlos de Río Negro"],
    "VE-AN": ["Barcelona", "Puerto La Cruz", "El Tigre", "Anaco", "Cantaura", "San José de Guanipa", "Guanta", "Clarines", "Aragua de Barcelona", "Pariaguán"],
    "VE-AP": ["San Fernando de Apure", "Guasdualito", "Elorza", "Achaguas", "Biruaca", "San Juan de Payara"],
    "VE-AR": ["Maracay", "Turmero", "La Victoria", "Cagua", "El Limón", "Villa de Cura", "Santa Cruz", "San Mateo", "Palo Negro", "Las Tejerías"],
    "VE-BA": ["Barinas", "Socopó", "Barinitas", "Sabaneta", "Ciudad Bolivia", "Santa Bárbara de Barinas", "Obispos"],
    "VE-BO": ["Ciudad Guayana (Puerto Ordaz)", "Ciudad Bolívar", "Upata", "Tumeremo", "Guasipati", "El Callao", "Caicara del Orinoco", "Santa Elena de Uairén"],
    "VE-CA": ["Valencia", "Naguanagua", "San Diego", "Puerto Cabello", "Guacara", "Tocuyito", "San Joaquín", "Mariara", "Morón", "Bejuma", "Güigüe"],
    "VE-CO": ["San Carlos", "Tinaquillo", "El Baúl", "Tinaco", "El Pao"],
    "VE-DA": ["Tucupita", "Pedernales", "Curiapo"],
    "VE-DC": ["Caracas", "El Junquito"],
    "VE-FA": ["Punto Fijo", "Coro", "Chichiriviche", "Tucacas", "La Vela de Coro", "Dabajuro", "Santa Cruz de Bucaral", "Píritu"],
    "VE-GU": ["San Juan de los Morros", "Valle de la Pascua", "Calabozo", "Altagracia de Orituco", "Zaraza", "El Socorro", "Camaguán"],
    "VE-LG": ["Catia La Mar", "La Guaira", "Maiquetía", "Caraballeda", "Macuto", "Naiguatá", "Carayaca"],
    "VE-LA": ["Barquisimeto", "Cabudare", "Carora", "El Tocuyo", "Quíbor", "Duaca", "Siquisique", "Sanare"],
    "VE-ME": ["Mérida", "El Vigía", "Ejido", "Tovar", "Nueva Bolivia", "Mucuchíes", "Lagunillas", "Bailadores"],
    "VE-MI": ["Los Teques", "Chacao", "Petare", "Baruta", "Guarenas", "Guatire", "Charallave", "Cúa", "Ocumare del Tuy", "Higuerote", "San Antonio de los Altos", "Río Chico", "Santa Teresa del Tuy", "Santa Lucía"],
    "VE-MO": ["Maturín", "Punta de Mata", "Caripe", "Caripito", "Temblador", "Caicara de Maturín", "Aragua de Maturín"],
    "VE-NE": ["Porlamar", "Pampatar", "La Asunción", "Juan Griego", "San Juan Bautista", "Punta de Piedras", "El Valle del Espíritu Santo"],
    "VE-PO": ["Acarigua", "Araure", "Guanare", "Turén", "Villa Bruzual", "Boconó", "Ospino", "Chabasquén"],
    "VE-SU": ["Cumaná", "Carúpano", "Güiria", "Cariaco", "El Pilar", "Río Caribe", "Araya"],
    "VE-TA": ["San Cristóbal", "Táriba", "Rubio", "San Antonio del Táchira", "La Grita", "Michelena", "Ureña", "Colón", "Lobatera"],
    "VE-TR": ["Valera", "Trujillo", "Boconó", "Sabana de Mendoza", "Carache", "Pampán", "Escuque", "La Puerta"],
    "VE-YA": ["San Felipe", "Yaritagua", "Chivacoa", "Nirgua", "Cocorote", "Urachiche", "Bruzual"],
    "VE-ZU": ["Maracaibo", "San Francisco", "Cabimas", "Ciudad Ojeda", "Machiques", "Santa Bárbara del Zulia", "La Villa del Rosario", "Lagunillas", "Bachaquero", "Mene Grande", "Puertos de Altagracia", "San Carlos del Zulia"],
    "ZE": ["Ciudad Este", "Pueblo Este"],
    "ZN": ["Ciudad Norte", "Pueblo Norte"],
    "ZS": ["Ciudad Sur", "Pueblo Sur"],
  };

  final List<Map<String, String>> _zonas = const [
    {"profit_code": "VE-AM", "description": "Amazonas"},
    {"profit_code": "VE-AN", "description": "Anzoátegui"},
    {"profit_code": "VE-AP", "description": "Apure"},
    {"profit_code": "VE-AR", "description": "Aragua"},
    {"profit_code": "VE-BA", "description": "Barinas"},
    {"profit_code": "VE-BO", "description": "Bolívar"},
    {"profit_code": "VE-CA", "description": "Carabobo"},
    {"profit_code": "VE-CO", "description": "Cojedes"},
    {"profit_code": "VE-DA", "description": "Delta Amacuro"},
    {"profit_code": "VE-DC", "description": "Distrito Capital"},
    {"profit_code": "VE-FA", "description": "Falcón"},
    {"profit_code": "VE-GU", "description": "Guárico"},
    {"profit_code": "VE-LG", "description": "La Guaira"},
    {"profit_code": "VE-LA", "description": "Lara"},
    {"profit_code": "VE-ME", "description": "Mérida"},
    {"profit_code": "VE-MI", "description": "Miranda"},
    {"profit_code": "VE-MO", "description": "Monagas"},
    {"profit_code": "VE-NE", "description": "Nueva Esparta"},
    {"profit_code": "VE-PO", "description": "Portuguesa"},
    {"profit_code": "VE-SU", "description": "Sucre"},
    {"profit_code": "VE-TA", "description": "Táchira"},
    {"profit_code": "VE-TR", "description": "Trujillo"},
    {"profit_code": "VE-YA", "description": "Yaracuy"},
    {"profit_code": "VE-ZU", "description": "Zulia"},
    {"profit_code": "ZE", "description": "[PRUEBA] Zona Este"},
    {"profit_code": "ZN", "description": "[PRUEBA] Zona Norte"},
    {"profit_code": "ZS", "description": "[PRUEBA] Zona Sur"}
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _notesCtrl.dispose();
    _contactNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarUbicacion() async {
    setState(() => _fetchingGps = true);
    try {
      final servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) {
        _showSnack('GPS deshabilitado', error: true);
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _showSnack('Permiso GPS denegado', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _showSnack('📍 Ubicación capturada');
    } catch (e) {
      _showSnack('Error GPS: $e', error: true);
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _clienteRepo.crearProspecto(
        name: _nameCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        contactName: _contactNameCtrl.text.trim(),
        city: _selectedCity,
        zoneCode: _selectedZoneCode,
        nextFollowupDate: _nextFollowupDate != null 
            ? "${_nextFollowupDate!.year}-${_nextFollowupDate!.month.toString().padLeft(2, '0')}-${_nextFollowupDate!.day.toString().padLeft(2, '0')}"
            : null,
        photo1: _photo1Base64,
        photo2: _photo2Base64,
      );
      if (!mounted) return;
      _showSnack('✅ Prospecto guardado. Se subirá al recuperar conexión.');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Prospecto'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nuevo cliente capturado en campo. Se sincronizará automáticamente cuando haya conexión.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _required(_nameCtrl, 'Nombre / Razón social', Icons.business),
              const SizedBox(height: 12),
              AppTextField(
                controller: _taxIdCtrl,
                labelText: 'RIF / Cédula',
                hintText: 'J-12345678-9',
                icon: Icons.badge,
              ),
              const SizedBox(height: 12),
              _required(_contactNameCtrl, 'Nombre de Contacto', Icons.person),
              const SizedBox(height: 12),
              AppTextField(
                controller: _telefonoCtrl,
                labelText: 'Teléfono',
                hintText: '0414-1234567',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _emailCtrl,
                labelText: 'Email',
                hintText: 'cliente@ejemplo.com',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedZoneCode,
                decoration: const InputDecoration(
                  labelText: 'Zona / Estado',
                  prefixIcon: Icon(Icons.map),
                ),
                hint: const Text(
                  'Selecciona la zona del candidato',
                  overflow: TextOverflow.ellipsis,
                ),
                items: _zonas.map((zona) {
                  return DropdownMenuItem<String>(
                    value: zona['profit_code'],
                    child: Text(
                      zona['description']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedZoneCode = value;
                    _selectedCity = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'Por favor selecciona la zona' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(Icons.location_city),
                ),
                hint: const Text(
                  'Selecciona la ciudad del candidato',
                  overflow: TextOverflow.ellipsis,
                ),
                disabledHint: const Text(
                  'Selecciona una zona/estado primero',
                  overflow: TextOverflow.ellipsis,
                ),
                items: _selectedZoneCode != null && _ciudadesPorZona.containsKey(_selectedZoneCode)
                    ? _ciudadesPorZona[_selectedZoneCode]!.map((ciudad) {
                        return DropdownMenuItem<String>(
                          value: ciudad,
                          child: Text(
                            ciudad,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList()
                    : null,
                onChanged: _selectedZoneCode != null
                    ? (value) {
                        setState(() {
                          _selectedCity = value;
                        });
                      }
                    : null,
                validator: (value) =>
                    _selectedZoneCode != null && value == null ? 'Por favor selecciona la ciudad' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _direccionCtrl,
                labelText: 'Dirección',
                hintText: 'Av. Principal, Edificio…',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: AppColors.primaryColor),
                title: Text(_nextFollowupDate == null 
                    ? 'Fecha de Siguiente Seguimiento'
                    : 'Seguimiento: ${_nextFollowupDate!.day}/${_nextFollowupDate!.month}/${_nextFollowupDate!.year}'),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _nextFollowupDate = picked;
                      });
                    }
                  },
                  child: const Text('Seleccionar'),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notesCtrl,
                labelText: 'Notas',
                hintText: 'Detalles de la visita inicial',
                icon: Icons.notes,
              ),
              const SizedBox(height: 16),
               _ubicacionCard(),
              // Oculto temporalmente para versión futura:
              /*
              const SizedBox(height: 16),
              const Text(
                'Evidencias fotográficas (opcional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PhotoCaptureWidget(
                      label: 'Foto del local',
                      onPhotoTaken: (file, base64) {
                        _photo1Base64 = base64;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PhotoCaptureWidget(
                      label: 'Foto adicional',
                      onPhotoTaken: (file, base64) {
                        _photo2Base64 = base64;
                      },
                    ),
                  ),
                ],
              ),
              */
              const SizedBox(height: 24),
              AppButton(
                text: _saving ? 'Guardando…' : 'Guardar Prospecto',
                isLoading: _saving,
                onPressed: _saving ? () {} : _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _required(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
    );
  }

  Widget _ubicacionCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.gps_fixed,
                    color: _lat != null
                        ? Colors.green
                        : AppColors.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _lat != null
                        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                        : 'Ubicación GPS no capturada',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: _fetchingGps ? null : _capturarUbicacion,
                  icon: _fetchingGps
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_lat != null ? 'Re-capturar' : 'Capturar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
