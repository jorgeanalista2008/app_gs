class ClienteModel {
  final String id;
  final String name;
  final String codeClientProfit;
  final String taxId;
  final String telefono;
  final String email;
  final String direccion;
  final bool activo;
  final String tipo;
  final bool isProspect;
  final String? serverId;
  final String notes;
  final bool sincronizado;
  
  // Nuevos campos para prospectos
  final String? contactName;
  final String? city;
  final String? zoneCode;
  final String? nextFollowupDate;
  final String? photo1;
  final String? photo2;

  ClienteModel({
    required this.id,
    required this.name,
    this.codeClientProfit = '',
    this.taxId = '',
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.activo = true,
    this.tipo = '',
    this.isProspect = false,
    this.serverId,
    this.notes = '',
    this.sincronizado = true,
    this.contactName,
    this.city,
    this.zoneCode,
    this.nextFollowupDate,
    this.photo1,
    this.photo2,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    final isProspectVal = json['is_prospect'] == 1 ||
        json['is_prospect'] == true ||
        json['status'] != null ||
        json['converted_customer_id'] != null;

    return ClienteModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sin nombre',
      codeClientProfit: json['code_client_profit']?.toString() ?? '',
      taxId: json['tax_id']?.toString() ?? '',
      telefono: json['phone']?.toString() ?? json['telefono']?.toString() ?? '',
      email: json['contact_email']?.toString() ?? json['email']?.toString() ?? '',
      direccion: json['address']?.toString() ?? json['direccion']?.toString() ?? '',
      activo: json['active'] == true ||
          json['active']?.toString() == 'true' ||
          json['activo'] == 1 ||
          json['status'] != 'DELETED',
      tipo: json['type']?.toString() ?? json['tipo']?.toString() ?? '',
      isProspect: isProspectVal,
      serverId: json['server_id']?.toString() ?? json['id']?.toString(),
      notes: json['notes']?.toString() ?? '',
      sincronizado: (json['sincronizado'] ?? 1) == 1,
      contactName: json['contact_name']?.toString(),
      city: json['city']?.toString(),
      zoneCode: json['zone_code']?.toString(),
      nextFollowupDate: json['next_followup_date']?.toString(),
      photo1: json['photo_1']?.toString(),
      photo2: json['photo_2']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code_client_profit': codeClientProfit,
        'tax_id': taxId,
        'phone': telefono,
        'email': email,
        'address': direccion,
        'active': activo,
        'type': tipo,
        'is_prospect': isProspect ? 1 : 0,
        'server_id': serverId,
        'notes': notes,
        'contact_name': contactName,
        'city': city,
        'zone_code': zoneCode,
        'next_followup_date': nextFollowupDate,
        'photo_1': photo1,
        'photo_2': photo2,
      };
}