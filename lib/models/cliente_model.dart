class ClienteModel {
  final String id;
  final String name;
  final String codeClientProfit;
  final String taxId;
  // Campos adicionales para el detalle
  final String telefono;
  final String email;
  final String direccion;
  final String tipo;
  final bool activo;

  ClienteModel({
    required this.id,
    required this.name,
    this.codeClientProfit = '',
    this.taxId = '',
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.tipo = '',
    this.activo = true,
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
      tipo: json['type']?.toString() ?? json['tipo']?.toString() ?? '',
      activo: json['active']?.toString() == 'true' || json['active'] == true || json['activo'] == true,
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
    'type': tipo,
    'active': activo,
  };

  @override
  String toString() => 'ClienteModel(id: $id, name: $name, rif: $taxId)';
}