import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/cliente_model.dart';
import '../models/customer_analytics_model.dart';
import '../services/customer_analytics_service.dart';
import '../services/auth_service.dart';
import '../molecules/customer_dashboard_card.dart';
import '../molecules/customer_stats_card.dart';
import '../molecules/customer_churn_indicator.dart';
import 'nueva_visita_page.dart';

class CustomerDetailsPage extends StatefulWidget {
  final ClienteModel cliente;

  const CustomerDetailsPage({required this.cliente, super.key});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerAnalyticsService _analyticsService = CustomerAnalyticsService();

  // Analytics state
  Map<String, dynamic>? _dashboard;
  CustomerAnalyticsModel? _stats;
  CustomerAnalyticsModel? _ltv;
  CustomerAnalyticsModel? _rfm;
  Map<String, dynamic>? _valueMatrix;
  Map<String, dynamic>? _trend;
  Map<String, dynamic>? _salesCorrelation;

  bool _loadingAnalytics = false;
  String? _errorAnalytics;

  // Facturas state
  Map<String, dynamic>? _invoices;
  List<Map<String, dynamic>> _invoicesList = [];
  Map<String, dynamic>? _invoicesSummary;
  bool _loadingInvoices = false;
  String? _errorInvoices;
  String _selectedPeriod = 'all';

