import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../services/location_service.dart';
import '../atoms/photo_capture_widget.dart';
import '../atoms/app_button.dart';

class EncuestaPage extends StatefulWidget {
  final VisitaModel visita;

  const EncuestaPage({super.key, required this.visita});

  @override
  State<EncuestaPage> createState() => _EncuestaPageState();
}

class _EncuestaPageState extends State<EncuestaPage> {
  final LocationService _locationService = LocationService();
  final _formKey = GlobalKey<FormState>();

  // GPS
  double? _lat;
  double? _lng;
  bool _isLoadingLocation = false;

  // Fotos
  File? _foto1;
  File? _foto2;

  // Estado
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _lat = position?.latitude;
          _lng = position?.longitude;
          _isLoadingLocation = false;
        });

        if (position != null) {
          print('📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _enviarEncuesta() {
    if (_formKey.currentState?.validate() != true) return;

    // Aquí irá la lógica de envío cuando tengamos el endpoint
    print('=== ENVIANDO ENCUESTA ===');
    print('Visita ID: ${widget.visita.id}');
    print('Cliente: ${widget.visita.customerName}');
    print('📍 Lat: $_lat, Lng: $_lng');
    print('📷 Foto 1: ${_foto1?.path ?? "No tomada"}');
    print('📷 Foto 2: ${_foto2?.path ?? "No tomada"}');
    print('==========================');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Encuesta enviada correctamente'),
        backgroundColor: AppColors.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Encuesta de Visita'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── INFORMACIÓN DE LA VISITA ───
              _buildHeaderVisita(),
              const SizedBox(height: 24),

              // ─── UBICACIÓN GPS ───
              _buildGpsSection(),
              const SizedBox(height: 24),

              // ─── PREGUNTAS (Placeholder - Se llenará con la API) ───
              _buildPreguntasPlaceholder(),
              const SizedBox(height: 24),

              // ─── FOTOS ───
              _buildFotosSection(),
              const SizedBox(height: 32),

              // ─── BOTÓN ENVIAR ───
              AppButton(
                text: 'ENVIAR ENCUESTA',
                onPressed: _enviarEncuesta,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header de la visita ───
  Widget _buildHeaderVisita() {
    final visita = widget.visita;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // Avatar del cliente
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryColor.withOpacity(0.1),
            child: Text(
              visita.customerName.isNotEmpty ? visita.customerName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visita.customerName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        visita.city.isNotEmpty ? visita.city : 'Sin ciudad',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'RIF: ${visita.taxId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Pendiente',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sección GPS ───
  Widget _buildGpsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on, color: AppColors.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ubicación actual',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                tooltip: 'Actualizar ubicación',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingLocation)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            )
          else if (_lat != null && _lng != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat: ${_lat!.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lng: ${_lng!.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 10),
                  const Text('No se pudo obtener la ubicación',
                      style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Placeholder de preguntas ───
  Widget _buildPreguntasPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.quiz, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Preguntas de la visita',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Preguntas no disponibles',
                  style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las preguntas se cargarán cuando esté disponible el endpoint',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sección de fotos ───
  Widget _buildFotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.camera_alt, color: AppColors.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Evidencias fotográficas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PhotoCaptureWidget(
                label: 'Foto del local',
                onPhotoTaken: (file) => _foto1 = file,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoCaptureWidget(
                label: 'Foto adicional',
                onPhotoTaken: (file) => _foto2 = file,
              ),
            ),
          ],
        ),
      ],
    );
  }
}