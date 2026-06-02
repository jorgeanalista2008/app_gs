import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/database_helper.dart';
import '../models/pregunta_model.dart';

class AdminEncuestaEditorPage extends StatefulWidget {
  final String encuestaId;
  final String encuestaTitulo;

  const AdminEncuestaEditorPage({
    super.key,
    required this.encuestaId,
    required this.encuestaTitulo,
  });

  @override
  State<AdminEncuestaEditorPage> createState() => _AdminEncuestaEditorPageState();
}

class _AdminEncuestaEditorPageState extends State<AdminEncuestaEditorPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _preguntas = [];
  String _encuestaDesc = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEncuestaInfo();
    _loadPreguntas();
  }

  Future<void> _loadEncuestaInfo() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'encuestas',
        where: 'id = ?',
        whereArgs: [widget.encuestaId],
        limit: 1,
      );
      if (results.isNotEmpty && mounted) {
        setState(() {
          _encuestaDesc = results.first['descripcion']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error al cargar descripción de la encuesta: $e');
    }
  }

  Future<void> _loadPreguntas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final questions = await _dbHelper.getPreguntasByEncuestaId(widget.encuestaId);
      if (mounted) {
        setState(() {
          _preguntas = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar preguntas: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // Swap order
  Future<void> _moverPregunta(int index, int direccion) async {
    // direccion: -1 para subir, 1 para bajar
    if (index + direccion < 0 || index + direccion >= _preguntas.length) return;

    final pActual = _preguntas[index];
    final pSiguiente = _preguntas[index + direccion];

    final idActual = pActual['id'] as String;
    final idSiguiente = pSiguiente['id'] as String;

    final ordenActual = pActual['orden'] as int;
    final ordenSiguiente = pSiguiente['orden'] as int;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'preguntas',
          {'orden': ordenSiguiente},
          where: 'id = ?',
          whereArgs: [idActual],
        );
        await txn.update(
          'preguntas',
          {'orden': ordenActual},
          where: 'id = ?',
          whereArgs: [idSiguiente],
        );
      });
      _loadPreguntas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reordenar: $e')),
      );
    }
  }

  // Eliminar pregunta
  Future<void> _eliminarPregunta(String id) async {
    try {
      await _dbHelper.eliminarPreguntaTemplate(id);
      _loadPreguntas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pregunta eliminada de la plantilla.'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar pregunta: $e'), backgroundColor: AppColors.errorColor),
      );
    }
  }

  // Dialog para agregar/editar pregunta
  void _mostrarPreguntaDialog() {
    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    final optionsController = TextEditingController();
    String selectedType = 'TEXT';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_comment_outlined, color: AppColors.primaryColor),
                  SizedBox(width: 10),
                  Text('Agregar Pregunta', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Pregunta / Enunciado',
                          prefixIcon: Icon(Icons.help_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa la pregunta';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Respuesta',
                          prefixIcon: Icon(Icons.list_alt_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'TEXT', child: Text('Texto Libre')),
                          DropdownMenuItem(value: 'RATING', child: Text('Calificación (Estrellas)')),
                          DropdownMenuItem(value: 'MULTIPLE_CHOICE', child: Text('Selección Múltiple')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                            });
                          }
                        },
                      ),
                      if (selectedType == 'MULTIPLE_CHOICE') ...[
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: optionsController,
                          decoration: const InputDecoration(
                            labelText: 'Opciones (separadas por comas)',
                            helperText: 'Ej: Excelente, Bueno, Regular, Malo',
                            prefixIcon: Icon(Icons.more_horiz),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          ),
                          validator: (value) {
                            if (selectedType == 'MULTIPLE_CHOICE' && (value == null || value.trim().isEmpty)) {
                              return 'Ingresa al menos una opción';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Text('¿Es requerida/obligatoria?', style: TextStyle(fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Switch(
                            value: isRequired,
                            activeColor: AppColors.primaryColor,
                            onChanged: (val) {
                              setDialogState(() {
                                isRequired = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newId = 'preg_${DateTime.now().microsecondsSinceEpoch}';
                      final nextOrder = _preguntas.length;

                      await _dbHelper.guardarPreguntaTemplate(
                        id: newId,
                        encuestaId: widget.encuestaId,
                        descripcion: descController.text.trim(),
                        tipo: selectedType,
                        esRequerida: isRequired ? 1 : 0,
                        opciones: selectedType == 'MULTIPLE_CHOICE' ? optionsController.text.trim() : null,
                        orden: nextOrder,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadPreguntas();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pregunta agregada con éxito.'),
                            backgroundColor: AppColors.successColor,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Badge para tipo de pregunta
  Widget _buildTypeBadge(String tipo) {
    Color bg;
    Color fg;
    String text;

    switch (tipo) {
      case 'RATING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        text = 'Estrellas';
        break;
      case 'MULTIPLE_CHOICE':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        text = 'Opción Múltiple';
        break;
      case 'TEXT':
      default:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        text = 'Texto';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Preguntas de la Encuesta'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Informativo de la encuesta
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.quiz, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.encuestaTitulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_encuestaDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _encuestaDesc,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de preguntas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _preguntas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.format_list_bulleted, size: 70, color: Colors.grey[300]),
                            const SizedBox(height: 15),
                            const Text(
                              'Aún no hay preguntas agregadas.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Haz clic en el botón inferior para agregar una.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _preguntas.length,
                        itemBuilder: (context, index) {
                          final p = _preguntas[index];
                          final id = p['id'] as String;
                          final desc = p['descripcion'] ?? '';
                          final tipo = p['tipo'] ?? 'TEXT';
                          final esReq = p['es_requerida'] == 1;
                          final opciones = p['opciones']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Indicador de orden y botones de reordenamiento
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: index == 0 ? null : () => _moverPregunta(index, -1),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: index == _preguntas.length - 1 ? null : () => _moverPregunta(index, 1),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),

                                  // Contenido de la pregunta
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildTypeBadge(tipo),
                                            if (esReq) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Requerida',
                                                  style: TextStyle(
                                                    color: AppColors.errorColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          desc,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (tipo == 'MULTIPLE_CHOICE' && opciones.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: PreguntaOption.parseOptions(opciones)
                                                .map(
                                                  (opt) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.grey[200]!),
                                                    ),
                                                    child: Text(
                                                      opt.label,
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Botón de eliminar pregunta
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.errorColor),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Eliminar Pregunta'),
                                          content: const Text('¿Estás seguro de que deseas eliminar esta pregunta de la plantilla?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _eliminarPregunta(id);
                                              },
                                              child: const Text('Eliminar', style: TextStyle(color: AppColors.errorColor)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarPreguntaDialog,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
