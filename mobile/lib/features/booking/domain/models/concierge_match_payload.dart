class ConciergeMatchPayload {
  const ConciergeMatchPayload({
    required this.customerName,
    required this.phone,
    required this.goal,
    required this.preferredDays,
    required this.preferredTime,
    required this.trainingLocationId,
    required this.preferredArea,
    required this.shareDetailsConsent,
    this.trainerGenderPreference,
    this.budgetMin,
    this.budgetMax,
    this.languagePreference,
    this.message,
  });

  final String customerName;
  final String phone;
  final String goal;

  final List<String> preferredDays;
  final String preferredTime;
  final String trainingLocationId;
  final String preferredArea;

  final String? trainerGenderPreference;
  final int? budgetMin;
  final int? budgetMax;
  final String? languagePreference;

  final String? message;
  final bool shareDetailsConsent;

  Map<String, dynamic> toJson() {
    return {
      'request_type': 'concierge_match',

      'customer_name': customerName.trim(),
      'phone': phone.trim(),
      'goal': goal.trim(),

      'preferred_days': preferredDays,
      'preferred_time': preferredTime,
      'training_location_id': trainingLocationId,
      'preferred_area': preferredArea.trim(),

      if (trainerGenderPreference != null) 'trainer_gender_preference': trainerGenderPreference,

      if (budgetMin != null) 'budget_min': budgetMin,
      if (budgetMax != null) 'budget_max': budgetMax,

      if (languagePreference != null && languagePreference!.trim().isNotEmpty)
        'language_preference': languagePreference!.trim(),

      if (message != null && message!.trim().isNotEmpty) 'message': message!.trim(),

      'share_details_consent': shareDetailsConsent,
    };
  }
}
