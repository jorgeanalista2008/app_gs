class PreguntaModel {
  final String id;
  final String code;
  final String description;
  final String questionType; // RATING, TEXT, MULTIPLE_CHOICE, etc.
  final bool isRequired;
  final List<String>? responseOptions;
  final int sortOrder;
  final int orderIndex;

  PreguntaModel({
    required this.id,
    required this.code,
    required this.description,
    required this.questionType,
    this.isRequired = false,
    this.responseOptions,
    this.sortOrder = 0,
    this.orderIndex = 0,
  });

  factory PreguntaModel.fromJson(Map<String, dynamic> json) {
    return PreguntaModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'TEXT',
      isRequired: json['is_required'] == true || json['is_required']?.toString() == 'true',
      responseOptions: json['response_options'] != null
          ? List<String>.from(json['response_options'])
          : null,
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
      orderIndex: json['order_index'] is int
          ? json['order_index']
          : int.tryParse(json['order_index']?.toString() ?? '0') ?? 0,
    );
  }

  bool get isRating => questionType == 'RATING';
  bool get isText => questionType == 'TEXT';
  bool get isMultipleChoice => questionType == 'MULTIPLE_CHOICE';

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'question_type': questionType,
    'is_required': isRequired,
    'response_options': responseOptions,
    'sort_order': sortOrder,
    'order_index': orderIndex,
  };
}