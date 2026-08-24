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
