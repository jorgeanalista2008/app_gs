import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/customer_analytics_model.dart';
import '../services/customer_analytics_service.dart';
import '../services/auth_service.dart';
import '../molecules/customer_dashboard_card.dart';
import '../molecules/customer_stats_card.dart';
import '../molecules/customer_churn_indicator.dart';
import '../core/app_colors.dart';

class CustomerDetailSheet extends StatefulWidget {
  final ClienteModel cliente;
  final CustomerAnalyticsService analyticsService;

  const CustomerDetailSheet({
    required this.cliente,
    required this.analyticsService,
  });

  @override
  State<CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends State<CustomerDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _dashboard;
  CustomerAnalyticsModel? _stats;
  CustomerAnalyticsModel? _ltv;
  Map<String, dynamic>? _invoices;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (_tabController.index == 1 && !_loading && _dashboard == null) {
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Credenciales no disponibles');
      }

      // Cargar en paralelo
      final results = await Future.wait([
        widget.analyticsService.getDashboard(
          customerId: widget.cliente.id,
          email: email,
          password: password,
        ),
        widget.analyticsService.getStats(
          customerId: widget.cliente.id,
          email: email,
          password: password,
        ),
        widget.analyticsService.getLTV(
          customerId: widget.cliente.id,
          email: email,
          password: password,
        ),
      ], eagerError: false);

      if (mounted) {
        setState(() {
          _dashboard = results[0] as Map<String, dynamic>?;
          _stats = results[1] as CustomerAnalyticsModel?;
          _ltv = results[2] as CustomerAnalyticsModel?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando analytics: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadInvoices() async {
    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      final invoices = await widget.analyticsService.getInvoices(
        customerId: widget.cliente.id,
        email: email,
        password: password,
        period: '30d',
        limit: 20,
      );

      if (mounted) {
        setState(() => _invoices = invoices);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando facturas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Encabezado con info del cliente
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      widget.cliente.name.isNotEmpty
                          ? widget.cliente.name[0].toUpperCase()
                          : '?',
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
                          widget.cliente.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.cliente.codeClientProfit.isNotEmpty)
                          Text(
                            'Cód: ${widget.cliente.codeClientProfit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TabBar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Detalles'),
                Tab(text: 'Analytics'),
                Tab(text: 'Facturas'),
              ],
              indicatorColor: AppColors.primaryColor,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: Colors.grey,
            ),

            // TabBarView con contenido
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetallesTab(),
                  _buildAnalyticsTab(),
                  _buildFacturasTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetallesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailRow(Icons.badge, 'RIF', widget.cliente.taxId),
        _buildDetailRow(Icons.phone, 'Teléfono', widget.cliente.telefono),
        _buildDetailRow(Icons.email, 'Email', widget.cliente.email),
        _buildDetailRow(
            Icons.location_on, 'Dirección', widget.cliente.direccion),
        _buildDetailRow(Icons.category, 'Tipo', widget.cliente.tipo),
        _buildDetailRow(
          Icons.check_circle,
          'Estado',
          widget.cliente.activo ? 'Activo' : 'Inactivo',
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_dashboard == null && _stats == null && _ltv == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Sin datos de Profit',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_dashboard != null) CustomerDashboardCard(data: _dashboard!),
        if (_stats != null) CustomerStatsCard(data: _convertStatsToMap(_stats!)),
        if (_ltv != null)
          CustomerChurnIndicator(
            churnScore: _ltv!.churnScore,
            churnRisk: _ltv!.churnRisk,
          ),
      ],
    );
  }

  Widget _buildFacturasTab() {
    if (_invoices == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Tap para cargar historial de facturas'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInvoices,
              icon: const Icon(Icons.download),
              label: const Text('Cargar Facturas'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Historial de Facturas (últimos 30 días)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // Aquí se mostrarían las facturas del _invoices
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Feature en desarrollo',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
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
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _convertStatsToMap(CustomerAnalyticsModel stats) {
    return {
      'num_facturas': stats.numFacturas,
      'dias_sin_comprar': stats.diasSinComprar,
      'total_neto_usd': stats.totalNetoUsd,
      'primera_compra': stats.primeraCompra,
      'ultima_compra': stats.ultimaCompra,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
