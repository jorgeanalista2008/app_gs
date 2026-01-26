class ShipmentModel {
  final String id;
  final String embarco;      // Asumiendo que tu tabla tiene un campo con el nombre del envío.
  final String cliente;     // Asumiendo que tienes una tabla de Clientes relacionada.
  final String fecha;
  final String estado;

  ShipmentModel({
    required this.id,
    required this.embarco,
    required this.cliente,
    required this.fecha,
    required this.estado,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['id'].toString(),
      embarco: json['embarco'] ?? 'Desconocido',
      cliente: json['cliente'] ?? 'Sin Cliente',
      fecha: json['fecha'] ?? 'Sin Fecha',
      estado: json['estado'] ?? 'Pendiente',
    );
  }
  
 
}