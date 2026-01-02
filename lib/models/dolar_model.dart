class DolarModel {
  final String fuente;   // 'paralelo', 'oficial', etc.
  final String nombre;    // 'Paralelo', 'Oficial'
  final double promedio;  // El precio real

  DolarModel({
    required this.fuente,
    required this.nombre,
    required this.promedio,
  });

  factory DolarModel.fromJson(Map<String, dynamic> json) {
    return DolarModel(
      fuente: json['fuente'] ?? '',
      nombre: json['nombre'] ?? '',
      promedio: (json['promedio'] ?? 0).toDouble(),
    );
  }
}