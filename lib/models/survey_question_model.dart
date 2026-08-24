class SurveyQuestionOption {
  final String id;
  final String label;

  SurveyQuestionOption({required this.id, required this.label});

  factory SurveyQuestionOption.fromJson(Map<String, dynamic> json) {
    return SurveyQuestionOption(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
  };
}

class SurveyQuestion {
  final int id;
  final String code;
  final String description;
  final String questionType; // RATING | BOOLEAN | TEXT | MULTIPLE_CHOICE
  final bool isRequired;
  final List<SurveyQuestionOption>? responseOptions;
  final int sortOrder;

  SurveyQuestion({
    required this.id,
    required this.code,
    required this.description,
    required this.questionType,
    this.isRequired = false,
    this.responseOptions,
    this.sortOrder = 0,
  });

  bool get isRating => questionType == 'RATING';
  bool get isBoolean => questionType == 'BOOLEAN';
  bool get isText => questionType == 'TEXT';
  bool get isMultipleChoice => questionType == 'MULTIPLE_CHOICE';

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'TEXT',
      isRequired: json['is_required'] == true || json['is_required'] == 1,
      responseOptions: json['response_options'] != null
          ? (json['response_options'] as List)
              .map((opt) {
                if (opt is Map) {
                  return SurveyQuestionOption.fromJson(opt as Map<String, dynamic>);
                }
                return SurveyQuestionOption(id: opt.toString(), label: opt.toString());
              })
              .toList()
          : null,
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'question_type': questionType,
    'is_required': isRequired,
    'response_options': responseOptions?.map((o) => o.toJson()).toList(),
    'sort_order': sortOrder,
  };
}
