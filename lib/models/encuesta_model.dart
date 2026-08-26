import 'pregunta_model.dart';

class EncuestaModel {
  final String id;
  final String salespersonId;
  final String customerId;
  final String status;
  final List<PreguntaModel> questions;
  final List<dynamic> answers;
  final String? packName;

  EncuestaModel({
    required this.id,
    required this.salespersonId,
    required this.customerId,
    this.status = 'PENDING',
    required this.questions,
    this.answers = const [],
    this.packName,
  });

  factory EncuestaModel.fromJson(Map<String, dynamic> json) {
    return EncuestaModel(
      id: json['id']?.toString() ?? '',
      salespersonId: json['salesperson_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      questions: json['questions'] != null
          ? (json['questions'] as List).map((q) => PreguntaModel.fromJson(q)).toList()
          : [],
      answers: json['answers'] ?? [],
      packName: json['pack_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'salesperson_id': salespersonId,
    'customer_id': customerId,
    'status': status,
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers,
    'pack_name': packName,
  };
}