  // Productos state
  List<Map<String, dynamic>>? _topProducts;
  List<Map<String, dynamic>>? _suggestedProducts;
  bool _loadingProducts = false;
  String? _errorProducts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadInitialDetails();
  }

  void _loadInitialDetails() async {
    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';
      if (email.isNotEmpty && password.isNotEmpty) {
        final corr = await _analyticsService.getSalesCorrelation(
          customerId: widget.cliente.id,
          email: email,
          password: password,
        );
        if (mounted && corr != null && corr.isNotEmpty) {
          setState(() => _salesCorrelation = corr);
        }
      }
    } catch (_) {}
  }

  void _onTabChange() {
    if (_tabController.index == 1 &&
        !_loadingAnalytics &&
        _dashboard == null &&
        _errorAnalytics == null) {
      _loadAnalytics();
    } else if (_tabController.index == 2 &&
        !_loadingInvoices &&
        _invoices == null &&
        _errorInvoices == null) {
      _loadInvoices();
    } else if (_tabController.index == 3 &&
        !_loadingProducts &&
        _topProducts == null &&
        _suggestedProducts == null &&
        _errorProducts == null) {
      _loadProducts();
    }
  }

  Future<void> _loadAnalytics() async {
    if (_loadingAnalytics) return;

    setState(() {
      _loadingAnalytics = true;
      _errorAnalytics = null;
    });

    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Credenciales no disponibles');
      }

      // Antes: un solo Future fallando (timeout, backend lento, 500 en UN
      // endpoint) tumbaba el `Future.wait` completo y dejaba la pantalla en
      // blanco con un error genérico, aunque los otros 5 sí hubieran
      // respondido bien. La UI ya renderiza cada sección con
      // `if (_dashboard != null)` etc., así que basta con que cada llamada
      // falle sola (log + null) para que el resto de la pantalla cargue
      // normal y solo falte la tarjeta puntual que tuvo el problema.
      final results = await Future.wait([
        _analyticsService
            .getDashboard(
              customerId: widget.cliente.id,
              email: email,
              password: password,
            )
            .catchError((e) {
          print('❌ [Analytics] dashboard falló, sigo sin esa tarjeta: $e');
          return null;
        }),
        _analyticsService
            .getStats(
              customerId: widget.cliente.id,
              email: email,
              password: password,
            )
            .catchError((e) {
          print('❌ [Analytics] stats falló, sigo sin esa tarjeta: $e');
          return null;
        }),
        _analyticsService
            .getLTV(
              customerId: widget.cliente.id,
              email: email,
              password: password,
            )
            .catchError((e) {
          print('❌ [Analytics] LTV falló, sigo sin esa tarjeta: $e');
          return null;
        }),
        _analyticsService
            .getRFM(
              customerId: widget.cliente.id,
              email: email,
              password: password,
            )
            .catchError((e) {
          print('❌ [Analytics] RFM falló, sigo sin esa tarjeta: $e');
          return null;
        }),
        _analyticsService
            .getValueMatrix(
              customerId: widget.cliente.id,
              email: email,
              password: password,
            )
            .catchError((e) {
          print('❌ [Analytics] value-matrix falló, sigo sin esa tarjeta: $e');
          return null;
        }),
        _analyticsService
            .getTrend(
              customerId: widget.cliente.id,
              email: email,
              password: password,
              days: 30,
            )
            .catchError((e) {
          print('❌ [Analytics] trend falló, sigo sin esa tarjeta: $e');
          return null;
        }),
      ]);

      if (mounted) {
        setState(() {
          final dashModel = results[0] as CustomerAnalyticsModel?;
          _dashboard = dashModel == null ? null : _convertDashboardToMap(dashModel);
          _stats = results[1] as CustomerAnalyticsModel?;
          _ltv = results[2] as CustomerAnalyticsModel?;
          _rfm = results[3] as CustomerAnalyticsModel?;
          _valueMatrix = results[4] as Map<String, dynamic>?;
          _trend = results[5] as Map<String, dynamic>?;
          _loadingAnalytics = false;
          // Con degradación parcial, un error real solo aplica si TODO
          // vino vacío — si algo cargó, no tiene sentido tapar la pantalla
          // con un banner de error.
          if (results.every((r) => r == null)) {
            _errorAnalytics = 'No se pudo cargar la información del cliente';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorAnalytics = 'Error cargando analytics: $e';
          _loadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _loadInvoices({String? period}) async {
    setState(() {
      _loadingInvoices = true;
      _errorInvoices = null;
      if (period != null) _selectedPeriod = period;
    });

    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Credenciales no disponibles');
      }

      final invoices = await _analyticsService.getInvoices(
        customerId: widget.cliente.id,
        email: email,
        password: password,
        period: _selectedPeriod,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _invoices = invoices;
          if (invoices != null && invoices['data'] is List) {
            _invoicesList = List<Map<String, dynamic>>.from(invoices['data']);
          } else {
            _invoicesList = [];
          }
          _invoicesSummary = invoices?['summary'] as Map<String, dynamic>?;
          _loadingInvoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorInvoices = 'Error cargando facturas: $e';
          _loadingInvoices = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    if (_loadingProducts) return;

    setState(() {
      _loadingProducts = true;
      _errorProducts = null;
    });

    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Credenciales no disponibles');
      }

      final results = await Future.wait([
        _analyticsService.getTopProducts(
          customerId: widget.cliente.id,
          email: email,
          password: password,
          limit: 10,
        ),
        _analyticsService.getSuggestedProducts(
          customerId: widget.cliente.id,
          email: email,
          password: password,
        ),
      ]);

      if (mounted) {
        setState(() {
          _topProducts = results[0];
          _suggestedProducts = results[1];
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorProducts = 'Error cargando productos: $e';
          _loadingProducts = false;
        });
      }
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0.00';
    final amount = value is num ? value : double.tryParse(value.toString()) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    final str = value.toString();
    try {
      final dt = DateTime.parse(str);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  void _programarVisita() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaVisitaPage(
          clienteInicial: {
            'id': widget.cliente.id,
            'name': widget.cliente.name,
            'tax_id': widget.cliente.taxId,
            'code_client_profit': widget.cliente.codeClientProfit,
            'direccion': widget.cliente.direccion,
            'telefono': widget.cliente.telefono,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Detalle del Cliente',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildBottomActionBar(),
      body: Column(
        children: [
          // Encabezado con nombre adaptable a múltiples líneas y badges
          Container(
            color: AppColors.primaryColor.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    widget.cliente.name.isNotEmpty
                        ? widget.cliente.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre adaptable a pantalla sin cortes
                      Text(
                        widget.cliente.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (widget.cliente.codeClientProfit.isNotEmpty)
                            _buildHeaderBadge(
                              Icons.tag,
                              'Profit: ${widget.cliente.codeClientProfit}',
                              AppColors.primaryColor,
                            ),
                          if (widget.cliente.taxId.isNotEmpty)
                            _buildHeaderBadge(
                              Icons.badge_outlined,
                              widget.cliente.taxId,
                              Colors.blueGrey,
                            ),
                          _buildHeaderBadge(
                            widget.cliente.activo
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            widget.cliente.activo ? 'Activo' : 'Inactivo',
                            widget.cliente.activo ? Colors.green : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TabBar estilizado y desplazable (Scrollable)
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primaryColor,
              indicatorWeight: 3.0,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Detalles'),
                Tab(text: 'Analytics'),
                Tab(text: 'Facturas'),
                Tab(text: 'Productos'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetallesTab(),
                _buildAnalyticsTab(),
                _buildFacturasTab(),
                _buildProductosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _programarVisita,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.calendar_month, size: 20),
            label: const Text(
              'Programar Visita a este Cliente',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

  Widget _buildDetallesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Tarjeta 1: Información de Contacto y Ubicación
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contact_mail_outlined,
                        size: 20, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Contacto y Ubicación',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (widget.cliente.contactName?.isNotEmpty ?? false)
                  _buildDetailRow(Icons.person_outline, 'Contacto Principal',
                      widget.cliente.contactName ?? ''),
                if (widget.cliente.taxId.isNotEmpty)
                  _buildDetailRow(Icons.badge_outlined, 'RIF / Cédula',
                      widget.cliente.taxId, canCopy: true),
                if (widget.cliente.telefono.isNotEmpty)
                  _buildDetailRow(Icons.phone_outlined, 'Teléfono',
                      widget.cliente.telefono, canCopy: true),
                if (widget.cliente.email.isNotEmpty)
                  _buildDetailRow(Icons.email_outlined, 'Correo Electrónico',
                      widget.cliente.email, canCopy: true),
                if (widget.cliente.direccion.isNotEmpty)
                  _buildDetailRow(Icons.location_on_outlined, 'Dirección Fiscal',
                      widget.cliente.direccion),
                if (widget.cliente.city?.isNotEmpty ?? false)
                  _buildDetailRow(Icons.location_city_outlined, 'Ciudad / Zona',
                      widget.cliente.city ?? ''),
                if (widget.cliente.lat != null && widget.cliente.lng != null)
                  _buildDetailRow(
                    Icons.pin_drop_outlined,
                    'Coordenadas GPS',
                    '${widget.cliente.lat!.toStringAsFixed(6)}, ${widget.cliente.lng!.toStringAsFixed(6)}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta 2: Condiciones Comerciales
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 20, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Condiciones Comerciales',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (widget.cliente.codeClientProfit.isNotEmpty)
                  _buildDetailRow(Icons.qr_code_2, 'Código Profit Plus',
                      widget.cliente.codeClientProfit),
                if (_dashboard != null && _dashboard!['dias_credito'] != null)
                  _buildDetailRow(
                    Icons.schedule,
                    'Días de Crédito',
                    '${_dashboard!['dias_credito']} días',
                  ),
                if (widget.cliente.tipo.isNotEmpty)
                  _buildDetailRow(Icons.category_outlined, 'Tipo de Negocio',
                      widget.cliente.tipo),
                _buildDetailRow(
                  Icons.verified_outlined,
                  'Estado de la Cuenta',
                  widget.cliente.activo ? 'Activo para ventas' : 'Inactivo',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta 3: Relación Comercial y Visitas
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up,
                        size: 20, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Relación Comercial y Visitas',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (_salesCorrelation != null &&
                    _salesCorrelation!['conversion_rate_pct'] != null)
                  _buildDetailRow(
                    Icons.pie_chart_outline,
                    'Efectividad Visita → Venta',
                    '${_salesCorrelation!['conversion_rate_pct']}% (${_salesCorrelation!['visits_with_sale_7d'] ?? 0}/${_salesCorrelation!['total_visits'] ?? 0} visitas efectivas)',
                  ),
                if (_stats?.primeraCompra != null)
                  _buildDetailRow(
                    Icons.history,
                    'Primera Compra Histórica',
                    _formatDate(_stats!.primeraCompra),
                  ),
                if (_stats?.ultimaCompra != null)
                  _buildDetailRow(
                    Icons.shopping_cart_checkout,
                    'Última Factura Registrada',
                    _formatDate(_stats!.ultimaCompra),
                  ),
              ],
            ),
          ),
        ),

        // Tarjeta 4: Notas / Observaciones
        if (widget.cliente.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 20, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Notas y Observaciones',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    widget.cliente.notes,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    if (_loadingAnalytics) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_errorAnalytics != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorAnalytics!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
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
            const SizedBox(height: 8),
            Text(
              'El cliente podría no tener código Profit asignado',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Cargar Analytics'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_dashboard != null) CustomerDashboardCard(data: _dashboard!),
        if (_stats != null)
          CustomerStatsCard(data: _convertStatsToMap(_stats!)),
        if (_ltv != null)
          CustomerChurnIndicator(
            churnScore: _ltv!.churnScore,
            churnRisk: _ltv!.churnRisk,
          ),
        if (_rfm != null || _valueMatrix != null) _buildRfmAndValueMatrixCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRfmAndValueMatrixCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Segmentación y Clasificación',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_rfm != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Segmento RFM:', style: TextStyle(fontSize: 13)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Score: ${_rfm!.rfmScore ?? 0}/15',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_rfm!.frequency != null)
                _buildInlineRow('Frecuencia de compra',
                    '${_rfm!.frequency!.toStringAsFixed(1)} facturas/mes'),
            ],
            if (_valueMatrix != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Matriz de Valor:', style: TextStyle(fontSize: 13)),
                  Text(
                    (_valueMatrix!['clasificacion']?.toString() ?? 'N/A')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (_valueMatrix!['margen'] is Map) ...[
                const SizedBox(height: 6),
                _buildInlineRow(
                  'Margen comercial',
                  '${(_valueMatrix!['margen']['margen_pct'] ?? 0)}%',
                ),
              ],
              if (_valueMatrix!['esfuerzo'] is Map) ...[
                const SizedBox(height: 6),
                _buildInlineRow(
                  'Nivel de esfuerzo',
                  '${_valueMatrix!['esfuerzo']['nivel']?.toString().toUpperCase() ?? "BAJO"}',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductosTab() {
    if (_loadingProducts) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_errorProducts != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorProducts!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_topProducts == null && _suggestedProducts == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            const Text('Productos Comprados y Sugeridos'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.download),
              label: const Text('Cargar Productos'),
            ),
          ],
        ),
      );
    }

    final hasTop = _topProducts != null && _topProducts!.isNotEmpty;
    final hasSug = _suggestedProducts != null && _suggestedProducts!.isNotEmpty;

    if (!hasTop && !hasSug) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Sin productos registrados para este cliente',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (hasTop) _buildTopProductsCard(),
        if (hasSug) _buildSuggestedProductsCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTopProductsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Más Comprados por el Cliente',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.star, color: Colors.amber, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topProducts!.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final p = _topProducts![index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['articulo'] ?? p['co_art'] ?? 'Producto',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p['marca'] != null &&
                              p['marca'].toString().isNotEmpty)
                            Text(
                              'Marca: ${p['marca']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(p['total_usd']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          '${p['unidades'] ?? 0} unds (${p['num_facturas'] ?? 0} fac)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedProductsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sugeridos para Ofertar',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.lightbulb_outline,
                    color: Colors.orange, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Productos populares en su zona que aún no compra:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestedProducts!.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final p = _suggestedProducts![index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.add_shopping_cart,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['articulo'] ?? p['co_art'] ?? 'Producto',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Comprado por ${p['clientes_compran'] ?? 0} clientes (${p['unidades_zona'] ?? 0} unds en zona)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCurrency(p['precio_promedio_usd']),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacturasTab() {
    if (_loadingInvoices) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_errorInvoices != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorInvoices!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInvoices,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_invoices == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            const Text('Historial de Facturas Profit'),
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

    return Column(
      children: [
        // Resumen KPIs de facturación
        if (_invoicesSummary != null)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpiSummary(
                  'Facturas',
                  '${_invoicesSummary!['facturas'] ?? _invoicesList.length}',
                  Colors.blue,
                ),
                _buildKpiSummary(
                  'Facturado',
                  _formatCurrency(_invoicesSummary!['total_neto_usd']),
                  Colors.green,
                ),
                _buildKpiSummary(
                  'Saldo Pend.',
                  _formatCurrency(_invoicesSummary!['saldo_pendiente_usd']),
                  Colors.red,
                ),
              ],
            ),
          ),

        // Filtro por Período
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _buildFilterChip('Todas', 'all'),
              _buildFilterChip('30 días', '30d'),
              _buildFilterChip('90 días', '90d'),
              _buildFilterChip('1 año', '1y'),
            ],
          ),
        ),

        // Lista de Facturas
        Expanded(
          child: _invoicesList.isEmpty
              ? Center(
                  child: Text(
                    'No hay facturas en este período',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _invoicesList.length,
                  itemBuilder: (context, index) {
                    final fac = _invoicesList[index];
                    return _buildInvoiceCard(fac);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String periodKey) {
    final isSelected = _selectedPeriod == periodKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryColor : Colors.grey[700],
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => _loadInvoices(period: periodKey),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> fac) {
    final estado = fac['estado_pago']?.toString() ?? 'Pendiente';
    final Color estadoColor;
    if (estado.toLowerCase() == 'pagada') {
      estadoColor = Colors.green;
    } else if (estado.toLowerCase() == 'vencida') {
      estadoColor = Colors.red;
    } else {
      estadoColor = Colors.blue;
    }

    final saldoUsd = fac['saldo_usd'] != null
        ? (fac['saldo_usd'] as num).toDouble()
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt,
                        size: 18, color: AppColors.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Factura #${fac['fact_num'] ?? ""}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emisión: ${_formatDate(fac['fecha'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (fac['fecha_vencimiento'] != null)
                  Text(
                    'Vence: ${_formatDate(fac['fecha_vencimiento'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(fac['total_neto_usd']),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (fac['tot_neto'] != null)
                      Text(
                        'Bs. ${(fac['tot_neto'] as num).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                if (saldoUsd > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Saldo Pendiente',
                        style: TextStyle(fontSize: 10, color: Colors.red),
                      ),
                      Text(
                        _formatCurrency(saldoUsd),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (fac['unidades_totales'] != null || fac['lineas'] != null) ...[
              const SizedBox(height: 6),
              Text(
                '${fac['lineas'] ?? 0} renglones (${fac['unidades_totales'] ?? 0} unidades)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool canCopy = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (canCopy)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copiado al portapapeles'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.copy, size: 16, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _convertDashboardToMap(CustomerAnalyticsModel d) {
    return {
      'saldos_por_vencer': d.saldosPorVencer,
      'saldos_vencidos': d.saldosVencidos,
      'docs_por_vencer': d.docsPorVencer,
      'docs_vencidos': d.docsVencidos,
      'total_saldo': d.totalSaldo,
      'total_docs': d.totalDocs,
      'dias_credito': _dashboard?['dias_credito'] ?? 15,
    };
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

