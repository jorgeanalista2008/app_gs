import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../repositories/asistencia_repository.dart';

class AsistenciaPage extends StatefulWidget {
  const AsistenciaPage({super.key});

  @override
  State<AsistenciaPage> createState() => _AsistenciaPageState();
}

class _AsistenciaPageState extends State<AsistenciaPage> {
  final AsistenciaRepository _repo = AsistenciaRepository.instance;

  AsistenciaDia _hoy = const AsistenciaDia();
  List<Map<String, dynamic>> _historial = [];
  bool _isLoading = true;
  bool _isMarcando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final hoy = await _repo.getHoy();
    final historial = await _repo.getHistorial();
    if (!mounted) return;
    setState(() {
      _hoy = hoy;
      _historial = historial;
      _isLoading = false;
    });
  }

  Future<void> _marcar(TipoAsistencia tipo) async {
    setState(() => _isMarcando = true);
    final error = await _repo.marcar(tipo);
    if (!mounted) return;
    setState(() => _isMarcando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '✅ ${tipo.label} registrada'),
        backgroundColor: error != null ? AppColors.errorColor : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (error == null) await _cargar();
  }

  String _hora(dynamic isoString) {
    if (isoString == null) return '--:--';
    final parsed = DateTime.tryParse(isoString.toString());
    if (parsed == null) return '--:--';
    return DateFormat('hh:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Mi Jornada'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildEstadoHoy(),
                  const SizedBox(height: 24),
                  _buildBotonMarcar(),
                  const SizedBox(height: 28),
                  Text(
                    'Últimos 30 días',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_historial.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Sin marcas registradas todavía',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  else
                    ..._historial.map(_buildHistorialItem),
                ],
              ),
            ),
    );
  }

  Widget _buildEstadoHoy() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, AppColors.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now()),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _marcaTile(
                  'Entrada',
                  _hora(_hoy.entrada?['recorded_at']),
                  Icons.login,
                  _hoy.tieneEntrada,
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white24),
              Expanded(
                child: _marcaTile(
                  'Salida',
                  _hora(_hoy.salida?['recorded_at']),
                  Icons.logout,
                  _hoy.tieneSalida,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marcaTile(String label, String hora, IconData icon, bool marcado) {
    return Column(
      children: [
        Icon(icon, color: marcado ? Colors.white : Colors.white38, size: 20),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(
          hora,
          style: TextStyle(
            color: marcado ? Colors.white : Colors.white38,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBotonMarcar() {
    final siguiente = _hoy.siguiente;

    if (siguiente == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Jornada completa. Buen trabajo.',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final esEntrada = siguiente == TipoAsistencia.entrada;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isMarcando ? null : () => _marcar(siguiente),
        icon: _isMarcando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(esEntrada ? Icons.login : Icons.logout),
        label: Text(
          _isMarcando
              ? 'Registrando...'
              : esEntrada
                  ? 'Marcar entrada'
                  : 'Marcar salida',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              esEntrada ? AppColors.primaryColor : AppColors.secondaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialItem(Map<String, dynamic> marca) {
    final esEntrada = marca['tipo'] == 'ENTRADA';
    final fecha = DateTime.tryParse(marca['recorded_at']?.toString() ?? '');
    final pendiente = marca['sincronizado'] == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: (esEntrada ? AppColors.primaryColor : AppColors.secondaryColor)
              .withValues(alpha: 0.12),
          child: Icon(
            esEntrada ? Icons.login : Icons.logout,
            size: 17,
            color: esEntrada ? AppColors.primaryColor : AppColors.secondaryColor,
          ),
        ),
        title: Text(
          esEntrada ? 'Entrada' : 'Salida',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          fecha != null
              ? DateFormat('dd/MM/yyyy · hh:mm a').format(fecha.toLocal())
              : '',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: pendiente
            ? Icon(Icons.cloud_upload_outlined,
                size: 18, color: Colors.orange[600])
            : Icon(Icons.cloud_done_outlined,
                size: 18, color: Colors.green[600]),
      ),
    );
  }
}
