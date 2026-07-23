import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../repositories/encuesta_repository.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

/// Página para que el vendedor cree preguntas de encuesta offline-first.
/// La pregunta se guarda localmente y se sube al servidor en el siguiente sync.
/// Backend es idempotente por `code`, así que múltiples vendedores creando
/// preguntas similares no chocan.
class CrearPreguntaPage extends StatefulWidget {
  const CrearPreguntaPage({super.key});

  @override
  State<CrearPreguntaPage> createState() => _CrearPreguntaPageState();
}

class _CrearPreguntaPageState extends State<CrearPreguntaPage> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _opcionCtrl = TextEditingController();
  final EncuestaRepository _repo = EncuestaRepository();

  String _tipo = 'TEXT';
  bool _esRequerida = false;
  final List<String> _opciones = [];
  bool _guardando = false;
  List<Map<String, dynamic>> _misPreguntas = [];

  static const _tipos = [
    {'value': 'TEXT', 'label': 'Texto libre', 'icon': Icons.short_text},
    {'value': 'MULTIPLE_CHOICE', 'label': 'Opción múltiple', 'icon': Icons.list_alt},
    {'value': 'BOOLEAN', 'label': 'Sí / No', 'icon': Icons.rule},
  ];

  @override
  void initState() {
    super.initState();
    _cargarMisPreguntas();
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _opcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMisPreguntas() async {
    final data = await _repo.listarPreguntas();
    if (!mounted) return;
    setState(() => _misPreguntas = data);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipo == 'MULTIPLE_CHOICE' && _opciones.isEmpty) {
      _showSnack('Agrega al menos una opción para MULTIPLE_CHOICE', error: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      await _repo.crearPreguntaOffline(
        descripcion: _descripcionCtrl.text.trim(),
        tipo: _tipo,
        esRequerida: _esRequerida,
        opciones: _tipo == 'MULTIPLE_CHOICE' ? _opciones : null,
      );

      _descripcionCtrl.clear();
      _opciones.clear();
      _esRequerida = false;
      _tipo = 'TEXT';
      await _cargarMisPreguntas();

      if (!mounted) return;
      _showSnack('✅ Pregunta guardada. Se subirá al recuperar conexión.');

      // Intentar sync inmediato si hay red
      final online = await ConnectivityService.instance.isConnected();
      if (online) {
        await SyncService.instance.marcarTodoSincronizado();
        if (mounted) await _cargarMisPreguntas();
      }
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
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

  void _agregarOpcion() {
    final val = _opcionCtrl.text.trim();
    if (val.isEmpty) return;
    if (_opciones.contains(val)) {
      _showSnack('Opción duplicada', error: true);
      return;
    }
    setState(() {
      _opciones.add(val);
      _opcionCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Nueva Pregunta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              _card(
                title: 'Datos de la pregunta',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _descripcionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Pregunta *',
                        hintText: '¿Qué necesitas preguntar al cliente?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.help_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'Mínimo 5 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo de respuesta', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tipos.map((t) {
                        final selected = _tipo == t['value'];
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t['icon'] as IconData, size: 16),
                              const SizedBox(width: 6),
                              Text(t['label'] as String),
                            ],
                          ),
                          selected: selected,
                          selectedColor: AppColors.primaryColor.withValues(alpha: 0.2),
                          onSelected: (_) {
                            setState(() {
                              _tipo = t['value'] as String;
                              if (_tipo != 'MULTIPLE_CHOICE') _opciones.clear();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Es obligatoria?'),
                      subtitle: const Text('El vendedor debe responderla siempre'),
                      value: _esRequerida,
                      activeThumbColor: AppColors.primaryColor,
                      onChanged: (v) => setState(() => _esRequerida = v),
                    ),
                  ],
                ),
              ),

              if (_tipo == 'MULTIPLE_CHOICE') ...[
                const SizedBox(height: 12),
                _card(
                  title: 'Opciones de respuesta',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _opcionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nueva opción',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _agregarOpcion(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _agregarOpcion,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_opciones.isEmpty)
                        const Text(
                          'Agrega al menos una opción',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _opciones
                              .map(
                                (o) => Chip(
                                  label: Text(o),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => setState(() => _opciones.remove(o)),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando...' : 'Guardar Pregunta'),
              ),

              const SizedBox(height: 24),
              _card(
                title: 'Mis preguntas (${_misPreguntas.length})',
                child: _misPreguntas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aún no has creado preguntas.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: _misPreguntas.map((p) {
                          final sync = p['sincronizado'] == 1;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              sync ? Icons.cloud_done : Icons.cloud_upload,
                              color: sync ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              p['descripcion']?.toString() ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '${p['tipo']}${p['es_requerida'] == 1 ? ' • Obligatoria' : ''} • ${sync ? 'Sincronizada' : 'Pendiente'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
