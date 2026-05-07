class ArticuloModel {
  final String id;
  final String codigo;
  final String descripcion;
  final double precio;
  final int stock;
  final String unidad;
  final String categoria;
  final bool activo;

  ArticuloModel({
    required this.id,
    required this.codigo,
    required this.descripcion,
    this.precio = 0.0,
    this.stock = 0,
    this.unidad = 'UND',
    this.categoria = '',
    this.activo = true,
  });

  factory ArticuloModel.fromJson(Map<String, dynamic> json) {
    return ArticuloModel(
      id: json['id']?.toString() ?? json['co_art']?.toString() ?? '',
      codigo: json['co_art']?.toString() ?? json['codigo']?.toString() ?? '',
      descripcion: json['art_des']?.toString() ?? json['descripcion']?.toString() ?? 'Sin descripción',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      unidad: json['unidad']?.toString() ?? 'UND',
      categoria: json['categoria']?.toString() ?? '',
      activo: json['activo']?.toString() == '1' || json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'co_art': codigo,
    'art_des': descripcion,
    'precio': precio,
    'stock': stock,
    'unidad': unidad,
    'categoria': categoria,
    'activo': activo ? '1' : '0',
  };
}