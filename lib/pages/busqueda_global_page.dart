import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/database_helper.dart';
import 'detalle_visita_page.dart';
import '../models/visita_model.dart';

/// Buscador unificado offline: busca en clientes, prospectos y visitas locales.
/// Todo el filtrado ocurre sobre SQLite (sin red), debounce de 300ms para
/// evitar re-queries en cada tecla.
class BusquedaGlobalPage extends StatefulWidget {
  const BusquedaGlobalPage({super.key});

  @override
  State<BusquedaGlobalPage> createState() => _BusquedaGlobalPageState();
}

class _BusquedaGlobalPageState extends State<BusquedaGlobalPage> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _prospectos = [];
  List<Map<String, dynamic>> _visitas = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _buscar(value));
  }

  Future<void> _buscar(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _clientes = [];
        _prospectos = [];
        _visitas = [];
      });
      return;
    }
    setState(() => _loading = true);
    final db = await _db.database;
    final like = '%$q%';

    final clientesRows = await db.rawQuery(
      '''SELECT id, name, tax_id, telefono, direccion, code_client_profit
         FROM clientes
         WHERE is_prospect = 0 AND (
           lower(name) LIKE ? OR lower(tax_id) LIKE ? OR lower(telefono) LIKE ?
           OR lower(code_client_profit) LIKE ? OR lower(direccion) LIKE ?
         )
         ORDER BY name ASC LIMIT 30''',
      [like, like, like, like, like],
    );

    final prospectosRows = await db.rawQuery(
      '''SELECT id, name, tax_id, telefono, direccion
         FROM clientes
         WHERE is_prospect = 1 AND (
           lower(name) LIKE ? OR lower(tax_id) LIKE ? OR lower(telefono) LIKE ?
           OR lower(direccion) LIKE ?
         )
         ORDER BY updated_at DESC LIMIT 30''',
      [like, like, like, like],
    );

    final visitasRows = await db.rawQuery(
      '''SELECT id, customer_id, customer_name, visit_date_from, notes, status, priority
         FROM visitas
         WHERE lower(customer_name) LIKE ? OR lower(notes) LIKE ?
         ORDER BY visit_date_from DESC LIMIT 30''',
      [like, like],
    );

    if (!mounted) return;
    setState(() {
      _clientes = clientesRows;
      _prospectos = prospectosRows;
      _visitas = visitasRows;
      _loading = false;
    });
  }

  int get _total => _clientes.length + _prospectos.length + _visitas.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Búsqueda'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            color: AppColors.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar cliente, RIF, prospecto, visita...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryColor),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          _buscar('');
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Contador resultados
          if (_ctrl.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                _loading ? 'Buscando...' : '$_total resultado${_total == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

          // Resultados
          Expanded(
            child: _ctrl.text.isEmpty
                ? _emptyState()
                : (_total == 0 && !_loading
                    ? _noResults()
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        children: [
                          if (_clientes.isNotEmpty) ...[
                            _sectionHeader(
                              Icons.people_alt_rounded,
                              'Clientes',
                              _clientes.length,
                              AppColors.primaryColor,
                            ),
                            ..._clientes.map((c) => _clienteCard(c, isProspecto: false)),
                            const SizedBox(height: 10),
                          ],
                          if (_prospectos.isNotEmpty) ...[
                            _sectionHeader(
                              Icons.person_add_alt_1_rounded,
                              'Prospectos',
                              _prospectos.length,
                              AppColors.secondaryColor,
                            ),
                            ..._prospectos.map((p) => _clienteCard(p, isProspecto: true)),
                            const SizedBox(height: 10),
                          ],
                          if (_visitas.isNotEmpty) ...[
                            _sectionHeader(
                              Icons.pin_drop_rounded,
                              'Visitas',
                              _visitas.length,
                              AppColors.warningColor,
                            ),
                            ..._visitas.map(_visitaCard),
                            const SizedBox(height: 20),
                          ],
                        ],
                      )),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Escribe para buscar',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clientes • Prospectos • Visitas',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _noResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Sin resultados para "${_ctrl.text}"',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clienteCard(Map<String, dynamic> c, {required bool isProspecto}) {
    final color = isProspecto ? AppColors.secondaryColor : AppColors.primaryColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            (c['name']?.toString() ?? '?').isNotEmpty
                ? c['name'].toString()[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          c['name']?.toString() ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((c['tax_id']?.toString() ?? '').isNotEmpty)
              Text('RIF: ${c['tax_id']}', style: const TextStyle(fontSize: 11)),
            if ((c['telefono']?.toString() ?? '').isNotEmpty)
              Text('📞 ${c['telefono']}', style: const TextStyle(fontSize: 11)),
            if ((c['direccion']?.toString() ?? '').isNotEmpty)
              Text(
                c['direccion'].toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        onTap: () => Navigator.pop(context, {
          'type': isProspecto ? 'prospecto' : 'cliente',
          'id': c['id'],
        }),
      ),
    );
  }

  Widget _visitaCard(Map<String, dynamic> v) {
    final status = (v['status']?.toString() ?? 'PENDING').toUpperCase();
    final isPending = status == 'PENDING';
    final statusColor = isPending
        ? AppColors.warningColor
        : (status == 'COMPLETED' ? AppColors.successColor : AppColors.errorColor);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.pin_drop_rounded, color: statusColor, size: 20),
        ),
        title: Text(
          v['customer_name']?.toString() ?? 'Cliente',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v['visit_date_from'] ?? '-'} · $status',
              style: TextStyle(fontSize: 11, color: statusColor),
            ),
            if ((v['notes']?.toString() ?? '').isNotEmpty)
              Text(
                v['notes'].toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        onTap: () {
          final visita = VisitaModel(
            id: v['id']?.toString() ?? '',
            customerId: v['customer_id']?.toString() ?? '',
            customerName: v['customer_name']?.toString() ?? '',
            visitDateFrom: v['visit_date_from']?.toString() ?? '',
            visitDateTo: v['visit_date_from']?.toString() ?? '',
            priority: (v['priority'] as int?) ?? 0,
            status: status,
            notes: v['notes']?.toString() ?? '',
            sincronizado: true,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleVisitaPage(visita: visita),
            ),
          );
        },
      ),
    );
  }
}
