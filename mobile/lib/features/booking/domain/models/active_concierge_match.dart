class ActiveConciergeMatch {
  const ActiveConciergeMatch({
    required this.id,
    required this.referenceCode,
    required this.status,
    this.goal,
    this.trainerId,
    this.createdAt,
  });

  final String id;
  final String referenceCode;
  final String status;
  final String? goal;
  final String? trainerId;
  final DateTime? createdAt;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isMatched => normalizedStatus == 'matched';

  bool get isInProgress => !isMatched;

  factory ActiveConciergeMatch.fromJson(Map<String, dynamic> json) {
    return ActiveConciergeMatch(
      id: json['id']?.toString().trim() ?? '',
      referenceCode:
          json['reference_code']?.toString().trim().isNotEmpty == true
          ? json['reference_code'].toString().trim()
          : 'Request',
      status: json['status']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim(),
      trainerId: json['trainer_id']?.toString().trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
