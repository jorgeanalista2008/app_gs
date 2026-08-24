import 'survey_question_model.dart';

class SurveyPack {
  final String id;
  final String name;
  final String packType; // NEW_CUSTOMER | EXISTING_CUSTOMER | CUSTOM
  final String? description;
  final List<SurveyQuestion> questions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt; // soft delete

  SurveyPack({
    required this.id,
    required this.name,
    required this.packType,
    this.description,
    required this.questions,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isNewCustomerPack => packType == 'NEW_CUSTOMER';
  bool get isExistingCustomerPack => packType == 'EXISTING_CUSTOMER';
  bool get isCustomPack => packType == 'CUSTOM';
  bool get isDeleted => deletedAt != null;

  factory SurveyPack.fromJson(Map<String, dynamic> json) {
    return SurveyPack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      packType: json['pack_type']?.toString() ?? 'CUSTOM',
      description: json['description']?.toString(),
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>))
              .toList()
          : [],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pack_type': packType,
    'description': description,
    'questions': questions.map((q) => q.toJson()).toList(),
    'is_active': isActive,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pack_type': packType,
    'description': description,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory SurveyPack.fromMap(Map<String, dynamic> map) {
    return SurveyPack(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      packType: map['pack_type']?.toString() ?? 'CUSTOM',
      description: map['description']?.toString(),
      questions: [], // Se cargan por separado desde survey_pack_questions
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'].toString()) : null,
    );
  }
}
