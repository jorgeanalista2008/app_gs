import 'survey_pack_model.dart';

class Customer360Contact {
  final String? phone;
  final String? email;
  final String? address;

  Customer360Contact({
    this.phone,
    this.email,
    this.address,
  });

  factory Customer360Contact.fromJson(Map<String, dynamic> json) {
    return Customer360Contact(
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'email': email,
    'address': address,
  };
}

class Customer360VisitsStats {
  final int totalVisits;
  final DateTime? lastVisitDate;

  Customer360VisitsStats({
    this.totalVisits = 0,
    this.lastVisitDate,
  });

  factory Customer360VisitsStats.fromJson(Map<String, dynamic> json) {
    return Customer360VisitsStats(
      totalVisits: json['total_visits'] is int
          ? json['total_visits']
          : int.tryParse(json['total_visits']?.toString() ?? '0') ?? 0,
      lastVisitDate: json['last_visit_date'] != null
          ? DateTime.parse(json['last_visit_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_visits': totalVisits,
    'last_visit_date': lastVisitDate?.toUtc().toIso8601String(),
  };
}

class Customer360ProfitSummary {
  final double totalPurchasesUsd;
  final List<dynamic> recentPurchases;
  final List<dynamic> topProducts;
  final double last30DaysVolume;
  final double currentYearUsd;
  final double previousYearUsd;
  final int totalInvoices;
  final DateTime? lastPurchaseDate;
  final int? daysSinceLastPurchase;
  final int? avgDaysBetweenPurchases;
  final double creditLimitUsd;
  final double pendingBalanceUsd;
  final double availableCreditUsd;
  final bool isOverCredit;

  Customer360ProfitSummary({
    this.totalPurchasesUsd = 0,
    this.recentPurchases = const [],
    this.topProducts = const [],
    this.last30DaysVolume = 0,
    this.currentYearUsd = 0,
    this.previousYearUsd = 0,
    this.totalInvoices = 0,
    this.lastPurchaseDate,
    this.daysSinceLastPurchase,
    this.avgDaysBetweenPurchases,
    this.creditLimitUsd = 0,
    this.pendingBalanceUsd = 0,
    this.availableCreditUsd = 0,
    this.isOverCredit = false,
  });

  factory Customer360ProfitSummary.fromJson(Map<String, dynamic> json) {
    final deuda = json['deuda'] as Map<String, dynamic>?;
    return Customer360ProfitSummary(
      totalPurchasesUsd: _parseDouble(json['total_purchases_usd']),
      recentPurchases: json['recent_purchases'] ?? [],
      topProducts: json['top_products'] ?? [],
      last30DaysVolume: _parseDouble(json['last_30_days_volume']),
      currentYearUsd: _parseDouble(json['anio_actual_usd']),
      previousYearUsd: _parseDouble(json['anio_anterior_usd']),
      totalInvoices: json['total_facturas'] is int
          ? json['total_facturas']
          : int.tryParse(json['total_facturas']?.toString() ?? '0') ?? 0,
      lastPurchaseDate: json['ultima_compra'] != null
          ? DateTime.tryParse(json['ultima_compra'].toString())
          : null,
      daysSinceLastPurchase: json['dias_desde_ultima_compra'] is int
          ? json['dias_desde_ultima_compra']
          : int.tryParse(json['dias_desde_ultima_compra']?.toString() ?? ''),
      avgDaysBetweenPurchases: json['promedio_dias_entre_compras'] is int
          ? json['promedio_dias_entre_compras']
          : int.tryParse(json['promedio_dias_entre_compras']?.toString() ?? ''),
      creditLimitUsd: _parseDouble(deuda?['credito_usd']),
      pendingBalanceUsd: _parseDouble(deuda?['saldo_pendiente_usd']),
      availableCreditUsd: _parseDouble(deuda?['disponible_usd']),
      isOverCredit: deuda?['sobregirado'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_purchases_usd': totalPurchasesUsd,
    'recent_purchases': recentPurchases,
    'top_products': topProducts,
    'last_30_days_volume': last30DaysVolume,
    'anio_actual_usd': currentYearUsd,
    'anio_anterior_usd': previousYearUsd,
    'total_facturas': totalInvoices,
    'ultima_compra': lastPurchaseDate?.toUtc().toIso8601String(),
    'dias_desde_ultima_compra': daysSinceLastPurchase,
    'promedio_dias_entre_compras': avgDaysBetweenPurchases,
    'deuda': {
      'credito_usd': creditLimitUsd,
      'saldo_pendiente_usd': pendingBalanceUsd,
      'disponible_usd': availableCreditUsd,
      'sobregirado': isOverCredit,
    },
  };

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class Customer360 {
  final Map<String, dynamic> customer;
  final Customer360Contact? contact;
  final Customer360VisitsStats? visitsStats;
  final List<dynamic> pendingSchedules;
  final Customer360ProfitSummary? profitSummary;
  final SurveyPack? recommendedSurvey;
  final DateTime timestamp;

  Customer360({
    required this.customer,
    this.contact,
    this.visitsStats,
    this.pendingSchedules = const [],
    this.profitSummary,
    this.recommendedSurvey,
    required this.timestamp,
  });

  factory Customer360.fromJson(Map<String, dynamic> json) {
    return Customer360(
      customer: json['customer'] ?? {},
      contact: json['contact'] != null
          ? Customer360Contact.fromJson(json['contact'] as Map<String, dynamic>)
          : null,
      visitsStats: json['visits_stats'] != null
          ? Customer360VisitsStats.fromJson(json['visits_stats'] as Map<String, dynamic>)
          : null,
      pendingSchedules: json['pending_schedules'] ?? [],
      profitSummary: json['profit_summary'] != null
          ? Customer360ProfitSummary.fromJson(json['profit_summary'] as Map<String, dynamic>)
          : null,
      recommendedSurvey: json['recommended_survey'] != null
          ? SurveyPack.fromJson(json['recommended_survey'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': customer,
    'contact': contact?.toJson(),
    'visits_stats': visitsStats?.toJson(),
    'pending_schedules': pendingSchedules,
    'profit_summary': profitSummary?.toJson(),
    'recommended_survey': recommendedSurvey?.toJson(),
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}
