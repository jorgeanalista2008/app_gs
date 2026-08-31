import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/database_helper.dart';
import '../services/sync_queue_service.dart';
import '../models/pregunta_model.dart';
import '../atoms/app_text_field.dart';
import '../repositories/survey_pack_repository.dart';
import '../repositories/generic_repository.dart';

class NuevaVisitaPage extends StatefulWidget {
  final Map<String, dynamic>? clienteInicial;

  const NuevaVisitaPage({super.key, this.clienteInicial});

  @override
  State<NuevaVisitaPage> createState() => _NuevaVisitaPageState();
}

class _NuevaVisitaPageState extends State<NuevaVisitaPage> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SurveyPackRepository _packRepo = SurveyPackRepository();
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _clientesFiltrados = [];
  List<SurveyPackModel> _packs = [];

  Map<String, dynamic>? _clienteSeleccionado;
  SurveyPackModel? _packSeleccionado;
  int _prioridad = 1;
  int _paso = 1; // 1=Cliente, 2=Pack de Preguntas, 3=Notas

  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadingPacks = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final clientes = await _db.getClientes();
      final packs = await _packRepo.getAvailablePacks();
      if (mounted) {
        setState(() {
          _clientes = clientes;
          _clientesFiltrados = clientes;
          _packs = packs;
          _isLoading = false;
          if (widget.clienteInicial != null) {
            _clienteSeleccionado = widget.clienteInicial;
            _paso = 2;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filtrarClientes(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.length < 2) {
        _clientesFiltrados = _clientes;
      } else {
        _clientesFiltrados = _clientes.where((c) {
          final name = (c['name'] ?? '').toLowerCase();
          final rif = (c['tax_id'] ?? '').toLowerCase();
          final code = (c['code_client_profit'] ?? '').toLowerCase();
          return name.contains(q) || rif.contains(q) || code.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _guardarVisita() async {
    if (_clienteSeleccionado == null || _packSeleccionado == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final yearStr = now.year.toString();
      final monthStr = now.month.toString().padLeft(2, '0');
      final dayStr = now.day.toString().padLeft(2, '0');
      final lastDay = DateTime(now.year, now.month + 1, 0).day.toString().padLeft(2, '0');

      final db = await _db.database;

      // Obtener question_ids del pack
      final questions = await _packRepo.getPackQuestions(_packSeleccionado!.id);
      final questionIds = questions.map((q) => int.tryParse(q.id) ?? 0).toList();

      final visitData = {
        'customer_id': _clienteSeleccionado!['id'],
        'customer_name': _clienteSeleccionado!['name'],
        'address': _clienteSeleccionado!['direccion'] ?? '',
        'city': _clienteSeleccionado!['direccion']?.toString().split(',').last.trim() ?? '',
        'code_client_profit': _clienteSeleccionado!['code_client_profit'] ?? '',
        'tax_id': _clienteSeleccionado!['tax_id'] ?? '',
        'visit_date_from': '$yearStr-$monthStr-$dayStr',
        'visit_date_to': '$yearStr-$monthStr-$lastDay',
        'notes': _notasController.text.trim(),
        'priority': _prioridad,
        'status': 'PENDING',
        'sincronizado': 0,
        'pack_id': _packSeleccionado!.id,
        'pack_name': _packSeleccionado!.name,
        'pack_type': _packSeleccionado!.packType,
        'question_ids': jsonEncode(questionIds),
      };

      // Buscar si el cliente ya tiene una visita programada (pendiente) en local
      final List<Map<String, dynamic>> visitasPendientes = await db.query(
        'visitas',
        where: "customer_id = ? AND status = 'PENDING'",
        whereArgs: [_clienteSeleccionado!['id']],
        limit: 1,
      );

      String visitaId;
      if (visitasPendientes.isNotEmpty) {
        // Si ya hay una agenda programada pendiente, la actualizamos para reutilizar su ID numérico
        visitaId = visitasPendientes.first['id'].toString();
        await db.update(
          'visitas',
          visitData,
          where: 'id = ?',
          whereArgs: [visitaId],
        );
        print('🔗 Vinculando visita manual a la agenda programada existente ID: $visitaId');
      } else {
        // De lo contrario, creamos una visita ad-hoc nueva
        visitaId = 'visita_${now.microsecondsSinceEpoch}';
        await db.insert('visitas', {
          'id': visitaId,
          ...visitData,
        });
        print('🆕 Creada visita manual ad-hoc con ID: $visitaId');

        // Auto-agendar en el servidor de inmediato (PENDING). Antes esta
        // visita solo existía local hasta completarse — no aparecía en la
        // web ni en /admin/scheduled-visits mientras tanto. Se encola (no
        // POST directo) para que el mismo mecanismo de retry+backoff+dedup
        // de SyncQueueService la reintente si no hay red ahora mismo.
        final salespersonId = await GenericRepository.instance.getUserId();
        if (salespersonId != null) {
          final userLocal = await _db.getUsuario(salespersonId);
          if (userLocal != null) {
            await SyncQueueService.instance.enqueue(
              entityType: 'visit_schedule',
              entityLocalId: visitaId,
              operation: 'create',
              httpMethod: 'POST',
              endpoint: '/salesperson/auth/schedules/create',
              payload: {
                'email': userLocal['username'],
                'password': userLocal['password'],
                'customer_id': _clienteSeleccionado!['id'],
                'visit_date_from': visitData['visit_date_from'],
                'visit_date_to': visitData['visit_date_to'],
                'priority': _prioridad,
                if (_notasController.text.trim().isNotEmpty)
                  'notes': _notasController.text.trim(),
                'pack_id': _packSeleccionado!.id,
              },
            );
            print('📤 [NuevaVisita] agenda encolada para subir: $visitaId');
          }
        }
      }

      print('✅ Visita guardada con pack: ${_packSeleccionado!.name} y ${questionIds.length} preguntas');

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Visita creada con pack "${_packSeleccionado!.name}"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _notasController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_paso == 1 ? 'Seleccionar Cliente' : _paso == 2 ? 'Seleccionar Pack de Preguntas' : 'Datos de Visita'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _paso > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _paso--),
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : _paso == 1
              ? _buildPasoCliente()
              : _paso == 2
                  ? _buildPasoPack()
                  : _buildPasoNotas(),
    );
  }

  // ═══════════════════════════════════════
  // PASO 1: SELECCIONAR CLIENTE
  // ═══════════════════════════════════════
  Widget _buildPasoCliente() {
    return Column(
      children: [
        // Indicador de pasos
        _buildStepper(1),
        // Búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: AppTextField(
            controller: _searchController,
            labelText: 'Buscar cliente',
            hintText: 'Escribe al menos 2 letras (Nombre, RIF, Código)...',
            icon: Icons.search,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _filtrarClientes('');
                    },
                  )
                : null,
            onChanged: _filtrarClientes,
            onSubmitted: _filtrarClientes,
          ),
        ),
        // Resultados
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${_clientesFiltrados.length} cliente${_clientesFiltrados.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
        Expanded(
          child: _clientesFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('No se encontraron clientes', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = _clientesFiltrados[index];
                    final isSelected = _clienteSeleccionado?['id'] == cliente['id'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected ? BorderSide(color: AppColors.primaryColor, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _clienteSeleccionado = cliente;
                            _paso = 2;
                          });
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppColors.primaryColor
                              : AppColors.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            (cliente['name'] ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cliente['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (cliente['is_prospect'] == 1)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300, width: 0.5),
                                ),
                                child: const Text(
                                  'Prospecto',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('RIF: ${cliente['tax_id'] ?? 'N/A'}'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.primaryColor)
                            : const Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // PASO 2: SELECCIONAR ENCUESTA
  // ═══════════════════════════════════════
  Widget _buildPasoPack() {
    return Column(
      children: [
        _buildStepper(2),
        // Cliente seleccionado
        if (_clienteSeleccionado != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Cliente: ',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          _clienteSeleccionado!['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_clienteSeleccionado!['is_prospect'] == 1)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Prospecto',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _paso = 1),
                  child: const Text('Cambiar', style: TextStyle(color: AppColors.primaryColor, fontSize: 13)),
                ),
              ],
            ),
          ),
        // Packs de preguntas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_packs.length} pack${_packs.length != 1 ? 's' : ''} disponible${_packs.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _packs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('No hay packs disponibles', style: TextStyle(color: Colors.grey)),
                      const Text('Descargue datos primero en la pantalla principal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _packs.length,
                  itemBuilder: (context, index) {
                    final pack = _packs[index];
                    final isSelected = _packSeleccionado?.id == pack.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected ? BorderSide(color: AppColors.primaryColor, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _packSeleccionado = pack;
                            _paso = 3;
                          });
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.primaryColor : pack.typeColor.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.assignment,
                            color: isSelected ? Colors.white : pack.typeColor,
                            size: 20,
                          ),
                        ),
                        title: Text(pack.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pack.typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  pack.typeLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pack.typeColor),
                                ),
                              ),
                              if (pack.description?.isNotEmpty == true)
                                Text(
                                  pack.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.primaryColor)
                            : Text('${pack.questionIds.length} preguntas', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // PASO 3: NOTAS Y PRIORIDAD
  // ═══════════════════════════════════════
  Widget _buildPasoNotas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepper(3),
          const SizedBox(height: 16),

          // Resumen
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumen de la visita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildResumenRow(
                  'Cliente',
                  _clienteSeleccionado?['name'] ?? '',
                  isProspect: _clienteSeleccionado?['is_prospect'] == 1,
                ),
                _buildResumenRow('Pack de Preguntas', _packSeleccionado?.name ?? ''),
                if (_packSeleccionado != null)
                  _buildResumenRow('Preguntas', '${_packSeleccionado!.questionIds.length} preguntas'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notas
          const Text('Notas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notasController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Escribe notas de la visita (opcional)...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Prioridad
          const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPrioridadChip(1, 'Normal', Colors.green),
              const SizedBox(width: 10),
              _buildPrioridadChip(2, 'Media', Colors.orange),
              const SizedBox(width: 10),
              _buildPrioridadChip(3, 'Alta', Colors.red),
            ],
          ),
          const SizedBox(height: 32),

          // Botón
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardarVisita,
              icon: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, size: 22),
              label: Text(_isSaving ? 'GUARDANDO...' : 'CREAR VISITA',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepDot(1, 'Cliente', currentStep),
          _buildStepLine(currentStep > 1),
          _buildStepDot(2, 'Pack', currentStep),
          _buildStepLine(currentStep > 2),
          _buildStepDot(3, 'Guardar', currentStep),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label, int current) {
    final isActive = current >= step;
    final isCurrent = current == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryColor : Colors.grey[200],
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: AppColors.primaryColor, width: 3) : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$step', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isCurrent ? AppColors.primaryColor : Colors.grey[500])),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      width: 40, height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? AppColors.primaryColor : Colors.grey[200],
    );
  }

  Widget _buildResumenRow(String label, String value, {bool isProspect = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isProspect)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Prospecto',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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

  Widget _buildPrioridadChip(int value, String label, Color color) {
    final isSelected = _prioridad == value;
    return GestureDetector(
      onTap: () => setState(() => _prioridad = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? color : Colors.grey[600],
        )),
      ),
    );
  }
}