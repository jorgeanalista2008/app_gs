// pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/lot_repository.dart';
import '../models/delivery_history_model.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<DeliveryHistory> _entregas = [];
  List<DeliveryHistory> _entregasFiltradas = [];
  bool _isLoading = true;
  String? _userId;
  String _errorMessage = '';
  
  // Filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _filtroBusqueda = '';
  String _estadoFiltro = 'todos'; // 'todos', 'entregado', 'pendiente'
  
  // Paginación
  int _paginaActual = 1;
  final int _limitePorPagina = 20;
  bool _hayMasDatos = true;
  bool _cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      
      if (_userId == null || _userId!.isEmpty) {
        throw Exception('Usuario no autenticado');
      }
      
      // Intentar obtener historial específico primero
      List<DeliveryHistory> historial = await LotRepository().getDeliveryHistory(
        userId: _userId!,
        startDate: _fechaInicio,
        endDate: _fechaFin,
        limit: _limitePorPagina,
        offset: 0,
      );
      
      // Si no hay endpoint específico, usar paquetes entregados
      if (historial.isEmpty) {
        historial = await LotRepository().getDeliveryHistory(
          userId: _userId!,
        );
      }
      
      setState(() {
        _entregas = historial;
        _entregasFiltradas = _aplicarFiltros(historial);
        _hayMasDatos = historial.length >= _limitePorPagina;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error cargando historial: $e');
      setState(() {
        _errorMessage = 'Error cargando historial: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarMasDatos() async {
    if (_cargandoMas || !_hayMasDatos || _userId == null) return;
    
    setState(() => _cargandoMas = true);
    
    try {
      final nuevaPagina = await LotRepository().getDeliveryHistory(
        userId: _userId!,
        startDate: _fechaInicio,
        endDate: _fechaFin,
        limit: _limitePorPagina,
        offset: _paginaActual * _limitePorPagina,
      );
      
      if (nuevaPagina.isNotEmpty) {
        setState(() {
          _entregas.addAll(nuevaPagina);
          _entregasFiltradas = _aplicarFiltros(_entregas);
          _paginaActual++;
          _hayMasDatos = nuevaPagina.length >= _limitePorPagina;
        });
      } else {
        setState(() => _hayMasDatos = false);
      }
    } catch (e) {
      print('❌ Error cargando más datos: $e');
    } finally {
      setState(() => _cargandoMas = false);
    }
  }

  List<DeliveryHistory> _aplicarFiltros(List<DeliveryHistory> entregas) {
    List<DeliveryHistory> filtradas = entregas;
    
    // Filtrar por estado
    if (_estadoFiltro != 'todos') {
      filtradas = filtradas.where((e) => 
        e.estado.toLowerCase().contains(_estadoFiltro)
      ).toList();
    }
    
    // Filtrar por búsqueda
    if (_filtroBusqueda.isNotEmpty) {
      final busqueda = _filtroBusqueda.toLowerCase();
      filtradas = filtradas.where((e) =>
        e.loteId.toLowerCase().contains(busqueda) ||
        e.cliente.toLowerCase().contains(busqueda) ||
        e.producto.toLowerCase().contains(busqueda) ||
        e.observaciones.toLowerCase().contains(busqueda)
      ).toList();
    }
    
    // Ordenar por fecha más reciente primero
    filtradas.sort((a, b) => b.fechaEntrega.compareTo(a.fechaEntrega));
    
    return filtradas;
  }

  void _aplicarFiltroEstado(String estado) {
    setState(() {
      _estadoFiltro = estado;
      _entregasFiltradas = _aplicarFiltros(_entregas);
    });
  }

  void _buscar(String texto) {
    setState(() {
      _filtroBusqueda = texto;
      _entregasFiltradas = _aplicarFiltros(_entregas);
    });
  }

  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (fecha != null) {
      setState(() {
        _fechaInicio = fecha;
        _cargarDatos();
      });
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? DateTime.now(),
      firstDate: _fechaInicio ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (fecha != null) {
      setState(() {
        _fechaFin = fecha;
        _cargarDatos();
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _filtroBusqueda = '';
      _estadoFiltro = 'todos';
      _cargarDatos();
    });
  }

  void _mostrarDetalles(DeliveryHistory entrega) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildDetallesSheet(entrega),
    );
  }

  Widget _buildDetallesSheet(DeliveryHistory entrega) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detalles de Entrega',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Información principal
          _buildDetalleItem('📦 Lote', entrega.loteId),
          _buildDetalleItem('📋 Paquete', entrega.producto),
          _buildDetalleItem('👤 Cliente', entrega.cliente),
          _buildDetalleItem('📅 Fecha', entrega.fechaFormateada),
          _buildDetalleItem('📍 Estado', entrega.estado),
          
          if (entrega.cantidad > 1) 
            _buildDetalleItem('🔢 Cantidad', entrega.cantidad.toString()),
          
          if (entrega.observaciones.isNotEmpty)
            _buildDetalleItem('📝 Observaciones', entrega.observaciones),
          
          if (entrega.facturas != null && entrega.facturas!.isNotEmpty)
            _buildDetalleItem('🧾 Facturas', entrega.facturas!),
          
          // Ubicación
          if (entrega.tieneUbicacion) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('📍 Ubicación de Entrega:', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Lat: ${entrega.latitud!.toStringAsFixed(6)}'),
            Text('Lng: ${entrega.longitud!.toStringAsFixed(6)}'),
          ],
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntregaItem(DeliveryHistory entrega) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entrega.estado == 'Entregado' 
              ? Colors.green 
              : Colors.orange,
          child: Icon(
            entrega.estado == 'Entregado' 
                ? Icons.check 
                : Icons.pending,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          entrega.loteId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entrega.cliente),
            Text('${entrega.fechaCorta} - ${entrega.hora}'),
            if (entrega.observaciones.isNotEmpty)
              Text(
                entrega.observaciones,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _mostrarDetalles(entrega),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por lote, cliente, etc...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _buscar(''),
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: _buscar,
          ),
          
          const SizedBox(height: 12),
          
          // Filtros de fecha
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fechaInicio != null
                        ? DateFormat('dd/MM/yy').format(_fechaInicio!)
                        : 'Desde',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _seleccionarFechaInicio,
                ),
              ),
              const SizedBox(width: 8),
              const Text('a', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fechaFin != null
                        ? DateFormat('dd/MM/yy').format(_fechaFin!)
                        : 'Hasta',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _seleccionarFechaFin,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Filtros de estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFiltro('Todos', 'todos'),
                const SizedBox(width: 8),
                _buildChipFiltro('Entregados', 'entregado'),
                const SizedBox(width: 8),
                _buildChipFiltro('Pendientes', 'pendiente'),
                if (_fechaInicio != null || _fechaFin != null || _filtroBusqueda.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      label: const Text('Limpiar filtros'),
                      avatar: const Icon(Icons.clear_all, size: 16),
                      onPressed: _limpiarFiltros,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _estadoFiltro == value,
      onSelected: (_) => _aplicarFiltroEstado(value),
      avatar: _estadoFiltro == value 
          ? const Icon(Icons.check, size: 16) 
          : null,
    );
  }

  Widget _buildResumen() {
    if (_entregas.isEmpty) return const SizedBox();
    
    final total = _entregas.length;
    final entregados = _entregas.where((e) => e.estado == 'Entregado').length;
    final pendientes = _entregas.where((e) => e.estado == 'Pendiente').length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumenItem('Total', total.toString(), Icons.list),
          _buildResumenItem('Entregados', entregados.toString(), Icons.check_circle),
          _buildResumenItem('Pendientes', pendientes.toString(), Icons.pending),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Entregas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportarHistorial,
            tooltip: 'Exportar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen
          _buildResumen(),
          
          // Filtros
          _buildFiltros(),
          
          // Contenido
          Expanded(
            child: _buildContenido(),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando historial...'),
          ],
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarDatos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    
    if (_entregasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay entregas registradas',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_fechaInicio != null || _fechaFin != null || _filtroBusqueda.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Prueba con otros filtros',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _limpiarFiltros,
                child: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      );
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _cargarMasDatos();
        }
        return false;
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_entregasFiltradas.length} entregas encontradas',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView.builder(
                itemCount: _entregasFiltradas.length + (_hayMasDatos ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _entregasFiltradas.length) {
                    return _buildEntregaItem(_entregasFiltradas[index]);
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _cargandoMas
                            ? const CircularProgressIndicator()
                            : const Text('No hay más entregas'),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarHistorial() async {
    // Aquí puedes implementar exportación a CSV, Excel, PDF, etc.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Historial'),
        content: const Text('Selecciona el formato de exportación:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportarCSV();
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportarPDF();
            },
            child: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarCSV() async {
    // Implementación básica de exportación a CSV
    final csv = StringBuffer();
    
    // Encabezados
    csv.writeln('Lote,Cliente,Producto,Fecha,Estado,Observaciones,Ubicacion');
    
    // Datos
    for (var entrega in _entregas) {
      csv.writeln('"${entrega.loteId}","${entrega.cliente}",'
          '"${entrega.producto}","${entrega.fechaFormateada}",'
          '"${entrega.estado}","${entrega.observaciones}",'
          '"${entrega.latitud},${entrega.longitud}"');
    }
    
    // Aquí podrías guardar el archivo o compartirlo
    _showSnackbar('CSV generado (${_entregas.length} registros)');
  }

  Future<void> _exportarPDF() async {
    _showSnackbar('Exportación PDF en desarrollo');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}