import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../repositories/visita_repository.dart';
import '../repositories/generic_repository.dart';
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
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _authService = AuthService.instance;
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<VisitaModel> _programadas = [];
  List<VisitaModel> _completadas = [];
  List<VisitaModel> _visitasFiltradas = [];
  bool _isLoading = true;
  String? _error;
  int _pendingUploads = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _aplicarFiltro();
    });
    _loadVisitas();
  }

  @override
  void dispose() {
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
      final pendingCount = await _db.contarRespuestasPendientes();
      if (mounted) {
        setState(() {
          _programadas = visitas.where((v) => v.isPendiente).toList();
          _completadas = visitas.where((v) => v.isCompletada).toList();
          _pendingUploads = pendingCount;
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

  Future<void> _descargarVisitas({String? email, String? password}) async {
    final conectado = await ConnectivityService.instance.isConnected();
    if (!conectado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 Sin conexión a internet para descargar visitas.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resDescarga = await SyncService.instance.descargarDatosFromServer(
        email: email,
        password: password,
      );

      final clientesDescargados = resDescarga['clientes'] ?? 0;
      final visitasDescargadas = resDescarga['visitas'] ?? 0;
      final preguntasDescargadas = resDescarga['preguntas'] ?? 0;
      final erroresDescarga = resDescarga['errores'] ?? 0;

      if (mounted) {
        if (erroresDescarga > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error en el servidor al descargar datos.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📥 Sincronización completa:\n'
                '• Clientes: $clientesDescargados\n'
                '• Visitas programadas: $visitasDescargadas\n'
                '• Preguntas descargadas: $preguntasDescargadas',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadVisitas();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al descargar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _subirVisitas({String? email, String? password}) async {
    final conectado = await ConnectivityService.instance.isConnected();
    if (!conectado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 Sin conexión a internet para subir datos.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resSubida = await SyncService.instance.marcarTodoSincronizado(
        email: email,
        password: password,
      );

      final subidas = resSubida['marcadas'] ?? 0;
      final erroresSubida = resSubida['errores'] ?? 0;

      if (mounted) {
        if (erroresSubida > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Se subieron $subidas visitas, pero hubo $erroresSubida errores.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⬆️ Sincronización exitosa: $subidas visitas enviadas al servidor.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadVisitas();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al subir visitas: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _syncDownloadPressed() {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa'), backgroundColor: Colors.red),
      );
      return;
    }
    _descargarVisitas(
      email: usuario['username'] ?? '',
      password: usuario['password'] ?? '',
    );
  }

  void _syncUploadPressed() {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa'), backgroundColor: Colors.red),
      );
      return;
    }
    _subirVisitas(
      email: usuario['username'] ?? '',
      password: usuario['password'] ?? '',
    );
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

    final plantillas = await DatabaseHelper.instance.getPlantillasEncuestas();

    if (!mounted) return;

    if (plantillas.isEmpty) {
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
            'El administrador no ha configurado ninguna encuesta en el sistema.\n\nPor favor, contacte al administrador para crear una encuesta y sus preguntas desde el panel de administración.',
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
              Text(
                'Seleccionar Encuesta',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona la encuesta a aplicar para ${visita.customerName}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plantillas.length,
                  itemBuilder: (context, index) {
                    final p = plantillas[index];
                    final id = p['id'] as String;
                    final titulo = p['titulo'] ?? 'Encuesta sin título';
                    final desc = p['descripcion'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.assignment_outlined, color: AppColors.primaryColor),
                        ),
                        title: Text(
                          titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        subtitle: desc.isNotEmpty
                            ? Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.primaryColor),
                        onTap: () async {
                          Navigator.pop(context);

                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EncuestaPage(
                                visita: visita,
                                plantillaId: id,
                                plantillaTitulo: titulo,
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
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
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
                      color: _getPrioridadColor(visita.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getPrioridadColor(visita.priority).withOpacity(0.3)),
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
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    visita.fechaRango,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
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
        text = 'Completada (Sin subir)';
        icon = Icons.cloud_upload;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? (esProgramadas
                      ? 'No tienes visitas programadas.\nPresiona 📥 para descargar.'
                      : 'No tienes visitas completadas.')
                  : 'No se encontraron visitas',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
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
          tabs: [
            Tab(text: 'Programadas (${_programadas.length})'),
            Tab(text: 'Completadas (${_completadas.length})'),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
            child: SyncStatusChip(),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Descargar visitas asignadas',
            onPressed: _isLoading ? null : _syncDownloadPressed,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_upload),
                tooltip: 'Subir visitas realizadas',
                onPressed: _isLoading ? null : _syncUploadPressed,
              ),
              if (_pendingUploads > 0)
                Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _pendingUploads > 99 ? '99+' : _pendingUploads.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
                color: AppColors.primaryColor.withOpacity(0.05),
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