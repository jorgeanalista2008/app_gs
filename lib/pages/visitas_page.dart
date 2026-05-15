import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/visita_model.dart';
import '../repositories/visita_repository.dart';
import '../atoms/app_button.dart';
import 'encuesta_page.dart';

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
       onTap: () async {
            final resultado = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EncuestaPage(visita: visita),
              ),
            );
            // Si se envió la encuesta, actualizar la lista
            if (resultado == true) {
              _loadVisitas();
            }
          },
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
}