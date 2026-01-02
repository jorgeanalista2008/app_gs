class DashboardModel {
  final double totalSales;
  final int totalOrders;
  final int newClients;
  final List<ChartDataPoint> chartData;
  final List<TransactionModel> transactions;

  DashboardModel({
    required this.totalSales,
    required this.totalOrders,
    required this.newClients,
    required this.chartData,
    required this.transactions,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalSales: (json['total_sales'] ?? 0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      newClients: json['new_clients'] ?? 0,
      chartData: (json['chart_data'] as List)
          .map((e) => ChartDataPoint.fromJson(e))
          .toList(),
      transactions: (json['transactions'] as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList(),
    );
  }
}

class ChartDataPoint {
  final int mes; // 1 = Ene, 2 = Feb...
  final double valor;

  ChartDataPoint({required this.mes, required this.valor});
  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(mes: json['mes'], valor: json['valor']);
  }
}

class TransactionModel {
  final String id;
  final String client;
  final String amount;
  final String status;

  TransactionModel({required this.id, required this.client, required this.amount, required this.status});
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'].toString(),
      client: json['cliente'],
      amount: json['monto'],
      status: json['estado'],
    );
  }
}