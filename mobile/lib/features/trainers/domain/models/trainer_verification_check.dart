class TrainerVerificationCheck {
  const TrainerVerificationCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.checkType,
    required this.displayOrder,
    required this.isVerified,
  });

  final String id;
  final String title;
  final String description;
  final String checkType;
  final int displayOrder;
  final bool isVerified;

  factory TrainerVerificationCheck.fromJson(Map<String, dynamic> json) {
    return TrainerVerificationCheck(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      checkType: json['check_type'] as String,
      displayOrder: json['display_order'] as int? ?? 999,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}
