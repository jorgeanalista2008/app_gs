import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ClienteRepository _clienteRepo = ClienteRepository();
  final TextEditingController _searchController = TextEditingController();

  List<ClienteModel> _clientes = [];
  List<ClienteModel> _clientesFiltrados = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientes = await _clienteRepo.getMisClientes(); // <-- CORREGIDO
      if (mounted) {
        setState(() {
          _clientes = clientes;
          _clientesFiltrados = clientes;
          _isLoading = false;
        });
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

  void _filtrarClientes(String query) {
    setState(() {
      if (query.isEmpty) {
        _clientesFiltrados = _clientes;
      } else {
        _clientesFiltrados = _clientes.where((cliente) {
          return cliente.name.toLowerCase().contains(query.toLowerCase()) ||
                 cliente.codeClientProfit.toLowerCase().contains(query.toLowerCase()) ||
                 cliente.taxId.toLowerCase().contains(query.toLowerCase()) ||
                 cliente.telefono.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Clientes'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
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
                    '${_clientesFiltrados.length} de ${_clientes.length} clientes',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Contenido principal
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    // Error
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Reintentar',
              onPressed: _loadClientes,
            ),
          ],
        ),
      );
    }

    // Lista vacía
    if (_clientesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No tienes clientes asignados'
                  : 'No se encontraron clientes',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Lista de clientes
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
                  cliente.name.isNotEmpty
                      ? cliente.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (cliente.codeClientProfit.isNotEmpty)
                      Text(
                        'Cód: ${cliente.codeClientProfit}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    if (cliente.taxId.isNotEmpty)
                      Text(
                        'RIF: ${cliente.taxId}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),

              // Badge de activo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cliente.activo
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cliente.activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cliente.activo ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Icono de navegación
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    child: Text(
                      cliente.name.isNotEmpty
                          ? cliente.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (cliente.codeClientProfit.isNotEmpty)
                          Text(
                            'Código: ${cliente.codeClientProfit}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Detalles
              if (cliente.taxId.isNotEmpty)
                _buildDetailRow(Icons.badge, 'RIF', cliente.taxId),
              if (cliente.telefono.isNotEmpty)
                _buildDetailRow(Icons.phone, 'Teléfono', cliente.telefono),
              if (cliente.email.isNotEmpty)
                _buildDetailRow(Icons.email, 'Email', cliente.email),
              if (cliente.direccion.isNotEmpty)
                _buildDetailRow(Icons.location_on, 'Dirección', cliente.direccion),
              if (cliente.tipo.isNotEmpty)
                _buildDetailRow(Icons.category, 'Tipo', cliente.tipo),
              _buildDetailRow(
                Icons.check_circle,
                'Estado',
                cliente.activo ? 'Activo' : 'Inactivo',
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}