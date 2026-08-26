import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../models/encuesta_model.dart';
import '../models/pregunta_model.dart';
import '../repositories/encuesta_repository.dart';
import '../services/location_service.dart';
import '../services/location_tracking_service.dart';
import '../services/database_helper.dart';
import '../atoms/photo_capture_widget.dart';
import '../atoms/app_button.dart';

class EncuestaPage extends StatefulWidget {
  final VisitaModel visita;
  final String plantillaId;
  final String plantillaTitulo;

  const EncuestaPage({
    super.key,
    required this.visita,
    required this.plantillaId,
    required this.plantillaTitulo,
  });

  @override
  State<EncuestaPage> createState() => _EncuestaPageState();
}

class _EncuestaPageState extends State<EncuestaPage> {
  final EncuestaRepository _encuestaRepo = EncuestaRepository();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  // Encuesta
  EncuestaModel? _encuesta;
  bool _isLoadingEncuesta = true;

  // GPS
  double? _lat;
  double? _lng;

  // Respuestas
  final Map<String, dynamic> _respuestas = {};

  // Fotos: guardamos el path local del archivo. Al sincronizar,
  // ImageUploadService lee el binario y lo sube. Mantener la ruta en vez de
  // base64 evita hinchar el SQLite con megabytes por respuesta.
  String? _foto1Path;
  String? _foto2Path;

  // Estado
  bool _isEnviando = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEncuesta();
    // Marca el punto exacto de inicio de encuesta como lugar de visita.
    LocationTrackingService.instance.registrarLugarVisita(
      visitId: widget.visita.id,
      note: 'encuesta_inicio',
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _lat = position?.latitude;
          _lng = position?.longitude;
        });
      }
    } catch (e) {
      // Silently catch geolocation errors or log them if needed
    }
  }

  Future<void> _loadEncuesta() async {
    setState(() => _isLoadingEncuesta = true);

    try {
      // Cargar desde SQLite local usando la plantilla seleccionada
      final encuesta = await _encuestaRepo.getPlantillaEncuesta(widget.plantillaId, widget.visita.id);
      
      if (mounted) {
        if (encuesta != null && encuesta.questions.isNotEmpty) {
          setState(() {
            _encuesta = encuesta;
            _isLoadingEncuesta = false;
          });
          print('✅ Encuesta cargada localmente: ${encuesta.questions.length} preguntas');
        } else {
          setState(() => _isLoadingEncuesta = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No hay preguntas asignadas a esta visita.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEncuesta = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar preguntas: $e'),
            backgroundColor: Colors.red,
          ),
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
      // Guardar respuestas localmente
      final exito = await _encuestaRepo.guardarRespuestas(
        visitId: widget.visita.id,
        customerName: widget.visita.customerName,
        respuestas: _respuestas,
        lat: _lat,
        lng: _lng,
        foto1Path: _foto1Path,
        foto2Path: _foto2Path,
      );

      if (mounted) {
        setState(() => _isEnviando = false);

        if (exito) {
          // Actualizar estado de la visita a COMPLETED
          await _db.actualizarEstadoVisita(widget.visita.id, 'COMPLETED');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Encuesta guardada correctamente'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se pudo guardar la encuesta. Intente de nuevo.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEnviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        title: Text(widget.plantillaTitulo),
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
                    _buildPreguntasSection(),
                    // const SizedBox(height: 24),
                    // _buildFotosSection(), // Oculto temporalmente para versión futura
                    const SizedBox(height: 32),
                    AppButton(
                      text: 'GUARDAR ENCUESTA',
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
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
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
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: const Text('Pendiente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
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
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
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

  Widget _buildMultipleChoiceInput(PreguntaModel pregunta) {
    final seleccionada = _respuestas[pregunta.id] as String?;

    return Column(
      children: (pregunta.responseOptions ?? []).map((opcion) {
        final isSelected = seleccionada == opcion.id;
        return GestureDetector(
          onTap: () => setState(() => _respuestas[pregunta.id] = opcion.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.08) : Colors.grey[50],
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
                Expanded(child: Text(opcion.label, style: TextStyle(fontSize: 14, color: isSelected ? AppColors.primaryColor : Colors.grey[700]))),
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
              decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
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
              child: PhotoCaptureWidget(
                label: 'Foto del local',
                visitId: widget.visita.id,
                onPhotoTaken: (file, _) {
                  _foto1Path = file?.path;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoCaptureWidget(
                label: 'Foto adicional',
                visitId: widget.visita.id,
                onPhotoTaken: (file, _) {
                  _foto2Path = file?.path;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}