import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../repositories/encuesta_repository.dart';
import '../services/database_helper.dart';
import '../models/pregunta_model.dart';

class DetalleVisitaPage extends StatefulWidget {
  final VisitaModel visita;

  const DetalleVisitaPage({super.key, required this.visita});

  @override
  State<DetalleVisitaPage> createState() => _DetalleVisitaPageState();
}

class _DetalleVisitaPageState extends State<DetalleVisitaPage> {
  final EncuestaRepository _encuestaRepo = EncuestaRepository();
  bool _isLoading = true;
  List<dynamic> _respuestas = [];
  double? _lat;
  double? _lng;
  String? _foto1Base64;
  String? _foto2Base64;
  Map<String, List<PreguntaOption>> _preguntasOpciones = {};

  @override
  void initState() {
    super.initState();
    _loadDetalle();
  }

  Future<void> _loadDetalle() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final preguntasData = await db.query('preguntas');
      for (var p in preguntasData) {
        final qId = p['id']?.toString() ?? '';
        final opcionesStr = p['opciones']?.toString() ?? '';
        _preguntasOpciones[qId] = PreguntaOption.parseOptions(opcionesStr);
      }

      final rows = await _encuestaRepo.getRespuestas(widget.visita.id);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final rawJson = row['respuestas_json'] as String?;
        if (rawJson != null && rawJson.isNotEmpty) {
          _respuestas = jsonDecode(rawJson) as List;
        }
        _lat = row['lat'] as double?;
        _lng = row['lng'] as double?;
        _foto1Base64 = row['foto1_path'] as String?;
        _foto2Base64 = row['foto2_path'] as String?;
      }
    } catch (e) {
      debugPrint('Error cargando detalle de visita: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPrioridadColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red[700]!;
      case 2:
        return Colors.orange[700]!;
      case 3:
        return Colors.blue[700]!;
      default:
        return Colors.green[700]!;
    }
  }

  void _verImagenCompleta(String base64Image, String titulo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String base64Image, String label) {
    return GestureDetector(
      onTap: () => _verImagenCompleta(base64Image, label),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.visita.sincronizado ? Colors.green : Colors.blue;
    final statusText = widget.visita.sincronizado ? 'Sincronizada' : 'Completada (Sin subir)';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detalle de Visita'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CARD GENERAL INFO
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                                child: Text(
                                  widget.visita.customerName.isNotEmpty
                                      ? widget.visita.customerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.visita.customerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'RIF: ${widget.visita.taxId} | Cód: ${widget.visita.codeClientProfit}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (widget.visita.city.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.visita.address.isNotEmpty
                                        ? '${widget.visita.address}, ${widget.visita.city}'
                                        : widget.visita.city,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                widget.visita.fechaRango,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getPrioridadColor(widget.visita.priority).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getPrioridadColor(widget.visita.priority).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  widget.visita.prioridadTexto,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getPrioridadColor(widget.visita.priority),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.visita.sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (widget.visita.notes.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text(
                              'Notas de Planificación:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.visita.notes,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD RESPUESTAS DE ENCUESTA
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment, color: AppColors.primaryColor, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Resultados de la Encuesta',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (_respuestas.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No hay respuestas registradas para esta visita.',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _respuestas.length,
                              separatorBuilder: (context, index) => const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final res = _respuestas[index] as Map<String, dynamic>;
                                final questionText = res['description'] ??
                                    res['question_description'] ??
                                    'Pregunta ${res['question_id']}';
                                final type = res['question_type'] ?? '';
                                final optionId = res['answer_option']?.toString();
                                final text = res['answer_text'];

                                String displayText = 'Sin responder';
                                if (optionId != null) {
                                  final opts = _preguntasOpciones[res['question_id']?.toString() ?? ''] ?? [];
                                  final match = opts.firstWhere(
                                    (o) => o.id == optionId,
                                    orElse: () => PreguntaOption(id: optionId, label: optionId),
                                  );
                                  displayText = match.label;
                                } else if (text != null) {
                                  displayText = text;
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      questionText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: Text(
                                        displayText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: (displayText == 'Sin responder')
                                              ? Colors.grey
                                              : AppColors.textPrimary,
                                          fontWeight: (optionId != null)
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // UBICACIÓN Y FOTOS
                  if ((_lat != null && _lng != null) || (_foto1Base64 != null || _foto2Base64 != null))
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.photo_library, color: AppColors.primaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Evidencia en Campo',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            if (_lat != null && _lng != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.my_location, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Coordenadas: $_lat, $_lng',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_foto1Base64 != null || _foto2Base64 != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (_foto1Base64 != null)
                                    _buildPhotoThumbnail(_foto1Base64!, 'Foto del Local'),
                                  if (_foto2Base64 != null)
                                    _buildPhotoThumbnail(_foto2Base64!, 'Foto Adicional'),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
