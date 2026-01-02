class BillingModel {
  final double sales; // dato1
  final double returns; // dato2
  final String name; // dato3
  final double collections; // dato4

  BillingModel({
    required this.sales,
    required this.returns,
    required this.name,
    required this.collections,
  });

  factory BillingModel.fromJson(Map<String, dynamic> json) {
    return BillingModel(
      sales: (json['dato1'] ?? 0).toDouble(),
      returns: (json['dato2'] ?? 0).toDouble(),
      name: json['dato3'] ?? 'Desconocido',
      collections: (json['dato4'] ?? 0).toDouble(),
    );
  }
}

// Modelo simple para los totales
class BillingTotals {
  final double totalSales;
  final double totalReturns;
  final double totalCollections;

  BillingTotals({
    required this.totalSales,
    required this.totalReturns,
    required this.totalCollections,
  });
}