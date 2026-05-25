import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../repositories/visita_repository.dart';
import '../repositories/generic_repository.dart';
import '../atoms/app_button.dart';
import 'encuesta_page.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../pages/nueva_visita_page.dart';

class VisitasPage extends StatefulWidget {
  const VisitasPage({super.key});

  @override
  State<VisitasPage> createState() => _VisitasPageState();
}

class _VisitasPageState extends State<VisitasPage> {
  final VisitaRepository _visitaRepo = VisitaRepository();
  final ScrollController _scrollController = ScrollController();

  List<VisitaModel> _visitas = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMorePages = true;
  static const int _limit = 25;

  late String _dateFrom;
  late String _dateTo;
  String _mesLabel = '';

  @override
  void initState() {
    super.initState();
    _setCurrentMonth();
    _loadVisitas();
    _scrollController.addListener(_onScroll);
  }
  
  // Helper para color de prioridad (en la página, no en el modelo)
Color _getPrioridadColor(int priority) {
  switch (priority) {
    case 1: return Colors.red;
    case 2: return Colors.orange;
    case 3: return Colors.yellow;
    case 4: return Colors.green;
    case 5: return Colors.grey;
    default: return Colors.grey;
  }
}
  void _setCurrentMonth() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    _dateFrom = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-01';
    _dateTo = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    _mesLabel = '${meses[now.month - 1]} ${now.year}';
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePages) {
      _loadMoreVisitas();
    }
  }

  Future<void> _loadVisitas() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final visitas = await _visitaRepo.getMisVisitas(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _visitas = visitas;
          _isLoading = false;
          _hasMorePages = visitas.length >= _limit;
        });
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

  Future<void> _loadMoreVisitas() async {
    if (_isLoadingMore || !_hasMorePages) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final nuevasVisitas = await _visitaRepo.getMisVisitas(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _visitas.addAll(nuevasVisitas);
          _isLoadingMore = false;
          _hasMorePages = nuevasVisitas.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
      }
    }
  }

  Future<void> _ejecutarSincronizacionCompleta({String? email, String? password}) async {
    final conectado = await ConnectivityService.instance.isConnected();
    if (!conectado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sin conexión a internet para sincronizar.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text('Autenticando con el servidor...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    final autenticado = await SyncService.instance.authenticateOnline(email: email, password: password);
    if (!autenticado) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error de autenticación: Credenciales del servidor incorrectas.'),
            backgroundColor: Colors.red,
          ),
        );
        _mostrarDialogCredencialesSync();
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text('Sincronizando datos...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    final resSubida = await SyncService.instance.marcarTodoSincronizado(email: email, password: password);
    final subidas = resSubida['marcadas'] ?? 0;
    final erroresSubida = resSubida['errores'] ?? 0;

    final resDescarga = await SyncService.instance.descargarDatosFromServer(email: email, password: password);
    final clientesDescargados = resDescarga['clientes'] ?? 0;
    final erroresDescarga = resDescarga['errores'] ?? 0;

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final totalErrores = erroresSubida + erroresDescarga;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sincronización completa: '
            '⬆️ $subidas enviadas, '
            '📥 $clientesDescargados clientes actualizados'
            '${totalErrores > 0 ? " ($totalErrores errores)" : ""}',
          ),
          backgroundColor: totalErrores == 0 
              ? Colors.green 
              : Colors.orange,
        ),
      );

      _loadVisitas();
    }
  }

  void _mostrarDialogCredencialesSync() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.sync_lock, color: AppColors.primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Credenciales de Servidor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ingrese el correo y contraseña que le asignó el administrador para sincronizar con el servidor.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El correo es requerido';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Ingrese un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña es requerida';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final email = emailController.text.trim();
                      final password = passwordController.text;
                      
                      Navigator.pop(context); // Close dialog
                      
                      // Run synchronization with these credentials
                      await _ejecutarSincronizacionCompleta(email: email, password: password);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sincronizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      actions: [
        // Botón de sincronización con contador
        FutureBuilder<int>(
         future: DatabaseHelper.instance.contarRespuestasPendientes(), // ← CAMBIADO
          builder: (context, snapshot) {
            final pendientes = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sincronizar encuestas pendientes',
                  onPressed: () async {
                    final currentUser = AuthService.instance.currentUser;
                    final localUsername = currentUser?['username']?.toString();
                    
                    if (localUsername == 'vendedor@solsumed') {
                      _mostrarDialogCredencialesSync();
                    } else {
                      await _ejecutarSincronizacionCompleta();
                    }
                  },
                ),
                // Badge contador
                if (pendientes > 0)
                  Positioned(
                    top: 6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        pendientes > 99 ? '99+' : pendientes.toString(),
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
            );
          },
        ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva Visita',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NuevaVisitaPage()),
              );
              if (result == true) _loadVisitas();
            },
          ),
      ],
    ),
    body: Column(
      children: [
        // Cabecera
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.primaryColor),
              const SizedBox(width: 10),
              Text(
                _mesLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildStatusFilter(),
            ],
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    ),

  );
}

  Widget _buildStatusFilter() {
    final pendientes = _visitas.where((v) => v.isPendiente).length;
    final completadas = _visitas.where((v) => v.isCompletada).length;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$pendientes pendientes',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
          ),
        ),
        if (completadas > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$completadas completadas',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
            ),
          ),
        ],
      ],
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

    if (_visitas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No tienes visitas este mes', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisitas,
      color: AppColors.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _visitas.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _visitas.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            );
          }
          return _buildVisitaCard(_visitas[index]);
        },
      ),
    );
  }

  Widget _buildVisitaCard(VisitaModel visita) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: visita.isPendiente ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _onVisitaTapped(visita),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: visita.isCompletada
                ? Border.all(color: Colors.green.withOpacity(0.3))
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primera fila: Fecha + Prioridad + Estado
              Row(
                children: [
                  // Fecha
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: visita.isCompletada
                          ? Colors.green.withOpacity(0.08)
                          : AppColors.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          visita.mesAbreviado,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: visita.isCompletada ? Colors.green : AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          visita.diaNumero,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: visita.isCompletada ? Colors.green : AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Cliente y dirección
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visita.customerName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        if (visita.city.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  visita.city,
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

                  // Prioridad
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                     color: _getPrioridadColor(visita.priority),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getPrioridadColor(visita.priority).withOpacity(0.3)),
                    ),
                    child: Text(
                      visita.prioridadTexto,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                       
                      ),
                    ),
                  ),
                ],
              ),

              // Notas (si hay)
              if (visita.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          visita.notes,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Fechas y estado
              Row(
                children: [
                  Icon(Icons.date_range, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    visita.fechaRango,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  // Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: visita.isPendiente
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: visita.isPendiente
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          visita.isPendiente ? Icons.pending : Icons.check_circle,
                          size: 12,
                          color: visita.isPendiente ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          visita.isPendiente ? 'Pendiente' : 'Completada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: visita.isPendiente ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVisitaTapped(VisitaModel visita) async {
    if (visita.isCompletada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta visita ya ha sido completada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Obtener plantillas de encuestas disponibles
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

    // Mostrar modal con las encuestas disponibles
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
                          Navigator.pop(context); // Cerrar bottom sheet

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

  void _onNuevaVisitaPressed() async {
    // 1. Cargar clientes y plantillas encuestas de SQLite
    final clientes = await DatabaseHelper.instance.getClientes();
    final plantillas = await DatabaseHelper.instance.getPlantillasEncuestas();

    if (!mounted) return;

    if (clientes.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Sin Clientes', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'No hay clientes registrados localmente.\n\nPor favor, conéctese a internet y sincronice los datos para descargar sus clientes asignados.',
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

    // Controladores de estado para el bottom sheet
    int currentStep = 1;
    Map<String, dynamic>? selectedCustomer;
    Map<String, dynamic>? selectedTemplate;
    int selectedPriority = 3; // Normal por defecto
    final notesController = TextEditingController();
    String searchCustomerQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Filtrar clientes
            final filteredClientes = clientes.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              final rif = (c['tax_id'] ?? '').toString().toLowerCase();
              final code = (c['code_client_profit'] ?? '').toString().toLowerCase();
              final query = searchCustomerQuery.toLowerCase();
              return name.contains(query) || rif.contains(query) || code.contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Indicador de pasos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentStep == 1
                              ? 'Paso 1: Seleccionar Cliente'
                              : currentStep == 2
                                  ? 'Paso 2: Seleccionar Encuesta'
                                  : 'Paso 3: Detalles de Visita',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          '$currentStep/3',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Contenido del paso actual
                    if (currentStep == 1) ...[
                      // Buscador
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente por nombre o RIF...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchCustomerQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredClientes.length,
                          itemBuilder: (context, index) {
                            final c = filteredClientes[index];
                            final name = c['name'] ?? 'Sin nombre';
                            final rif = c['tax_id'] ?? 'Sin RIF';
                            final code = c['code_client_profit'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryColor.withOpacity(0.08),
                                  child: const Icon(Icons.person, color: AppColors.primaryColor),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  'RIF: $rif ${code.isNotEmpty ? "• Código: $code" : ""}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                onTap: () {
                                  setModalState(() {
                                    selectedCustomer = c;
                                    currentStep = 2;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (currentStep == 2) ...[
                      // Seleccionar Encuesta
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: plantillas.length,
                          itemBuilder: (context, index) {
                            final p = plantillas[index];
                            final titulo = p['titulo'] ?? 'Encuesta sin título';
                            final desc = p['descripcion'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.08),
                                  child: const Icon(Icons.assignment_outlined, color: Colors.green),
                                ),
                                title: Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: desc.isNotEmpty
                                    ? Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      )
                                    : null,
                                onTap: () {
                                  setModalState(() {
                                    selectedTemplate = p;
                                    currentStep = 3;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // Botón volver
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            currentStep = 1;
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver a Clientes'),
                      ),
                    ] else if (currentStep == 3) ...[
                      // Prioridad y Notas
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cliente: ${selectedCustomer?['name']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Plantilla: ${selectedTemplate?['titulo']}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 16),

                              // Selector de prioridad
                              const Text(
                                'Prioridad de la visita:',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Baja'),
                                    selected: selectedPriority == 4,
                                    selectedColor: Colors.green.withOpacity(0.2),
                                    onSelected: (selected) {
                                      if (selected) setModalState(() => selectedPriority = 4);
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Normal'),
                                    selected: selectedPriority == 3,
                                    selectedColor: Colors.orange.withOpacity(0.2),
                                    onSelected: (selected) {
                                      if (selected) setModalState(() => selectedPriority = 3);
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Urgente'),
                                    selected: selectedPriority == 2,
                                    selectedColor: Colors.red.withOpacity(0.2),
                                    onSelected: (selected) {
                                      if (selected) setModalState(() => selectedPriority = 2);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Notas
                              const Text(
                                'Notas / Observaciones:',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Añadir notas para la visita...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  currentStep = 2;
                                });
                              },
                              child: const Text('Volver'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                Navigator.pop(context); // Cerrar bottom sheet

                                // Generar visita local
                                final localVisitId = 'local_${DateTime.now().microsecondsSinceEpoch}';
                                final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                                
                                final visitData = {
                                  'id': localVisitId,
                                  'customer_id': selectedCustomer!['id'],
                                  'customer_name': selectedCustomer!['name'],
                                  'address': selectedCustomer!['direccion'] ?? '',
                                  'city': selectedCustomer!['city'] ?? '',
                                  'code_client_profit': selectedCustomer!['code_client_profit'] ?? '',
                                  'tax_id': selectedCustomer!['tax_id'] ?? '',
                                  'visit_date_from': todayStr,
                                  'visit_date_to': todayStr,
                                  'notes': notesController.text.trim(),
                                  'priority': selectedPriority,
                                  'status': 'PENDING',
                                  'sincronizado': 0,
                                };

                                // Guardar visita localmente
                                await GenericRepository.instance.insert(
                                  table: 'visitas',
                                  data: visitData,
                                  id: localVisitId,
                                );

                                // Refrescar lista de visitas
                                _loadVisitas();

                                // Navegar a encuesta inmediatamente
                                if (mounted) {
                                  final visitaModel = VisitaModel.fromJson(visitData);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EncuestaPage(
                                        visita: visitaModel,
                                        plantillaId: selectedTemplate!['id'],
                                        plantillaTitulo: selectedTemplate!['titulo'] ?? 'Encuesta',
                                      ),
                                    ),
                                  );
                                  _loadVisitas();
                                }
                              },
                              child: const Text('COMENZAR', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}