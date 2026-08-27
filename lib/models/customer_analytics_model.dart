class CustomerAnalyticsModel {
  // Dashboard
  final double? saldosPorVencer;
  final double? saldosVencidos;
  final int? docsPorVencer;
  final int? docsVencidos;
  final double? totalSaldo;
  final int? totalDocs;

  // Stats
  final int? numFacturas;
  final int? facturasAnioActual;
  final String? primeraCompra;
  final String? ultimaCompra;
  final double? totalNetoVes;
  final double? totalNetoUsd;
  final double? ticketPromedio;
  final int? diasSinComprar;

  // RFM
  final int? recencyDias;
  final double? frequency;
  final double? monetaryVes;
  final double? monetaryUsd;
  final int? rfmScore;

  // LTV
  final double? ltvProyectado12m;
  final double? ltvProyectado24m;
  final double? margenEstimado;
  final double? margenPct;

  // Churn
  final int? churnScore;
  final String? churnRisk;

  CustomerAnalyticsModel({
    this.saldosPorVencer,
    this.saldosVencidos,
    this.docsPorVencer,
    this.docsVencidos,
    this.totalSaldo,
    this.totalDocs,
    this.numFacturas,
    this.facturasAnioActual,
    this.primeraCompra,
    this.ultimaCompra,
    this.totalNetoVes,
    this.totalNetoUsd,
    this.ticketPromedio,
    this.diasSinComprar,
    this.recencyDias,
    this.frequency,
    this.monetaryVes,
    this.monetaryUsd,
    this.rfmScore,
    this.ltvProyectado12m,
    this.ltvProyectado24m,
    this.margenEstimado,
    this.margenPct,
    this.churnScore,
    this.churnRisk,
  });

  factory CustomerAnalyticsModel.fromDashboardJson(Map<String, dynamic> json) {
    return CustomerAnalyticsModel(
      saldosPorVencer: (json['saldos_por_vencer'] as num?)?.toDouble(),
      saldosVencidos: (json['saldos_vencidos'] as num?)?.toDouble(),
      docsPorVencer: json['docs_por_vencer'] as int?,
      docsVencidos: json['docs_vencidos'] as int?,
      totalSaldo: (json['total_saldo'] as num?)?.toDouble(),
      totalDocs: json['total_docs'] as int?,
    );
  }

  factory CustomerAnalyticsModel.fromStatsJson(Map<String, dynamic> json) {
    return CustomerAnalyticsModel(
      numFacturas: json['num_facturas'] as int?,
      facturasAnioActual: json['facturas_anio_actual'] as int?,
      primeraCompra: json['primera_compra']?.toString(),
      ultimaCompra: json['ultima_compra']?.toString(),
      totalNetoVes: (json['total_neto_ves'] as num?)?.toDouble(),
      totalNetoUsd: (json['total_neto_usd'] as num?)?.toDouble(),
      ticketPromedio: (json['ticket_promedio_ves'] as num?)?.toDouble(),
      diasSinComprar: json['dias_sin_comprar'] as int?,
    );
  }

  factory CustomerAnalyticsModel.fromRfmJson(Map<String, dynamic> json) {
    final recency = json['recency'] is Map<String, dynamic> ? json['recency'] as Map<String, dynamic> : null;
    final frequency = json['frequency'] is Map<String, dynamic> ? json['frequency'] as Map<String, dynamic> : null;
    final monetary = json['monetary'] is Map<String, dynamic> ? json['monetary'] as Map<String, dynamic> : null;

    return CustomerAnalyticsModel(
      recencyDias: (recency?['dias'] ?? json['recency_dias']) as int?,
      frequency: ((frequency?['facturas_por_mes'] ?? json['frequency_facturas_mes']) as num?)?.toDouble(),
      monetaryVes: ((monetary?['total_ves'] ?? json['monetary_total_ves']) as num?)?.toDouble(),
      monetaryUsd: ((monetary?['total_usd'] ?? json['monetary_total_usd']) as num?)?.toDouble(),
      rfmScore: json['rfm_score'] as int?,
    );
  }

  factory CustomerAnalyticsModel.fromLtvJson(Map<String, dynamic> json) {
    final churnData = json['churn'] as Map<String, dynamic>?;
    return CustomerAnalyticsModel(
      ltvProyectado12m: (json['ltv_proyectado_12m'] as num?)?.toDouble(),
      ltvProyectado24m: (json['ltv_proyectado_24m'] as num?)?.toDouble(),
      margenEstimado: (json['margen_bruto_estimado_ves'] as num?)?.toDouble(),
      margenPct: (json['margen_pct'] as num?)?.toDouble(),
      churnScore: churnData?['churn_score'] as int?,
      churnRisk: churnData?['churn_risk']?.toString(),
    );
  }
}
