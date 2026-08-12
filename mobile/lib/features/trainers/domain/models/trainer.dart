class Trainer {
  const Trainer({
    required this.id,
    required this.fullName,
    required this.slug,
    required this.gender,
    required this.credentials,
    required this.yearsExperience,
    required this.pricePerSession,
    required this.profileImageUrl,
    required this.serviceArea,
    required this.languages,
    required this.availabilityNote,
    required this.isVerified,
    required this.primaryService,
  });

  final String id;
  final String fullName;
  final String slug;
  final String? gender;
  final String? credentials;
  final int? yearsExperience;
  final double? pricePerSession;
  final String? profileImageUrl;

  final String? serviceArea;
  final List<String> languages;

  final String? availabilityNote;
  final bool isVerified;

  final String? primaryService;

  factory Trainer.fromJson(Map<String, dynamic> json) {
    final trainerServices = (json['trainer_services'] as List<dynamic>?) ?? [];

    String? primaryService;

    for (final item in trainerServices) {
      final serviceData = item as Map<String, dynamic>;

      if (serviceData['is_primary'] == true) {
        final service = serviceData['services'] as Map<String, dynamic>?;

        primaryService = service?['name'] as String?;

        break;
      }
    }

    return Trainer(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      slug: json['slug'] as String,
      gender: json['gender'] as String?,
      credentials: json['credentials'] as String?,
      yearsExperience: json['years_experience'] as int?,
      pricePerSession: (json['price_per_session'] as num?)?.toDouble(),
      profileImageUrl: json['profile_image_url'] as String?,
      serviceArea: json['service_area'] as String?,
      languages: List<String>.from(json['languages'] ?? const []),
      availabilityNote: json['availability_note'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      primaryService: primaryService,
    );
  }
}
