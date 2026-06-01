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
  final _cityCtrl = TextEditingController();
  final _zoneCodeCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _fetchingGps = false;
  DateTime? _nextFollowupDate;
  String? _photo1Base64;
  String? _photo2Base64;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _notesCtrl.dispose();
    _contactNameCtrl.dispose();
    _cityCtrl.dispose();
    _zoneCodeCtrl.dispose();
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
        city: _cityCtrl.text.trim(),
        zoneCode: _zoneCodeCtrl.text.trim(),
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
              AppTextField(
                controller: _cityCtrl,
                labelText: 'Ciudad',
                hintText: 'Caracas, Maracaibo...',
                icon: Icons.location_city,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _zoneCodeCtrl,
                labelText: 'Código de Zona (ej: VE-MI)',
                hintText: 'VE-MI',
                icon: Icons.map,
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
