import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import 'nuevo_prospecto_page.dart';
import '../services/sync_queue_service.dart';
import '../services/connectivity_service.dart';
import '../atoms/sync_status_chip.dart';
import '../organisms/connection_wrapper.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage>
    with SingleTickerProviderStateMixin {
  final ClienteRepository _clienteRepo = ClienteRepository();
  final AuthService _authService = AuthService.instance;
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<ClienteModel> _clientes = [];
  List<ClienteModel> _prospectos = [];
  List<ClienteModel> _clientesFiltrados = [];
  bool _isLoading = true;
  String? _error;

  // "Cerca de mí": si activo ordena la lista por distancia y muestra badge km.
  bool _cercaDeMiActivo = false;
  double? _miLat;
  double? _miLng;
  bool _obteniendoGps = false;
  final Map<String, double> _distanciasKm = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _aplicarFiltro();
    });
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _sincronizarDesdeApi();

      final clientes = await _clienteRepo.getClientesLocales();
      final prospectos = clientes.where((c) => c.isProspect).toList();
      if (mounted) {
        setState(() {
          _clientes = clientes.where((c) => !c.isProspect).toList();
          _prospectos = prospectos;
          _isLoading = false;
        });
        _aplicarFiltro();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar clientes: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Descarga clientes y prospectos oficializados del backend antes de leer
  /// SQLite, para que la lista se mantenga al día. Se ignora si no hay
  /// conexión o si no tenemos credenciales (usuario sin username/password
  /// locales, ej. login online sin fallback).
  Future<void> _sincronizarDesdeApi() async {
    final conectado = await ConnectivityService.instance.isConnected();
    if (!conectado) return;

    final user = _authService.currentUser;
    final email = user?['username']?.toString();
    final password = user?['password']?.toString();
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return;
    }

    try {
      await _clienteRepo.sincronizarClientes(email: email, password: password);
      await _clienteRepo.sincronizarProspectos(email: email, password: password);
    } catch (e) {
      print('⚠️ [ClientesPage] error sincronizando desde API: $e');
    }
  }

  /// Normaliza texto para búsqueda: minúsculas, sin acentos, sin espacios
  /// extras. Aplica al query y a cada campo del cliente.
  String _norm(String? s) {
    if (s == null) return '';
    var t = s.toLowerCase().trim();
    const from = 'áéíóúñü';
    const to = 'aeiounu';
    for (int i = 0; i < from.length; i++) {
      t = t.replaceAll(from[i], to[i]);
    }
    return t;
  }

  /// Normaliza RIF/cédula: quita guiones, puntos, espacios y prefijo (J/V/E/G).
  /// Permite buscar "J40199" y matchear "J-40199731-7", "J401997317", etc.
  String _normRif(String? s) {
    if (s == null) return '';
    return s
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  void _aplicarFiltro() {
    final base = _tabController.index == 0 ? _clientes : _prospectos;
    final rawQuery = _searchController.text.trim();
    final query = _norm(rawQuery);
    final queryRif = _normRif(rawQuery);
    List<ClienteModel> lista;

    if (query.isEmpty) {
      lista = List.of(base);
    } else {
      lista = base.where((c) {
        // Match RIF/código sin importar guiones o prefijo
        if (queryRif.length >= 3) {
          if (_normRif(c.taxId).contains(queryRif)) return true;
          if (_normRif(c.codeClientProfit).contains(queryRif)) return true;
        }

        // Match texto libre en TODOS los campos relevantes del modelo
        if (_norm(c.name).contains(query)) return true;
        if (_norm(c.codeClientProfit).contains(query)) return true;
        if (_norm(c.taxId).contains(query)) return true;
        if (_norm(c.telefono).contains(query)) return true;
        if (_norm(c.email).contains(query)) return true;
        if (_norm(c.direccion).contains(query)) return true;
        if (_norm(c.notes).contains(query)) return true;
        if (_norm(c.contactName).contains(query)) return true;
        if (_norm(c.city).contains(query)) return true;
        if (_norm(c.zoneCode).contains(query)) return true;
        if (_norm(c.tipo).contains(query)) return true;

        return false;
      }).toList();
    }

    if (_cercaDeMiActivo && _miLat != null && _miLng != null) {
      _distanciasKm.clear();
      for (final c in lista) {
        if (c.lat != null && c.lng != null) {
          _distanciasKm[c.id] = _distanciaKm(_miLat!, _miLng!, c.lat!, c.lng!);
        }
      }
      lista.sort((a, b) {
        final da = _distanciasKm[a.id] ?? double.infinity;
        final db = _distanciasKm[b.id] ?? double.infinity;
        return da.compareTo(db);
      });
    }

    setState(() => _clientesFiltrados = lista);
  }

  /// Haversine — distancia en km entre 2 coords GPS.
  double _distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // radio Tierra km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  String _formatearDistancia(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  Future<void> _toggleCercaDeMi() async {
    if (_cercaDeMiActivo) {
      setState(() {
        _cercaDeMiActivo = false;
        _distanciasKm.clear();
      });
      _aplicarFiltro();
      return;
    }
    setState(() => _obteniendoGps = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _miLat = pos.latitude;
        _miLng = pos.longitude;
        _cercaDeMiActivo = true;
      });
      _aplicarFiltro();
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _abrirNuevoProspecto() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NuevoProspectoPage()),
    );
    if (creado == true) {
      _tabController.animateTo(1);
      _loadClientes();
    }
  }

  void _filtrarClientes(String query) {
    _aplicarFiltro();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Clientes'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Clientes (${_clientes.length})'),
            Tab(text: 'Prospectos (${_prospectos.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _cercaDeMiActivo
                ? 'Quitar orden por cercanía'
                : 'Ordenar por cercanía a mi ubicación',
            icon: _obteniendoGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    _cercaDeMiActivo ? Icons.near_me : Icons.near_me_outlined,
                    color: Colors.white,
                  ),
            onPressed: _obteniendoGps ? null : _toggleCercaDeMi,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: SyncStatusChip(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevoProspecto,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Prospecto'),
      ),
      body: ConnectionWrapper(
        child: Column(
          children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: AppTextField(
              controller: _searchController,
              labelText: 'Buscar cliente',
              hintText: 'Nombre, RIF, código o teléfono...',
              icon: Icons.search,
              onSubmitted: _filtrarClientes,
            ),
          ),

          // Contador de resultados
          if (_clientesFiltrados.isNotEmpty && _searchController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryColor.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Text(
                    '${_clientesFiltrados.length} de ${(_tabController.index == 0 ? _clientes : _prospectos).length} ${_tabController.index == 0 ? "clientes" : "prospectos"}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Contenido principal
          Expanded(child: _buildContent()),
        ],
      ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            AppButton(text: 'Reintentar', onPressed: _loadClientes),
          ],
        ),
      );
    }

    if (_clientesFiltrados.isEmpty) {
      final esProspectos = _tabController.index == 1;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esProspectos ? Icons.person_add_outlined : Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? (esProspectos
                      ? 'No tienes prospectos. Usa el botón + para crear uno.'
                      : 'No tienes clientes. Conéctate a internet para cargarlos automáticamente.')
                  : 'No se encontraron ${esProspectos ? "prospectos" : "clientes"}',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClientes,
      color: AppColors.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clientesFiltrados.length,
        itemBuilder: (context, index) {
          final cliente = _clientesFiltrados[index];
          return _buildClienteCard(cliente);
        },
      ),
    );
  }

  Widget _buildClienteCard(ClienteModel cliente) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _mostrarDetalleCliente(cliente),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar con inicial
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  cliente.name.isNotEmpty ? cliente.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                ),
              ),
              const SizedBox(width: 16),

              // Info del cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (cliente.codeClientProfit.isNotEmpty)
                      Text('Cód: ${cliente.codeClientProfit}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    if (cliente.taxId.isNotEmpty)
                      Text('RIF: ${cliente.taxId}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    if (_cercaDeMiActivo && _distanciasKm.containsKey(cliente.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me, size: 12, color: AppColors.primaryColor),
                            const SizedBox(width: 3),
                            Text(
                              _formatearDistancia(_distanciasKm[cliente.id]!),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Badge
              _buildStatusBadge(cliente),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleCliente(ClienteModel cliente) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      cliente.name.isNotEmpty ? cliente.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cliente.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        if (cliente.codeClientProfit.isNotEmpty)
                          Text('Código: ${cliente.codeClientProfit}', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              if (cliente.taxId.isNotEmpty) _buildDetailRow(Icons.badge, 'RIF', cliente.taxId),
              if (cliente.telefono.isNotEmpty) _buildDetailRow(Icons.phone, 'Teléfono', cliente.telefono),
              if (cliente.email.isNotEmpty) _buildDetailRow(Icons.email, 'Email', cliente.email),
              if (cliente.direccion.isNotEmpty) _buildDetailRow(Icons.location_on, 'Dirección', cliente.direccion),
              if (cliente.tipo.isNotEmpty) _buildDetailRow(Icons.category, 'Tipo', cliente.tipo),
              _buildDetailRow(Icons.check_circle, 'Estado', cliente.activo ? 'Activo' : 'Inactivo'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ClienteModel c) {
    late Color color;
    late String text;
    if (c.isProspect && !c.sincronizado) {
      color = Colors.orange;
      text = 'Sin subir';
    } else if (c.isProspect && c.sincronizado) {
      color = Colors.blue;
      text = 'Subido';
    } else if (c.activo) {
      color = Colors.green;
      text = 'Activo';
    } else {
      color = Colors.red;
      text = 'Inactivo';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryColor),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }
}