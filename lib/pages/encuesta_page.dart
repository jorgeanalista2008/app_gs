import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../models/encuesta_model.dart';
import '../models/pregunta_model.dart';
import '../repositories/encuesta_repository.dart';
import '../services/location_service.dart';
import '../atoms/photo_capture_widget.dart';
import '../atoms/app_button.dart';

import 'dart:convert';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';
import 'dart:async'; // Para TimeoutException

class EncuestaPage extends StatefulWidget {
  final VisitaModel visita;

  const EncuestaPage({super.key, required this.visita});

  @override
  State<EncuestaPage> createState() => _EncuestaPageState();
}

class _EncuestaPageState extends State<EncuestaPage> {
  final EncuestaRepository _encuestaRepo = EncuestaRepository();
  final _formKey = GlobalKey<FormState>();

  // Encuesta
  EncuestaModel? _encuesta;
  bool _isLoadingEncuesta = true;

  // GPS
  double? _lat;
  double? _lng;
  bool _isLoadingLocation = false;

  // Respuestas
  final Map<String, dynamic> _respuestas = {};

  // Fotos
  File? _foto1;
  File? _foto2;

  // Estado
  bool _isEnviando = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEncuesta();
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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadEncuesta() async {
    setState(() => _isLoadingEncuesta = true);

    try {
      final encuesta = await _encuestaRepo.getEncuesta(widget.visita.id);
      if (mounted) {
        setState(() {
          _encuesta = encuesta;
          _isLoadingEncuesta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEncuesta = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar preguntas: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

 void _enviarEncuesta() async {
  if (_formKey.currentState?.validate() != true) return;

  // Verificar preguntas requeridas
  if (_encuesta != null) {
    for (var pregunta in _encuesta!.questions) {
      if (pregunta.isRequired &&
          (_respuestas[pregunta.id] == null ||
           _respuestas[pregunta.id].toString().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('La pregunta "${pregunta.description}" es obligatoria'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
  }

  setState(() => _isEnviando = true);

  try {
    // Construir array de respuestas
    final List<Map<String, dynamic>> arrayRespuestas = [];
    _respuestas.forEach((preguntaId, valor) {
      if (valor == null || valor.toString().isEmpty) return;
      final respuesta = <String, dynamic>{
        'visit_id': widget.visita.id,
        'question_id': preguntaId,
      };
      if (valor is int) {
        respuesta['answer_option'] = valor.toString();
      } else {
        respuesta['answer_text'] = valor.toString();
      }
      arrayRespuestas.add(respuesta);
    });

    // Primero verificar conexión rápido
    final conectado = await ConnectivityService.isConnected();
    
    if (!conectado) {
      // OFFLINE DETECTADO - Guardar localmente
      await _guardarLocalmente(arrayRespuestas);
      return;
    }

    // ONLINE - Intentar enviar con timeout corto
    try {
      final exito = await _encuestaRepo
          .enviarEncuesta(
            visitId: widget.visita.id,
            respuestas: arrayRespuestas,
          )
          .timeout(const Duration(seconds: 10)); // Timeout de 10 segundos

      if (mounted) {
        setState(() => _isEnviando = false);
        if (exito) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Encuesta enviada correctamente'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        } else {
          // Falló el envío - guardar localmente
          await _guardarLocalmente(arrayRespuestas);
        }
      }
    } on TimeoutException {
      // Timeout - probablemente sin conexión real
      await _guardarLocalmente(arrayRespuestas);
    } catch (e) {
      // Error de red - guardar localmente
      print('Error de red: $e');
      await _guardarLocalmente(arrayRespuestas);
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isEnviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _guardarLocalmente(List<Map<String, dynamic>> arrayRespuestas) async {
  try {
    final db = DatabaseHelper.instance;
    await db.guardarEncuesta(
      visitId: widget.visita.id,
      customerName: widget.visita.customerName,
      respuestasJson: jsonEncode(arrayRespuestas),
      lat: _lat,
      lng: _lng,
      foto1Path: _foto1?.path,
      foto2Path: _foto2?.path,
    );

    if (mounted) {
      setState(() => _isEnviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📴 Guardado localmente. Se enviará cuando haya conexión.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    }
  } catch (e) {
    print('Error guardando localmente: $e');
    if (mounted) {
      setState(() => _isEnviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
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
          body: _isLoadingEncuesta
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderVisita(),
                    const SizedBox(height: 24),
                    // _buildGpsSection(), ← QUITAR ESTA LÍNEA
                    _buildPreguntasSection(),
                    const SizedBox(height: 24),
                    _buildFotosSection(),
                    const SizedBox(height: 32),
                    AppButton(
                      text: 'ENVIAR ENCUESTA',
                      onPressed: _enviarEncuesta,
                      isLoading: _isEnviando,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Header ───
  Widget _buildHeaderVisita() {
    final visita = widget.visita;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryColor.withOpacity(0.1),
            child: Text(
              visita.customerName.isNotEmpty ? visita.customerName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visita.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (visita.city.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(child: Text(visita.city, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                Text('RIF: ${visita.taxId}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: const Text('Pendiente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  // ─── GPS ───
  Widget _buildGpsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: AppColors.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.location_on, color: AppColors.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Ubicación actual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _isLoadingLocation ? null : _getCurrentLocation),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingLocation)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primaryColor)))
          else if (_lat != null && _lng != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.15))),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lat: ${_lat!.toStringAsFixed(6)}', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontFamily: 'monospace')),
                        Text('Lng: ${_lng!.toStringAsFixed(6)}', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.15))),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 10),
                  const Text('No se pudo obtener la ubicación', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Preguntas ───
  Widget _buildPreguntasSection() {
    if (_encuesta == null || _encuesta!.questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No hay preguntas disponibles')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.quiz, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Preguntas de la visita', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ..._encuesta!.questions.map((pregunta) => _buildPregunta(pregunta)),
      ],
    );
  }

  Widget _buildPregunta(PreguntaModel pregunta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pregunta.description,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (pregunta.isRequired)
                const Text(' *', style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (pregunta.isRating) _buildRatingInput(pregunta),
          if (pregunta.isText) _buildTextInput(pregunta),
          if (pregunta.isMultipleChoice) _buildMultipleChoiceInput(pregunta),
        ],
      ),
    );
  }

  // ─── Input tipo RATING (estrellas) ───
  Widget _buildRatingInput(PreguntaModel pregunta) {
    final rating = (_respuestas[pregunta.id] as int?) ?? 0;

    return Row(
      children: List.generate(5, (index) {
        final star = index + 1;
        return GestureDetector(
          onTap: () => setState(() => _respuestas[pregunta.id] = star),
          child: Icon(
            star <= rating ? Icons.star : Icons.star_border,
            size: 36,
            color: star <= rating ? Colors.amber : Colors.grey[300],
          ),
        );
      }),
    );
  }

  // ─── Input tipo TEXTO ───
  Widget _buildTextInput(PreguntaModel pregunta) {
    return TextFormField(
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Escribe tu respuesta...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor)),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: pregunta.isRequired ? (v) => (v == null || v.isEmpty) ? 'Respuesta obligatoria' : null : null,
      onChanged: (value) => _respuestas[pregunta.id] = value,
    );
  }

  // ─── Input tipo MULTIPLE CHOICE ───
  Widget _buildMultipleChoiceInput(PreguntaModel pregunta) {
    final seleccionada = _respuestas[pregunta.id] as String?;

    return Column(
      children: (pregunta.responseOptions ?? []).map((opcion) {
        final isSelected = seleccionada == opcion;
        return GestureDetector(
          onTap: () => setState(() => _respuestas[pregunta.id] = opcion),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor.withOpacity(0.08) : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.primaryColor : Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: isSelected ? AppColors.primaryColor : Colors.grey[400],
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(opcion, style: TextStyle(fontSize: 14, color: isSelected ? AppColors.primaryColor : Colors.grey[700]))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Fotos ───
  Widget _buildFotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.camera_alt, color: AppColors.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Evidencias fotográficas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PhotoCaptureWidget(label: 'Foto del local', onPhotoTaken: (file) => _foto1 = file),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoCaptureWidget(label: 'Foto adicional', onPhotoTaken: (file) => _foto2 = file),
            ),
          ],
        ),
      ],
    );
  }
}