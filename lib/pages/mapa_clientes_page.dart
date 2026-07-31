import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../services/database_helper.dart';
import '../services/location_service.dart';

class MapaClientesPage extends StatefulWidget {
  const MapaClientesPage({super.key});

  @override
  State<MapaClientesPage> createState() => _MapaClientesPageState();
}

class _MapaClientesPageState extends State<MapaClientesPage> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _visitas = [];
  bool _isLoading = true;
  LatLng? _miPosicion;
  Map<String, dynamic>? _clienteSeleccionado;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getMyLocation();
  }

  Future<void> _getMyLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _miPosicion = LatLng(position.latitude, position.longitude);
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final clientes = await _db.getClientes();
      final visitas = await _db.getVisitas();

      if (mounted) {
        setState(() {
          _clientes = clientes;
          _visitas = visitas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _clienteTieneVisita(String clienteId) {
    return _visitas.any((v) => v['customer_id'] == clienteId);
  }

  int _contarVisitas(String clienteId) {
    return _visitas.where((v) => v['customer_id'] == clienteId).length;
  }

  Future<void> _actualizarCoordenadas(Map<String, dynamic> cliente) async {
    if (_miPosicion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación'), backgroundColor: Colors.red),
      );
      return;
    }

    final db = await _db.database;
    await db.update(
      'clientes',
      {
        'lat': _miPosicion!.latitude,
        'lng': _miPosicion!.longitude,
        'coordenadas_actualizadas': 1,
      },
      where: 'id = ?',
      whereArgs: [cliente['id']],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Coordenadas de ${cliente['name']} actualizadas'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _loadData();
    setState(() => _clienteSeleccionado = null);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Mi posición
    if (_miPosicion != null) {
      markers.add(
        Marker(
          point: _miPosicion!,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location,
              color: AppColors.accentColor, size: 40),
        ),
      );
    }

    // Clientes con coordenadas
    for (var cliente in _clientes) {
      final lat = cliente['lat'];
      final lng = cliente['lng'];
      if (lat != null && lng != null) {
        final tieneVisita = _clienteTieneVisita(cliente['id']?.toString() ?? '');
        final visitasCount = _contarVisitas(cliente['id']?.toString() ?? '');

        markers.add(
          Marker(
            point: LatLng(lat is double ? lat : double.tryParse(lat.toString()) ?? 0,
                          lng is double ? lng : double.tryParse(lng.toString()) ?? 0),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                setState(() => _clienteSeleccionado = cliente);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                    ),
                    child: Text(
                      cliente['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    tieneVisita ? Icons.location_on : Icons.location_on_outlined,
                    color: tieneVisita
                        ? AppColors.successColor
                        : AppColors.errorColor,
                    size: 30,
                  ),
                  if (visitasCount > 0)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: AppColors.successColor,
                          shape: BoxShape.circle),
                      child: Text('$visitasCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8)),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mapa de Clientes'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Ir a mi ubicación',
            onPressed: _getMyLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : Stack(
              children: [
                // Mapa
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _miPosicion ?? const LatLng(10.0, -66.0),
                    initialZoom: 12.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.solsumed.app',
                    ),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),

                // Panel inferior: cliente seleccionado
                if (_clienteSeleccionado != null)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _buildClientePanel(_clienteSeleccionado!),
                  ),

                // Leyenda
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLeyenda(Icons.location_on, Colors.green, 'Visitado'),
                        const SizedBox(height: 4),
                        _buildLeyenda(Icons.location_on_outlined, Colors.red, 'Sin visitar'),
                        const SizedBox(height: 4),
                        _buildLeyenda(Icons.my_location, Colors.blue, 'Mi posición'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClientePanel(Map<String, dynamic> cliente) {
    final tieneVisita = _clienteTieneVisita(cliente['id']?.toString() ?? '');
    final visitasCount = _contarVisitas(cliente['id']?.toString() ?? '');
    final tieneCoordenadas = cliente['lat'] != null && cliente['lng'] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cliente['name'] ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _clienteSeleccionado = null),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('RIF: ${cliente['tax_id'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(tieneVisita ? Icons.check_circle : Icons.cancel, size: 16, color: tieneVisita ? Colors.green : Colors.red),
              const SizedBox(width: 6),
              Text(
                tieneVisita ? '$visitasCount visita(s) realizada(s)' : 'Sin visitas',
                style: TextStyle(fontSize: 13, color: tieneVisita ? Colors.green : Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(tieneCoordenadas ? Icons.gps_fixed : Icons.gps_off, size: 16,
                  color: tieneCoordenadas ? Colors.green : Colors.grey),
              const SizedBox(width: 6),
              Text(
                tieneCoordenadas ? 'Coordenadas registradas' : 'Sin coordenadas',
                style: TextStyle(fontSize: 13, color: tieneCoordenadas ? Colors.green : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _actualizarCoordenadas(cliente),
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Actualizar coordenadas con mi posición'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeyenda(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
