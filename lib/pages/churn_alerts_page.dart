import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/customer_analytics_service.dart';
import '../services/auth_service.dart';
import '../organisms/customer_detail_sheet.dart';
import '../models/cliente_model.dart';

class ChurnAlertsPage extends StatefulWidget {
  const ChurnAlertsPage({super.key});

  @override
  State<ChurnAlertsPage> createState() => _ChurnAlertsPageState();
}

class _ChurnAlertsPageState extends State<ChurnAlertsPage> {
  final CustomerAnalyticsService _analyticsService =
      CustomerAnalyticsService();

  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
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

      final alerts = await _analyticsService.getChurnAlerts(
        email: email,
        password: password,
        minDaysWithoutPurchase: 30,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _alerts = alerts ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando alertas: $e';
          _loading = false;
        });
      }
    }
  }

  Color _getColorByRisk(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'bajo':
        return Colors.green;
      case 'medio':
        return Colors.orange;
      case 'alto':
        return Colors.red;
      case 'crítico':
        return const Color(0xFFB71C1C);
      default:
        return Colors.grey;
    }
  }

  IconData _getIconByRisk(String? risk) {
    switch (risk?.toLowerCase()) {
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

  void _mostrarDetalle(Map<String, dynamic> alert) {
    // Crear un ClienteModel simulado desde los datos del alert
    final cliente = ClienteModel(
      id: alert['id'] ?? '',
      name: alert['name'] ?? 'Sin nombre',
      codeClientProfit: alert['code_client_profit'] ?? '',
      taxId: alert['tax_id'] ?? '',
      telefono: alert['phone'] ?? '',
      email: alert['email'] ?? '',
      direccion: alert['address'] ?? '',
      activo: alert['active'] == true || alert['active'] == 1,
      tipo: alert['type'] ?? '',
      isProspect: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return CustomerDetailSheet(
          cliente: cliente,
          analyticsService: _analyticsService,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Churn'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
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
              onPressed: _loadAlerts,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              'Sin alertas de churn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Todos tus clientes están en buen estado',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        final churn = alert['churn'] as Map<String, dynamic>? ?? {};
        final churnScore = (churn['churn_score'] ?? 0) as int;
        final churnRisk = churn['churn_risk']?.toString() ?? 'desconocido';
        final color = _getColorByRisk(churnRisk);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: color.withValues(alpha: 0.02),
          child: InkWell(
            onTap: () => _mostrarDetalle(alert),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      _getIconByRisk(churnRisk),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['name'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (alert['code_client_profit'] != null)
                          Text(
                            'Cód: ${alert['code_client_profit']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              'Últimas compra: ${_formatDaysAgo(churn['dias_sin_comprar'] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Score Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$churnScore%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        churnRisk.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDaysAgo(dynamic dias) {
    if (dias == null) return 'N/A';
    final d = dias is int ? dias : int.tryParse(dias.toString()) ?? 0;
    if (d == 0) return 'Hoy';
    if (d == 1) return 'Ayer';
    if (d < 7) return 'Hace $d días';
    if (d < 30) return 'Hace ${(d / 7).toStringAsFixed(0)} semanas';
    return 'Hace ${(d / 30).toStringAsFixed(0)} meses';
  }
}
