class SurveyAssignment {
  final int id;
  final String customerId;
  final String packId;
  final String? assignedByUserId;
  final DateTime assignedAt;
  final String status; // PENDING | IN_PROGRESS | COMPLETED
  final DateTime? completedAt;
  final String? completedByUserId;
  final String? notes;
  final Map<String, dynamic>? answers;

  SurveyAssignment({
    required this.id,
    required this.customerId,
    required this.packId,
    this.assignedByUserId,
    required this.assignedAt,
    this.status = 'PENDING',
    this.completedAt,
    this.completedByUserId,
    this.notes,
    this.answers,
  });

  bool get isPending => status == 'PENDING';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isOverdue => !isCompleted && DateTime.now().difference(assignedAt).inDays > 7;

  factory SurveyAssignment.fromJson(Map<String, dynamic> json) {
    return SurveyAssignment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      customerId: json['customer_id']?.toString() ?? '',
      packId: json['pack_id']?.toString() ?? '',
      assignedByUserId: json['assigned_by_user_id']?.toString(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'].toString())
          : DateTime.now().toUtc(),
      status: json['status']?.toString() ?? 'PENDING',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'].toString())
          : null,
      completedByUserId: json['completed_by_user_id']?.toString(),
      notes: json['notes']?.toString(),
      answers: json['answers'] is Map ? json['answers'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'pack_id': packId,
    'assigned_by_user_id': assignedByUserId,
    'assigned_at': assignedAt.toUtc().toIso8601String(),
    'status': status,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'completed_by_user_id': completedByUserId,
    'notes': notes,
    'answers': answers,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'pack_id': packId,
    'assigned_by_user_id': assignedByUserId,
    'assigned_at': assignedAt.toUtc().toIso8601String(),
    'status': status,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'completed_by_user_id': completedByUserId,
    'notes': notes,
  };

  factory SurveyAssignment.fromMap(Map<String, dynamic> map) {
    return SurveyAssignment(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      customerId: map['customer_id']?.toString() ?? '',
      packId: map['pack_id']?.toString() ?? '',
      assignedByUserId: map['assigned_by_user_id']?.toString(),
      assignedAt: map['assigned_at'] != null
          ? DateTime.parse(map['assigned_at'].toString())
          : DateTime.now().toUtc(),
      status: map['status']?.toString() ?? 'PENDING',
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'].toString())
          : null,
      completedByUserId: map['completed_by_user_id']?.toString(),
      notes: map['notes']?.toString(),
    );
  }
}
