import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/app_colors.dart';
import '../core/env.dart';

class TasasCambioPage extends StatefulWidget {
  const TasasCambioPage({super.key});

  @override
  State<TasasCambioPage> createState() => _TasasCambioPageState();
}

class _TasasCambioPageState extends State<TasasCambioPage> {
  double? _tasaUsd;
  double? _tasaEur;
  String? _tasaFecha;
  List<Map<String, dynamic>> _historialUsd = [];
  List<Map<String, dynamic>> _historialEur = [];

  bool _isLoading = true;
  String? _error;

  // Calculadora
  final TextEditingController _montoController = TextEditingController(text: '100');
  String _monedaOrigen = 'USD'; // 'USD', 'EUR', 'VES'

  @override
  void initState() {
    super.initState();
    _loadTasas();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _loadTasas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        http.get(Uri.parse('${Env.apiBaseUrl}/currency-s/latest/USD')),
        http.get(Uri.parse('${Env.apiBaseUrl}/currency-s/latest/EUR')),
        http.get(Uri.parse('${Env.apiBaseUrl}/currency-s/by-currency/USD?page=1&limit=7')),
        http.get(Uri.parse('${Env.apiBaseUrl}/currency-s/by-currency/EUR?page=1&limit=7')),
      ]);

      double? usd;
      double? eur;
      String? fecha;
      List<Map<String, dynamic>> histUsd = [];
      List<Map<String, dynamic>> histEur = [];

      // Parse latest USD
      if (results[0].statusCode == 200) {
        final body = jsonDecode(results[0].body);
        final data = body is Map ? body['data'] : null;
        if (data is Map) {
          final rate = data['daily_rate'];
          usd = rate is num ? rate.toDouble() : double.tryParse(rate?.toString() ?? '');
          fecha = data['rate_date']?.toString();
        }
      }

      // Parse latest EUR
      if (results[1].statusCode == 200) {
        final body = jsonDecode(results[1].body);
        final data = body is Map ? body['data'] : null;
        if (data is Map) {
          final rate = data['daily_rate'];
          eur = rate is num ? rate.toDouble() : double.tryParse(rate?.toString() ?? '');
          fecha ??= data['rate_date']?.toString();
        }
      }

      // Parse historial USD
      if (results[2].statusCode == 200) {
        final body = jsonDecode(results[2].body);
        if (body is Map && body['data'] is List) {
          histUsd = List<Map<String, dynamic>>.from(body['data']);
        }
      }

      // Parse historial EUR
      if (results[3].statusCode == 200) {
        final body = jsonDecode(results[3].body);
        if (body is Map && body['data'] is List) {
          histEur = List<Map<String, dynamic>>.from(body['data']);
        }
      }

      if (mounted) {
        setState(() {
          _tasaUsd = usd;
          _tasaEur = eur;
          _tasaFecha = fecha;
          _historialUsd = histUsd;
          _historialEur = histEur;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron obtener las tasas actualizadas: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final str = value.toString();
    try {
      final dt = DateTime.parse(str);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  void _copiarAlPortapapeles(String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Tasas Oficiales BCV',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar tasas',
            onPressed: _loadTasas,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: _loadTasas,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              )
            : _error != null && _tasaUsd == null && _tasaEur == null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          _error ?? 'Error de conexión',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadTasas,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // ─── Tarjetas Principales USD y EUR ───
        Row(
          children: [
            Expanded(
              child: _buildCurrencyCard(
                titulo: 'Dólar Oficial',
                codigo: 'USD',
                simbolo: '\$',
                rate: _tasaUsd,
                color: AppColors.primaryColor,
                icon: Icons.attach_money_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCurrencyCard(
                titulo: 'Euro Oficial',
                codigo: 'EUR',
                simbolo: '€',
                rate: _tasaEur,
                color: AppColors.secondaryColor,
                icon: Icons.euro_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Calculadora / Conversor de Divisas ───
        _buildCalculadoraCard(),

        const SizedBox(height: 16),

        // ─── Historial Reciente de Tasas ───
        if (_historialUsd.isNotEmpty || _historialEur.isNotEmpty)
          _buildHistorialCard(),

        const SizedBox(height: 16),

        // ─── Nota Informativa BCV ───
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blueGrey[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tasas de cambio publicadas por el Banco Central de Venezuela (BCV). Las operaciones de venta y cobranza de Solsumed se rigen por la tasa oficial del día.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[800], height: 1.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCurrencyCard({
    required String titulo,
    required String codigo,
    required String simbolo,
    required double? rate,
    required Color color,
    required IconData icon,
  }) {
    final rateStr = rate != null ? rate.toStringAsFixed(4) : '—';
    final rateDisplay = rate != null ? rate.toStringAsFixed(2) : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rateDisplay,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Bs / $simbolo',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tasaFecha != null ? 'Fecha: ${_formatDate(_tasaFecha)}' : 'BCV',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              if (rate != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _copiarAlPortapapeles(
                    rateStr,
                    'Tasa $codigo ($rateStr Bs) copiada',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalculadoraCard() {
    final montoInput = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0;
    final usdRate = _tasaUsd ?? 0;
    final eurRate = _tasaEur ?? 0;

    double resultadoUsd = 0;
    double resultadoEur = 0;
    double resultadoVes = 0;

    if (_monedaOrigen == 'USD') {
      resultadoUsd = montoInput;
      resultadoVes = montoInput * usdRate;
      resultadoEur = eurRate > 0 ? resultadoVes / eurRate : 0;
    } else if (_monedaOrigen == 'EUR') {
      resultadoEur = montoInput;
      resultadoVes = montoInput * eurRate;
      resultadoUsd = usdRate > 0 ? resultadoVes / usdRate : 0;
    } else {
      // VES (Bolívares)
      resultadoVes = montoInput;
      resultadoUsd = usdRate > 0 ? montoInput / usdRate : 0;
      resultadoEur = eurRate > 0 ? montoInput / eurRate : 0;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_rounded, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Calculadora de Conversión',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Input y Selector de moneda
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _montoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto a convertir',
                      labelStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: Icon(
                        _monedaOrigen == 'USD'
                            ? Icons.attach_money
                            : _monedaOrigen == 'EUR'
                                ? Icons.euro
                                : Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _monedaOrigen,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                          DropdownMenuItem(value: 'VES', child: Text('Bs. (VES)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _monedaOrigen = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Resultados de conversión
            Row(
              children: [
                if (_monedaOrigen != 'USD')
                  Expanded(
                    child: _buildConversionResultTile(
                      titulo: 'En Dólares',
                      monto: '\$${resultadoUsd.toStringAsFixed(2)}',
                      subtitulo: usdRate > 0 ? 'Tasa: ${usdRate.toStringAsFixed(2)}' : '',
                      color: AppColors.primaryColor,
                    ),
                  ),
                if (_monedaOrigen != 'USD' && _monedaOrigen != 'EUR')
                  const SizedBox(width: 8),
                if (_monedaOrigen != 'EUR')
                  Expanded(
                    child: _buildConversionResultTile(
                      titulo: 'En Euros',
                      monto: '€${resultadoEur.toStringAsFixed(2)}',
                      subtitulo: eurRate > 0 ? 'Tasa: ${eurRate.toStringAsFixed(2)}' : '',
                      color: AppColors.secondaryColor,
                    ),
                  ),
                if (_monedaOrigen != 'VES') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildConversionResultTile(
                      titulo: 'En Bolívares',
                      monto: 'Bs. ${resultadoVes.toStringAsFixed(2)}',
                      subtitulo: 'Total oficial',
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionResultTile({
    required String titulo,
    required String monto,
    required String subtitulo,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              monto,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (subtitulo.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorialCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Historial Reciente (Últimos días)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_historialUsd.isNotEmpty) ...[
              const Text(
                'Dólar Oficial (USD)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
              ),
              const SizedBox(height: 6),
              ..._historialUsd.take(5).map((item) {
                final rate = item['daily_rate'];
                final rateVal = rate is num ? rate.toDouble() : double.tryParse(rate?.toString() ?? '') ?? 0;
                final fecha = item['rate_date'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(fecha), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        'Bs. ${rateVal.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (_historialEur.isNotEmpty) ...[
              const Divider(height: 16),
              const Text(
                'Euro Oficial (EUR)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
              ),
              const SizedBox(height: 6),
              ..._historialEur.take(5).map((item) {
                final rate = item['daily_rate'];
                final rateVal = rate is num ? rate.toDouble() : double.tryParse(rate?.toString() ?? '') ?? 0;
                final fecha = item['rate_date'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(fecha), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        'Bs. ${rateVal.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
