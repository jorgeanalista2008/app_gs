class VisitaModel {
  final String id;
  final String customerId;
  final String customerName;
  final String address;
  final String city;
  final String codeClientProfit;
  final String taxId;
  final String visitDateFrom;
  final String visitDateTo;
  final String notes;
  final int priority;
  final String status;
  final String? completedAt;

  VisitaModel({
    required this.id,
    required this.customerId,
    this.customerName = '',
    this.address = '',
    this.city = '',
    this.codeClientProfit = '',
    this.taxId = '',
    required this.visitDateFrom,
    required this.visitDateTo,
    this.notes = '',
    this.priority = 1,
    this.status = 'PENDING',
    this.completedAt,
  });

  factory VisitaModel.fromJson(Map<String, dynamic> json) {
    return VisitaModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      codeClientProfit: json['code_client_profit']?.toString() ?? '',
      taxId: json['tax_id']?.toString() ?? '',
      visitDateFrom: json['visit_date_from']?.toString() ?? '',
      visitDateTo: json['visit_date_to']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      priority: json['priority'] is int 
          ? json['priority'] 
          : int.tryParse(json['priority']?.toString() ?? '1') ?? 1,
      status: json['status']?.toString() ?? 'PENDING',
      completedAt: json['completed_at']?.toString(),
    );
  }

  bool get isPendiente => status == 'PENDING';
  bool get isCompletada => status == 'COMPLETED';

  String get prioridadTexto {
    switch (priority) {
      case 1: return 'Muy Urgente';
      case 2: return 'Urgente';
      case 3: return 'Normal';
      case 4: return 'Baja';
      case 5: return 'Muy Baja';
      default: return 'Normal';
    }
  }

  String get fechaRango {
    try {
      final desde = DateTime.parse(visitDateFrom);
      final hasta = DateTime.parse(visitDateTo);
      return '${desde.day}/${desde.month} - ${hasta.day}/${hasta.month}/${hasta.year}';
    } catch (e) {
      return '$visitDateFrom - $visitDateTo';
    }
  }

  String get diaNumero {
    try {
      final date = DateTime.parse(visitDateFrom);
      return date.day.toString();
    } catch (e) {
      return '?';
    }
  }

  String get mesAbreviado {
    try {
      final date = DateTime.parse(visitDateFrom);
      const meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
      return meses[date.month - 1];
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'address': address,
    'city': city,
    'code_client_profit': codeClientProfit,
    'tax_id': taxId,
    'visit_date_from': visitDateFrom,
    'visit_date_to': visitDateTo,
    'notes': notes,
    'priority': priority,
    'status': status,
    'completed_at': completedAt,
  };
}