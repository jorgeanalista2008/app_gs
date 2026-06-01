import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../services/auth_service.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';
import 'nuevo_prospecto_page.dart';
import '../services/sync_queue_service.dart';

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

  void _aplicarFiltro() {
    final base = _tabController.index == 0 ? _clientes : _prospectos;
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _clientesFiltrados = base;
      } else {
        _clientesFiltrados = base.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.codeClientProfit.toLowerCase().contains(query) ||
              c.taxId.toLowerCase().contains(query) ||
              c.telefono.contains(query);
        }).toList();
      }
    });
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

  Future<void> _syncClientes() async {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Primero subir prospectos u otras operaciones locales pendientes
      await SyncQueueService.instance.drain();

      final guardados = await _clienteRepo.sincronizarClientes(
        email: usuario['username'] ?? '',
        password: usuario['password'] ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(guardados > 0
                ? '✅ $guardados clientes nuevos sincronizados'
                : '✅ Ya tienes todos los clientes actualizados'),
            backgroundColor: guardados > 0 ? Colors.green : Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadClientes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e'), backgroundColor: Colors.red),
        );
      }
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
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Sincronizar clientes',
            onPressed: _isLoading ? null : _syncClientes,
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
      body: Column(
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
              color: AppColors.primaryColor.withOpacity(0.05),
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
                      : 'No tienes clientes. Presiona ☁️ para sincronizar.')
                  : 'No se encontraron ${esProspectos ? "prospectos" : "clientes"}',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.isEmpty && !esProspectos) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _syncClientes,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Sincronizar Clientes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
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
                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
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
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
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
        color: color.withOpacity(0.1),
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