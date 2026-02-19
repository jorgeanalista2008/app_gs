// models/delivery_history_model.dart - VERSIÓN CORREGIDA
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
  
  // ✅ PROPIEDADES FALTANTES AGREGADAS
  final String? vehiculo;
  final int cantidadPaquetes;

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
    this.codigoVendedor,
    // ✅ PARÁMETROS CORREGIDOS
    this.vehiculo,
    this.cantidadPaquetes = 1,
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
    
    // Determinar estado
    String estado = 'Pendiente';
    final estatusRaw = json['estatus']?.toString() ?? '';
    final estadoRaw = json['estado']?.toString() ?? '';
    
    if (estatusRaw.toLowerCase() == 'entregado' || 
        estadoRaw.toLowerCase() == 'entregado' ||
        (estatusRaw.isNotEmpty && estatusRaw != 'Pendiente' && estatusRaw != '1')) {
      estado = 'Entregado';
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
      estado: estado,
      fechaEntrega: fechaEntrega ?? DateTime.now(),
      latitud: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
      longitud: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
      observaciones: json['observaciones']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      facturas: json['facturas']?.toString() ?? json['facturas_texto']?.toString(),
      codigoCliente: json['co_cli']?.toString(),
      codigoVendedor: json['co_ven']?.toString(),
      // ✅ CAMPOS AGREGADOS
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
      // ✅ CAMPOS AGREGADOS AL JSON
      'vehiculo': vehiculo,
      'cantidad_paquetes': cantidadPaquetes,
    };
  }

  // ✅ MÉTODO COPYWITH AGREGADO
  DeliveryHistory copyWith({
    String? id,
    String? loteId,
    String? paqueteId,
    String? cliente,
    String? producto,
    int? cantidad,
    String? estado,
    DateTime? fechaEntrega,
    double? latitud,
    double? longitud,
    String? observaciones,
    String? userId,
    String? facturas,
    String? codigoCliente,
    String? codigoVendedor,
    String? vehiculo,
    int? cantidadPaquetes,
  }) {
    return DeliveryHistory(
      id: id ?? this.id,
      loteId: loteId ?? this.loteId,
      paqueteId: paqueteId ?? this.paqueteId,
      cliente: cliente ?? this.cliente,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      estado: estado ?? this.estado,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      observaciones: observaciones ?? this.observaciones,
      userId: userId ?? this.userId,
      facturas: facturas ?? this.facturas,
      codigoCliente: codigoCliente ?? this.codigoCliente,
      codigoVendedor: codigoVendedor ?? this.codigoVendedor,
      vehiculo: vehiculo ?? this.vehiculo,
      cantidadPaquetes: cantidadPaquetes ?? this.cantidadPaquetes,
    );
  }

  // Getters de formato
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
  
  // ✅ GETTER ADICIONAL: Verificar si tiene vehículo asignado
  bool get tieneVehiculo {
    return vehiculo != null && vehiculo!.isNotEmpty;
  }
  
  // ✅ EQUALITY OVERRIDE
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryHistory &&
        other.id == id &&
        other.loteId == loteId &&
        other.paqueteId == paqueteId;
  }

  @override
  int get hashCode => id.hashCode ^ loteId.hashCode ^ paqueteId.hashCode;
  
  // ✅ TOSTRING PARA DEBUG
  @override
  String toString() {
    return 'DeliveryHistory(id: $id, loteId: $loteId, cliente: $cliente, estado: $estado)';
  }
}