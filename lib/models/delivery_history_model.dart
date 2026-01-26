// models/delivery_history_model.dart
import 'package:intl/intl.dart';

class DeliveryHistory {
  final String id;
  final String loteId;
  final String paqueteId;
  final String cliente;
  final String producto;
  final int cantidad;
  final String estado;
  final DateTime fechaEntrega;
  final double? latitud;
  final double? longitud;
  final String observaciones;
  final String userId;
  final String? facturas;
  final String? codigoCliente;
  final String? codigoVendedor;

  DeliveryHistory({
    required this.id,
    required this.loteId,
    required this.paqueteId,
    required this.cliente,
    required this.producto,
    required this.cantidad,
    required this.estado,
    required this.fechaEntrega,
    this.latitud,
    this.longitud,
    required this.observaciones,
    required this.userId,
    this.facturas,
    this.codigoCliente,
    this.codigoVendedor, String? vehiculo, required int cantidadPaquetes,
  });

 factory DeliveryHistory.fromJson(Map<String, dynamic> json) {
  // Intentar parsear fecha_entrega, si no existe o es inválido, usar dato_extra1
  DateTime? fechaEntrega;
  
  try {
    if (json['fecha_entrega'] != null && json['fecha_entrega'].toString().isNotEmpty) {
      fechaEntrega = DateTime.parse(json['fecha_entrega'].toString());
    } else if (json['dato_extra1'] != null && json['dato_extra1'].toString().isNotEmpty) {
      fechaEntrega = DateTime.parse(json['dato_extra1'].toString());
    }
  } catch (e) {
    print('⚠️ Error parseando fecha: ${json['fecha_entrega'] ?? json['dato_extra1']}');
    fechaEntrega = DateTime.now(); // Valor por defecto
  }
  
  // Intentar parsear cli_des, si no existe usar valor por defecto
  String cliente = 'Cliente no especificado';
  try {
    if (json['cli_des'] != null) {
      final cliDes = json['cli_des'].toString().trim();
      if (cliDes.isNotEmpty && cliDes != 'Cliente por confirmar') {
        cliente = cliDes;
      }
    }
  } catch (e) {
    print('⚠️ Error parseando cliente: ${json['cli_des']}');
  }
  
  return DeliveryHistory(
    id: json['id']?.toString() ?? '0',
    loteId: json['loteID']?.toString() ?? json['co_lote']?.toString() ?? '',
    paqueteId: json['id']?.toString() ?? '0',
    cliente: cliente,
    producto: 'Paquete ${json['numero_paquete']?.toString() ?? '1'}',
    cantidad: json['cantidad_paquetes'] != null 
        ? int.tryParse(json['cantidad_paquetes'].toString()) ?? 1 
        : 1,
    estado: json['estatus']?.toString() == 'Entregado' || 
            json['estado']?.toString() == 'Entregado' || 
            (!json['estatus'].toString().isEmpty && json['estatus'] != 'Pendiente')
            ? 'Entregado' : 'Pendiente',
    fechaEntrega: fechaEntrega ?? DateTime.now(),
    latitud: null, // No viene en esta estructura
    longitud: null, // No viene en esta estructura
    observaciones: '',
    userId: json['user_id']?.toString() ?? '',
    facturas: null,
    codigoCliente: json['co_cli']?.toString(),
    codigoVendedor: json['co_ven']?.toString(),
    vehiculo: json['vehiculo']?.toString(),
    cantidadPaquetes: json['cantidad_paquetes'] != null 
        ? int.tryParse(json['cantidad_paquetes'].toString()) ?? 1 
        : 1,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lote_id': loteId,
      'paquete_id': paqueteId,
      'cliente': cliente,
      'producto': producto,
      'cantidad': cantidad,
      'estado': estado,
      'fecha_entrega': fechaEntrega.toIso8601String(),
      'lat': latitud,
      'lng': longitud,
      'observaciones': observaciones,
      'user_id': userId,
      'facturas': facturas,
      'co_cli': codigoCliente,
      'co_ven': codigoVendedor,
    };
  }

  String get fechaFormateada {
    return DateFormat('dd/MM/yyyy HH:mm').format(fechaEntrega);
  }

  String get fechaCorta {
    return DateFormat('dd/MM/yy').format(fechaEntrega);
  }

  String get hora {
    return DateFormat('HH:mm').format(fechaEntrega);
  }

  bool get tieneUbicacion {
    return latitud != null && longitud != null;
  }
}