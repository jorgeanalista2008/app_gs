import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../atoms/offline_banner.dart';

class ConnectionWrapper extends StatefulWidget {
  final Widget child;

  const ConnectionWrapper({super.key, required this.child});

  @override
  State<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends State<ConnectionWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isConnected = true;
  bool _showOfflineBanner = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _subscription = _connectivityService.onConnectivityChanged.listen(_onConnectionChanged);
  }

  Future<void> _checkInitialConnection() async {
    final conectado = await _connectivityService.isConnected();
    if (mounted) {
      setState(() {
        _isConnected = conectado;
        _showOfflineBanner = !conectado;
      });
    }
  }

  void _onConnectionChanged(ConnectivityResult result) {
    final conectado = result == ConnectivityResult.mobile ||
                      result == ConnectivityResult.wifi ||
                      result == ConnectivityResult.ethernet;

    if (mounted) {
      setState(() {
        _isConnected = conectado;
        _showOfflineBanner = !conectado;
      });

      if (conectado) {
        // Recuperó conexión
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('🌐 Conexión recuperada'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Perdió conexión
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('📴 Se perdió la conexión a internet'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _irModoOffline() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📴 Modo offline activado. Trabajando con datos locales.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner offline
        if (_showOfflineBanner)
          OfflineBanner(onGoOffline: _irModoOffline),

        // Contenido principal
        Expanded(child: widget.child),
      ],
    );
  }
}