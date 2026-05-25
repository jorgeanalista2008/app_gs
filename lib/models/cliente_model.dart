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
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sin nombre',
      codeClientProfit: json['code_client_profit']?.toString() ?? '',
      taxId: json['tax_id']?.toString() ?? '',
      telefono: json['phone']?.toString() ?? json['telefono']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      direccion: json['address']?.toString() ?? json['direccion']?.toString() ?? '',
      activo: json['active'] == true ||
          json['active']?.toString() == 'true' ||
          json['activo'] == 1,
      tipo: json['type']?.toString() ?? json['tipo']?.toString() ?? '',
      isProspect: json['is_prospect'] == 1 || json['is_prospect'] == true,
      serverId: json['server_id']?.toString(),
      notes: json['notes']?.toString() ?? '',
      sincronizado: (json['sincronizado'] ?? 1) == 1,
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
      };
}