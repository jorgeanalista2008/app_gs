# Plan de Integración de Analytics en App Mobile

> **Fecha**: 26/08/2026  
> **Estado**: 📋 Especificación de implementación  
> **Basado en**: Backend endpoints en `gsolsumed_backend/src/modules/salesperson/`  

---

## Resumen Actual

La app actualmente:
- ✅ Muestra listado de clientes en `lib/pages/clientes_page.dart`
- ✅ Tiene modelo `ClienteModel` con campo `codeClientProfit`
- ✅ Usa patrón de autenticación offline (email+password) en `ClienteRepository`
- ✅ Estructura de carpetas con `services`, `repositories`, `models`, `pages`
- ❌ **No consume endpoints de analytics del backend**

---

## Endpoints Disponibles en Backend

| Endpoint | Retorna | Caso de Uso |
|----------|---------|------------|
| `/salesperson/auth/customers/:customerId/dashboard` | Saldos, deuda | Panel financiero |
| `/salesperson/auth/customers/:customerId/stats` | Facturas, USD, días sin comprar | Estadísticas rápidas |
| `/salesperson/auth/customers/:customerId/invoices` | Historial paginado | Detalles de compras |
| `/salesperson/auth/customers/:customerId/rfm` | Segmentación RFM | Valor del cliente |
| `/salesperson/auth/customers/:customerId/value-matrix` | Margen vs esfuerzo | Priorización |
| `/salesperson/auth/customers/:customerId/ltv` | LTV, churn risk | Riesgo y proyección |
| `/salesperson/auth/customers/:customerId/trend` | Tendencia N días | Comportamiento |
| `/salesperson/auth/churn-alerts` | Clientes en riesgo | Alertas críticas |

---

## Plan de Implementación

### Fase 1: Crear Servicios y Repositorio

#### 1.1 Crear modelo de Analytics
**Archivo**: `lib/models/customer_analytics_model.dart`

```dart
class CustomerAnalyticsModel {
  // Dashboard
  final double? saldosPorVencer;
  final double? saldosVencidos;
  final int? docsPorVencer;
  final int? docsVencidos;
  
  // Stats
  final int? numFacturas;
  final String? primeraCompra;
  final String? ultimaCompra;
  final double? totalNetoUSD;
  final int? diasSinComprar;
  
  // RFM
  final int? recencyDias;
  final double? frequency;
  final double? monetaryTotal;
  
  // LTV
  final double? ltvProyectado12m;
  final double? ltvProyectado24m;
  final double? margenPct;
  
  // Churn
  final int? churnScore;
  final String? churnRisk;
  
  CustomerAnalyticsModel({
    this.saldosPorVencer,
    this.saldosVencidos,
    // ... más campos
  });
  
  factory CustomerAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return CustomerAnalyticsModel(
      saldosPorVencer: (json['saldos_por_vencer'] as num?)?.toDouble(),
      saldosVencidos: (json['saldos_vencidos'] as num?)?.toDouble(),
      // ... parsear más campos
    );
  }
}
```

#### 1.2 Crear servicio de Analytics
**Archivo**: `lib/services/customer_analytics_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/env.dart';
import '../models/customer_analytics_model.dart';

class CustomerAnalyticsService {
  static final CustomerAnalyticsService _instance = 
    CustomerAnalyticsService._internal();
  
  factory CustomerAnalyticsService() => _instance;
  CustomerAnalyticsService._internal();
  
  /// Dashboard del cliente (saldos, deuda, desglose)
  Future<Map<String, dynamic>?> getDashboard({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/dashboard'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Credenciales inválidas');
      } else if (response.statusCode == 403) {
        throw Exception('Cliente no asignado');
      }
      return null;
    } catch (e) {
      print('❌ Error getting dashboard: $e');
      rethrow;
    }
  }

  /// Estadísticas de compra del cliente
  Future<Map<String, dynamic>?> getStats({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/stats'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting stats: $e');
      rethrow;
    }
  }

  /// Historial de facturas (con filtros opcionales)
  Future<Map<String, dynamic>?> getInvoices({
    required String customerId,
    required String email,
    required String password,
    String? period = '30d',
    int? page = 1,
    int? limit = 10,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/invoices'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (period != null) 'period': period,
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting invoices: $e');
      rethrow;
    }
  }

  /// RFM Analysis
  Future<Map<String, dynamic>?> getRFM({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/rfm'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting RFM: $e');
      rethrow;
    }
  }

  /// LTV + Churn Risk
  Future<Map<String, dynamic>?> getLTV({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/ltv'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting LTV: $e');
      rethrow;
    }
  }

  /// Tendencia de compras (últimos N días)
  Future<Map<String, dynamic>?> getTrend({
    required String customerId,
    required String email,
    required String password,
    int days = 30,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/trend'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'days': days,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting trend: $e');
      rethrow;
    }
  }

  /// Alertas de churn
  Future<List<Map<String, dynamic>>?> getChurnAlerts({
    required String email,
    required String password,
    int minDaysWithoutPurchase = 30,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse(
        '${Env.apiBaseUrl}/salesperson/auth/churn-alerts'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'minDaysWithoutPurchase': minDaysWithoutPurchase,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return null;
      }
      return null;
    } catch (e) {
      print('❌ Error getting churn alerts: $e');
      rethrow;
    }
  }
}
```

