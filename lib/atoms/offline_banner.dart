import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final VoidCallback? onGoOffline;

  const OfflineBanner({super.key, this.onGoOffline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sin conexión a internet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (onGoOffline != null)
            TextButton(
              onPressed: onGoOffline,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text(
                'Modo offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}