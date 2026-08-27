import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../repositories/visita_repository.dart';
import '../repositories/generic_repository.dart';
import '../repositories/encuesta_repository.dart';
import '../repositories/survey_pack_repository.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import 'encuesta_page.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import 'nueva_visita_page.dart';
import 'detalle_visita_page.dart';
import 'dart:convert';
import '../atoms/sync_status_chip.dart';
import '../organisms/connection_wrapper.dart';

class VisitasPage extends StatefulWidget {
  const VisitasPage({super.key});

  @override
  State<VisitasPage> createState() => _VisitasPageState();
}

class _VisitasPageState extends State<VisitasPage> with SingleTickerProviderStateMixin {
  final VisitaRepository _visitaRepo = VisitaRepository();
  final EncuestaRepository _encuestaRepo = EncuestaRepository();
  final SurveyPackRepository _packRepo = SurveyPackRepository();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _authService = AuthService.instance;
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  StreamSubscription<bool>? _syncSub;

  List<VisitaModel> _programadas = [];
  List<VisitaModel> _completadas = [];
  List<VisitaModel> _visitasFiltradas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _aplicarFiltro();
    });
    _loadVisitas();

    _syncSub = SyncService.instance.syncingStream.listen((syncing) {
      if (!syncing && mounted) {
        _loadVisitas();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final visitas = await _visitaRepo.getVisitasLocales();
      if (mounted) {
        final prog = visitas.where((v) => v.isPendiente).toList()
          ..sort((a, b) {
            final dtA = DateTime.tryParse(a.visitDateFrom) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = DateTime.tryParse(b.visitDateFrom) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });

        final comp = visitas.where((v) => v.isCompletada).toList()
          ..sort((a, b) {
            final strA = (a.completedAt != null && a.completedAt!.isNotEmpty)
                ? a.completedAt!
                : a.visitDateFrom;
            final strB = (b.completedAt != null && b.completedAt!.isNotEmpty)
                ? b.completedAt!
                : b.visitDateFrom;
            final dtA = DateTime.tryParse(strA) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = DateTime.tryParse(strB) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });

        setState(() {
          _programadas = prog;
          _completadas = comp;
          _isLoading = false;
        });
        _aplicarFiltro();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar visitas: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _aplicarFiltro() {
    final base = _tabController.index == 0 ? _programadas : _completadas;
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _visitasFiltradas = base;
      } else {
        _visitasFiltradas = base.where((v) {
          return v.customerName.toLowerCase().contains(query) ||
              v.codeClientProfit.toLowerCase().contains(query) ||
              v.taxId.toLowerCase().contains(query) ||
              v.city.toLowerCase().contains(query) ||
              v.notes.toLowerCase().contains(query);
        }).toList();
      }
    });
  }


  Color _getPrioridadColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.green;
      case 5:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _abrirNuevaVisita() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NuevaVisitaPage()),
    );
    if (result == true) {
      _loadVisitas();
    }
  }

  void _onVisitaTapped(VisitaModel visita) async {
    if (visita.isCompletada) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetalleVisitaPage(visita: visita),
        ),
      );
      return;
    }

    // Prioridad: si la visita ya trae un pack asignado (agendada por el
    // admin con un tipo de encuesta — nuevo/existente/activación — o elegido
    // al crearla en "Nueva Visita"), responder directo. Antes esto se
    // ignoraba por completo y toda visita pendiente caía en el mismo picker
    // genérico sin importar el pack real.
    final encuestaAsignada = await _encuestaRepo.getEncuestaVisita(visita.id);
    if (!mounted) return;

    if (encuestaAsignada != null && encuestaAsignada.questions.isNotEmpty) {
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EncuestaPage(
            visita: visita,
            plantillaId: '',
            plantillaTitulo: encuestaAsignada.packName ?? 'Encuesta de visita',
          ),
        ),
      );
      if (resultado == true) _loadVisitas();
      return;
    }

    // Sin pack asignado: dejar elegir uno real (con su tipo) en vez de la
    // plantilla plana genérica.
    final packs = await _packRepo.getAvailablePacks();
    if (!mounted) return;

    if (packs.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Sin Encuestas', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'El administrador no ha configurado ningún pack de encuesta en el sistema.\n\nPor favor, contacte al administrador para crear un pack y sus preguntas desde el panel de administración.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Seleccionar Pack de Encuesta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona el pack a aplicar para ${visita.customerName}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: packs.length,
                  itemBuilder: (context, index) {
                    final pack = packs[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pack.typeColor.withValues(alpha: 0.12),
                          child: Icon(Icons.assignment_outlined, color: pack.typeColor),
                        ),
                        title: Text(
                          pack.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
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
                              Text(
                                '${pack.questionIds.length} pregunta${pack.questionIds.length == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.primaryColor),
                        onTap: () async {
                          Navigator.pop(context);

                          await _packRepo.assignPackToVisit(
                            visitId: visita.id,
                            packId: pack.id,
                            packName: pack.name,
                          );

                          if (!mounted) return;

                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EncuestaPage(
                                visita: visita,
                                plantillaId: '',
                                plantillaTitulo: pack.name,
                              ),
                            ),
                          );

                          if (resultado == true) {
                            _loadVisitas();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitaCard(VisitaModel visita) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onVisitaTapped(visita),
        borderRadius: BorderRadius.circular(12),
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
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      visita.customerName.isNotEmpty ? visita.customerName[0].toUpperCase() : '?',
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
                          visita.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (visita.city.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  visita.city,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'RIF: ${visita.taxId} | Cód: ${visita.codeClientProfit}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPrioridadColor(visita.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getPrioridadColor(visita.priority).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      visita.prioridadTexto,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPrioridadColor(visita.priority),
                      ),
                    ),
                  ),
                ],
              ),
              if (visita.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    visita.notes,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    visita.isCompletada ? Icons.event_available : Icons.calendar_today,
                    size: 13,
                    color: visita.isCompletada ? Colors.green[700] : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      visita.isCompletada ? 'Realizada: ${visita.fechaCompletada}' : visita.fechaRango,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: visita.isCompletada ? FontWeight.w600 : FontWeight.normal,
                        color: visita.isCompletada ? Colors.green[800] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(visita),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(VisitaModel visita) {
    late Color color;
    late String text;
    late IconData icon;

    if (visita.isPendiente) {
      color = Colors.orange;
      text = 'Pendiente';
      icon = Icons.pending_actions;
    } else {
      if (visita.sincronizado) {
        color = Colors.green;
        text = 'Sincronizada';
        icon = Icons.cloud_done;
      } else {
        color = Colors.blue;
        text = 'Por subir';
        icon = Icons.cloud_upload_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(text: 'Reintentar', onPressed: _loadVisitas),
            ],
          ),
        ),
      );
    }

    if (_visitasFiltradas.isEmpty) {
      final esProgramadas = _tabController.index == 0;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esProgramadas ? Icons.assignment_outlined : Icons.assignment_turned_in_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              esProgramadas ? 'No hay visitas programadas' : 'No hay visitas completadas',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisitas,
      color: AppColors.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visitasFiltradas.length,
        itemBuilder: (context, index) {
          return _buildVisitaCard(_visitasFiltradas[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Visitas'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: [
            Tab(text: 'Programadas (${_programadas.length})'),
            Tab(text: 'Completadas (${_completadas.length})'),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: SyncStatusChip(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevaVisita,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Nueva Visita'),
      ),
      body: ConnectionWrapper(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: AppTextField(
                controller: _searchController,
                labelText: 'Buscar visita',
                hintText: 'Cliente, RIF, código o ciudad...',
                icon: Icons.search,
                onSubmitted: (_) => _aplicarFiltro(),
                onChanged: (_) => _aplicarFiltro(),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primaryColor.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Text(
                      '${_visitasFiltradas.length} resultados encontrados',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}