---

### Fase 2: UI Components

#### 2.1 Widget de Dashboard del Cliente
**Archivo**: `lib/molecules/customer_dashboard_card.dart`

```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CustomerDashboardCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onRetry;

  const CustomerDashboardCard({
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Análisis Financiero', 
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            // Saldos
            _buildRow(
              'Saldos por vencer',
              '\$${(data['saldos_por_vencer'] ?? 0).toStringAsFixed(2)}',
              Colors.green,
            ),
            _buildRow(
              'Saldos vencidos',
              '\$${(data['saldos_vencidos'] ?? 0).toStringAsFixed(2)}',
              Colors.red,
            ),
            
            const Divider(margin: EdgeInsets.symmetric(vertical: 12)),
            
            // Documentos
            _buildRow(
              'Docs por vencer',
              '${data['docs_por_vencer'] ?? 0}',
              Colors.blue,
            ),
            _buildRow(
              'Docs vencidos',
              '${data['docs_vencidos'] ?? 0}',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 2.2 Widget de Estadísticas Rápidas
**Archivo**: `lib/molecules/customer_stats_card.dart`

```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CustomerStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomerStatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final numFacturas = data['num_facturas'] ?? 0;
    final diasSinComprar = data['dias_sin_comprar'] ?? 0;
    final totalUsd = data['total_neto_usd'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estadísticas de Compra',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Facturas', '$numFacturas'),
                _buildStat('Total USD', '\$$totalUsd'),
                _buildStat('Días sin comprar', '$diasSinComprar'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }
}
```

#### 2.3 Widget de Riesgo de Churn
**Archivo**: `lib/molecules/customer_churn_indicator.dart`

```dart
import 'package:flutter/material.dart';

class CustomerChurnIndicator extends StatelessWidget {
  final int churnScore;
  final String churnRisk;

  const CustomerChurnIndicator({
    required this.churnScore,
    required this.churnRisk,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColorByRisk(churnRisk);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getIconByRisk(churnRisk),
              color: color,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Riesgo de Churn',
                    style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${churnRisk.toUpperCase()} (Score: $churnScore/100)',
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: churnScore / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorByRisk(String risk) {
    switch (risk.toLowerCase()) {
      case 'bajo':
        return Colors.green;
      case 'medio':
        return Colors.orange;
      case 'alto':
        return Colors.red;
      case 'crítico':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconByRisk(String risk) {
    switch (risk.toLowerCase()) {
      case 'bajo':
        return Icons.trending_up;
      case 'medio':
        return Icons.trending_flat;
      case 'alto':
      case 'crítico':
        return Icons.trending_down;
      default:
        return Icons.help;
    }
  }
}
```

---

### Fase 3: Modificar Pantalla de Clientes

#### 3.1 Agregar Tab de Analytics
**Modificar**: `lib/pages/clientes_page.dart`

Cambios sugeridos:
1. Cuando hace tap en un cliente, mostrar panel con tabs:
   - **Detalles** (información básica — ya existe)
   - **Analytics** (dashboard, stats, RFM, LTV)
   - **Facturas** (historial de invoices)

Ejemplo de código a agregar:

```dart
class _ClientesPageState extends State<ClientesPage> {
  final CustomerAnalyticsService _analyticsService = 
    CustomerAnalyticsService();

  // ...existente...

  void _mostrarDetalleClienteConAnalytics(ClienteModel cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CustomerDetailSheet(
          cliente: cliente,
          analyticsService: _analyticsService,
        );
      },
    );
  }
}
```

#### 3.2 Crear Sheet de Detalle con Analytics
**Archivo**: `lib/organisms/customer_detail_sheet.dart`

```dart
import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../services/customer_analytics_service.dart';
import '../molecules/customer_dashboard_card.dart';
import '../molecules/customer_stats_card.dart';
import '../molecules/customer_churn_indicator.dart';
import '../services/auth_service.dart';

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
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _ltv;
  
  bool _loading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      final [dashboard, stats, ltv] = await Future.wait([
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
      ]);

      setState(() {
        _dashboard = dashboard;
        _stats = stats;
        _ltv = ltv;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando analytics: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Detalles'),
                Tab(text: 'Analytics'),
                Tab(text: 'Facturas'),
              ],
            ),
            
            // Content
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
    // ... existente ...
    return Center(child: Text('Detalles básicos'));
  }

