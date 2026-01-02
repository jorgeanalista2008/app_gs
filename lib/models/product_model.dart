class ProductModel {
  final String name;
  final String formattedValue; // "6.249,00"
  final String provider;
  final int units; // Agregado para la gráfica

  ProductModel({
    required this.name,
    required this.formattedValue,
    required this.provider,
    required this.units,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      name: json['dato1'],
      formattedValue: json['dato2'],
      provider: json['dato3'],
      units: json['dato4'] ?? 0,

    );
  }

  // Helper para convertir "6.249,00" a 6249.00 para sumar
  double get value {
    String raw = formattedValue.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }
}

// Modelo para los totales
class ProductTotals {
  final double totalValue;
  final int totalProducts;
  final String topProduct;

  ProductTotals({
    required this.totalValue,
    required this.totalProducts,
    required this.topProduct,
  });
}