import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_360_model.dart';
import '../core/app_colors.dart';

class Customer360Card extends StatelessWidget {
  final Customer360 customer360;

  const Customer360Card({
    Key? key,
    required this.customer360,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomerHeader(),
        const SizedBox(height: 16),
        _buildContactInfo(),
        const SizedBox(height: 16),
        _buildVisitsStats(),
        const SizedBox(height: 16),
        _buildProfitSummary(),
      ],
    );
  }

  Widget _buildCustomerHeader() {
    final customer = customer360.customer;
    final name = customer['name']?.toString() ?? 'Sin nombre';
    final code = customer['code_client_profit']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (code.isNotEmpty)
                      Text(
                        code,
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
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    final contact = customer360.contact;
    if (contact == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📞 Contacto',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (contact.phone != null) ...[
            _buildContactRow('Teléfono', contact.phone!, Icons.phone),
            const SizedBox(height: 6),
          ],
          if (contact.email != null) ...[
            _buildContactRow('Email', contact.email!, Icons.email),
            const SizedBox(height: 6),
          ],
          if (contact.address != null)
            _buildContactRow('Dirección', contact.address!, Icons.location_on),
        ],
      ),
    );
  }

  Widget _buildContactRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsStats() {
    final stats = customer360.visitsStats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.checklist_rtl,
            label: 'Visitas',
            value: stats.totalVisits.toString(),
            color: Colors.blue,
          ),
          if (stats.lastVisitDate != null)
            _buildStatItem(
              icon: Icons.calendar_today,
              label: 'Última visita',
              value: _formatDate(stats.lastVisitDate!),
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProfitSummary() {
    final profit = customer360.profitSummary;
    if (profit == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Resumen de Compras',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total (USD)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    '\$${profit.totalPurchasesUsd.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Últimos 30 días',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    '\$${profit.last30DaysVolume.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildKpiGrid(profit),
          if (profit.pendingBalanceUsd > 0 || profit.creditLimitUsd > 0) ...[
            const SizedBox(height: 12),
            _buildCreditRow(profit),
          ],
          if (profit.recentPurchases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Compras Recientes',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            ...(profit.recentPurchases as List).take(2).map((purchase) {
              final factNum = purchase['fact_num']?.toString() ?? '';
              final amount = purchase['amount']?.toString() ?? '0';
              final date = purchase['date']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#$factNum',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    Text(
                      '\$$amount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDate(DateTime.parse(date)),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  /// KPIs de apoyo para el vendedor en campo: cómo va el año contra el
  /// anterior, cuánto hace que no compra y cada cuánto suele comprar.
  Widget _buildKpiGrid(Customer360ProfitSummary profit) {
    final delta = profit.previousYearUsd > 0
        ? ((profit.currentYearUsd - profit.previousYearUsd) /
                profit.previousYearUsd) *
            100
        : null;

    // Se pasó del ritmo habitual de compra → señal de que hay que reactivarlo.
    final overdue = profit.avgDaysBetweenPurchases != null &&
        profit.daysSinceLastPurchase != null &&
        profit.daysSinceLastPurchase! > profit.avgDaysBetweenPurchases! * 2;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpiTile(
                'Año actual',
                '\$${profit.currentYearUsd.toStringAsFixed(0)}',
                subtitle: delta != null
                    ? '${delta >= 0 ? '▲' : '▼'} ${delta.abs().toStringAsFixed(0)}% vs año pasado'
                    : null,
                subtitleColor: delta == null
                    ? null
                    : (delta >= 0 ? Colors.green[700] : Colors.red[700]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiTile(
                'Facturas',
                '${profit.totalInvoices}',
                subtitle: profit.avgDaysBetweenPurchases != null
                    ? 'compra c/ ${profit.avgDaysBetweenPurchases}d'
                    : null,
              ),
            ),
          ],
        ),
        if (profit.daysSinceLastPurchase != null) ...[
          const SizedBox(height: 8),
          _kpiTile(
            'Última compra',
            'hace ${profit.daysSinceLastPurchase} días',
            subtitle: overdue ? '⚠ Fuera de su ritmo habitual' : null,
            subtitleColor: overdue ? Colors.orange[800] : null,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildCreditRow(Customer360ProfitSummary profit) {
    final over = profit.isOverCredit;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: over ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: over ? Colors.red[300]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo pendiente',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(
                '\$${profit.pendingBalanceUsd.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: over ? Colors.red[700] : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(over ? 'Sobregirado' : 'Crédito disponible',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(
                '\$${profit.availableCreditUsd.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: over ? Colors.red[700] : Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiTile(
    String label,
    String value, {
    String? subtitle,
    Color? subtitleColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: subtitleColor ?? Colors.grey[600],
                fontWeight: subtitleColor != null ? FontWeight.w600 : null,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Hoy';
      } else if (dateOnly == yesterday) {
        return 'Ayer';
      } else {
        return DateFormat('dd/MM/yy').format(date);
      }
    } catch (_) {
      return 'N/A';
    }
  }
}