  Widget _buildAnalyticsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_dashboard != null)
          CustomerDashboardCard(data: _dashboard!),
        if (_stats != null)
          CustomerStatsCard(data: _stats!),
        if (_ltv != null)
          CustomerChurnIndicator(
            churnScore: (_ltv!['churn']?['churn_score'] ?? 0).toInt(),
            churnRisk: _ltv!['churn']?['churn_risk'] ?? 'desconocido',
          ),
      ],
    );
  }

  Widget _buildFacturasTab() {
    return const Center(child: Text('Historial de facturas (próxima fase)'));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
```

---

### Fase 4: Página de Alertas de Churn

#### 4.1 Nueva página de alertas
**Archivo**: `lib/pages/churn_alerts_page.dart`

```dart
class ChurnAlertsPage extends StatefulWidget {
  const ChurnAlertsPage({super.key});

  @override
  State<ChurnAlertsPage> createState() => _ChurnAlertsPageState();
}

class _ChurnAlertsPageState extends State<ChurnAlertsPage> {
  final CustomerAnalyticsService _analyticsService = 
    CustomerAnalyticsService();
  
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    
    try {
      final user = AuthService.instance.currentUser;
      final email = user?['username']?.toString() ?? '';
      final password = user?['password']?.toString() ?? '';

      final alerts = await _analyticsService.getChurnAlerts(
        email: email,
        password: password,
        minDaysWithoutPurchase: 30,
        limit: 50,
      );

      setState(() {
        _alerts = alerts ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Churn'),
        backgroundColor: Colors.red,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(child: Text('No hay alertas'))
              : ListView.builder(
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: Icon(
                          Icons.warning,
                          color: Colors.red[700],
                        ),
                        title: Text(alert['name'] ?? 'Sin nombre'),
                        subtitle: Text(
                          'Score: ${alert['churn']?['churn_score'] ?? 0}',
                        ),
                        trailing: Chip(
                          label: Text(
                            alert['churn']?['churn_risk'] ?? 'Desconocido',
                          ),
                          backgroundColor: Colors.red[100],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
```

---

## Checklist de Implementación

### Paso 1: Crear Servicios
- [ ] Crear `lib/services/customer_analytics_service.dart`
- [ ] Crear `lib/models/customer_analytics_model.dart`
- [ ] Verificar que `Env.apiBaseUrl` está configurado

### Paso 2: Crear UI Components
- [ ] Crear `lib/molecules/customer_dashboard_card.dart`
- [ ] Crear `lib/molecules/customer_stats_card.dart`
- [ ] Crear `lib/molecules/customer_churn_indicator.dart`
- [ ] Crear `lib/organisms/customer_detail_sheet.dart`

### Paso 3: Modificar Pantallas
- [ ] Actualizar `lib/pages/clientes_page.dart` para llamar al detail sheet
- [ ] Crear `lib/pages/churn_alerts_page.dart`
- [ ] Agregar navegación a churn_alerts_page en main navigation

### Paso 4: Testing
- [ ] Probar conexión a endpoints de analytics
- [ ] Validar parsing de respuestas
- [ ] Verificar UI con datos reales
- [ ] Probar manejo de errores (cliente sin Profit code, etc.)

### Paso 5: Optimizaciones Futuras
- [ ] Cachear datos de analytics en SQLite
- [ ] Agregar gráficos de tendencias
- [ ] Mostrar comparación mes a mes
- [ ] Exportar reportes en PDF

---

## Estimación de Esfuerzo

| Fase | Tareas | Tiempo |
|------|--------|--------|
| 1 | Servicios + modelos | 2-3 horas |
| 2 | UI components | 3-4 horas |
| 3 | Integración en pantallas | 2-3 horas |
| 4 | Página de alertas | 1-2 horas |
| 5 | Testing + ajustes | 2-3 horas |
| **Total** | | **10-15 horas** |

---

## Notas Importantes

1. **Autenticación**: Los endpoints requieren email+password en cada call (offline-first)
2. **Campos opcionales**: Si falta `code_client_profit`, backend retorna `{"message": "Cliente sin código Profit", "data": null}`
3. **Rate limiting**: 600 req/min. Si la app hace muchas calls simultáneas, implementar caché
4. **Conexión**: Todos los endpoints retornan datos listos para parsear (sin nested data wrappers)
5. **Moneda**: USD por defecto en LTV/tendencias; Bs en dashboard/stats

---

## Referencias

- Endpoints del backend: `gsolsumed_backend/CUSTOMER_ANALYTICS_ENDPOINTS.md`
- Guía de consumo: `gsolsumed_backend/BACKEND_ANALYTICS_API.md`
- Estructura actual de app: `lib/pages/clientes_page.dart`
