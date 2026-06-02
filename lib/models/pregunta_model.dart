import 'dart:convert';

class PreguntaOption {
  final String id;
  final String label;

  PreguntaOption({required this.id, required this.label});

  factory PreguntaOption.fromJson(Map<String, dynamic> json) {
    return PreguntaOption(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
  };

  static List<PreguntaOption> parseOptions(dynamic rawOptions) {
    if (rawOptions == null) return [];
    
    // Si es un String, intentamos decodificarlo como JSON; si falla, lo tratamos como CSV
    if (rawOptions is String) {
      if (rawOptions.trim().isEmpty) return [];
      try {
        final decoded = jsonDecode(rawOptions);
        return parseOptions(decoded);
      } catch (_) {
        return rawOptions
            .split(',')
            .map((opt) => opt.trim())
            .where((opt) => opt.isNotEmpty)
            .map((opt) => PreguntaOption(id: opt, label: opt))
            .toList();
      }
    }
    
    // Si es una Lista
    if (rawOptions is List) {
      return rawOptions.map((item) {
        if (item is Map) {
          final mapItem = Map<String, dynamic>.from(item);
          return PreguntaOption.fromJson(mapItem);
        } else if (item is String) {
          return PreguntaOption(id: item, label: item);
        } else {
          return PreguntaOption(id: item.toString(), label: item.toString());
        }
      }).toList();
    }
    
    // Fallback
    return [PreguntaOption(id: rawOptions.toString(), label: rawOptions.toString())];
  }
}

class PreguntaModel {
  final String id;
  final String code;
  final String description;
  final String questionType; // RATING, TEXT, MULTIPLE_CHOICE, etc.
  final bool isRequired;
  final List<PreguntaOption>? responseOptions;
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
          ? PreguntaOption.parseOptions(json['response_options'])
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
    'response_options': responseOptions?.map((o) => o.toJson()).toList(),
    'sort_order': sortOrder,
    'order_index': orderIndex,
  };
}