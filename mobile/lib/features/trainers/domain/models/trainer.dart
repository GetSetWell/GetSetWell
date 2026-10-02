import 'trainer_fit_point.dart';
import 'trainer_specialty.dart';
import 'trainer_verification_check.dart';

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
    required this.verificationChecks,
    required this.specialties,
    required this.fitPoints,
    required this.sessionDurationMinutes,
    required this.sessionFormat,
    required this.sessionLocations,
    required this.sessionScheduleNote,
    required this.paymentNote,
    required this.bio,
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
  final List<TrainerVerificationCheck> verificationChecks;
  final List<TrainerSpecialty> specialties;
  final List<TrainerFitPoint> fitPoints;
  final int? sessionDurationMinutes;
  final String? sessionFormat;
  final String? sessionLocations;
  final String? sessionScheduleNote;
  final String? paymentNote;
  final String? bio;

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

    final verificationData =
        (json['trainer_verification_checks'] as List<dynamic>?) ?? [];

    final verificationChecks =
        verificationData
            .map(
              (item) => TrainerVerificationCheck.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final trainerSpecialties =
        (json['trainer_specialties'] as List<dynamic>?) ?? [];

    final specialties = trainerSpecialties
        .map((item) {
          final specialtyData = Map<String, dynamic>.from(item as Map);

          final specialty =
              specialtyData['specialties'] as Map<String, dynamic>?;

          if (specialty == null) {
            return null;
          }

          return TrainerSpecialty.fromJson(
            Map<String, dynamic>.from(specialty),
          );
        })
        .whereType<TrainerSpecialty>()
        .toList();

    final fitPointData = (json['trainer_fit_points'] as List<dynamic>?) ?? [];

    final fitPoints =
        fitPointData
            .map(
              (item) => TrainerFitPoint.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

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
      verificationChecks: verificationChecks,
      specialties: specialties,
      fitPoints: fitPoints,

      sessionDurationMinutes: json['session_duration_minutes'] as int?,
      sessionFormat: json['session_format'] as String?,
      sessionLocations: json['session_locations'] as String?,
      sessionScheduleNote: json['session_schedule_note'] as String?,
      paymentNote: json['payment_note'] as String?,
      bio: json['bio'] as String?,
    );
  }
}
