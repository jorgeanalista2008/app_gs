// models/lot_model.dart
class LotModel {
  final String id;
  final String loteId;
  final String cliente;
  final String direccion;
  final String telefono;
  final String producto;
  final int cantidad;
  final String estado;
  final String? fechaEntrega;
  final double? latitud;
  final double? longitud;
  final String observaciones;
  
  // Campos adicionales de la API
  final String? codigoCliente;
  final String? codigoVendedor;
  final String? qrData;
  final List<String> facturas;
  final String? numeroPaquete; // Nuevo campo

  LotModel({
    required this.id,
    required this.loteId,
    required this.cliente,
    required this.direccion,
    required this.telefono,
    required this.producto,
    required this.cantidad,
    required this.estado,
    this.fechaEntrega,
    this.latitud,
    this.longitud,
    required this.observaciones,
    this.codigoCliente,
    this.codigoVendedor,
    this.qrData,
    this.facturas = const [],
    this.numeroPaquete,
  });

  // Método copyWith actualizado
  LotModel copyWith({
    String? id,
    String? loteId,
    String? cliente,
    String? direccion,
    String? telefono,
    String? producto,
    int? cantidad,
    String? estado,
    String? fechaEntrega,
    double? latitud,
    double? longitud,
    String? observaciones,
    String? codigoCliente,
    String? codigoVendedor,
    String? qrData,
    List<String>? facturas,
    String? numeroPaquete,
  }) {
    return LotModel(
      id: id ?? this.id,
      loteId: loteId ?? this.loteId,
      cliente: cliente ?? this.cliente,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      estado: estado ?? this.estado,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      observaciones: observaciones ?? this.observaciones,
      codigoCliente: codigoCliente ?? this.codigoCliente,
      codigoVendedor: codigoVendedor ?? this.codigoVendedor,
      qrData: qrData ?? this.qrData,
      facturas: facturas ?? this.facturas,
      numeroPaquete: numeroPaquete ?? this.numeroPaquete,
    );
  }

  // Método para mostrar información resumida
  String get resumen {
    return 'Lote: $loteId - Paquete: $numeroPaquete - Cliente: ${cliente.substring(0, min(20, cliente.length))}...';
  }

  int min(int a, int b) => a < b ? a : b;
}