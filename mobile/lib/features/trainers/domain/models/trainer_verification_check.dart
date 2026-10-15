class TrainerVerificationCheck {
  const TrainerVerificationCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.checkType,
    required this.displayOrder,
    required this.isVerified,
    this.verifiedAt,
  });

  final String id;
  final String title;
  final String description;
  final String checkType;
  final int displayOrder;
  final bool isVerified;

  /// Calendar date the check was completed (a date column, no time zone).
  final DateTime? verifiedAt;

  factory TrainerVerificationCheck.fromJson(Map<String, dynamic> json) {
    final rawVerifiedAt = json['verified_at']?.toString();

    return TrainerVerificationCheck(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      checkType: json['check_type']?.toString() ?? 'other',
      displayOrder: json['display_order'] as int? ?? 999,
      isVerified: json['is_verified'] as bool? ?? false,
      verifiedAt: rawVerifiedAt == null ? null : DateTime.tryParse(rawVerifiedAt),
    );
  }
}
