class ConciergeMatchPayload {
  const ConciergeMatchPayload({
    required this.goal,
    required this.preferredDays,
    required this.preferredTime,
    required this.trainingLocationId,
    required this.trainingLocationName,
    required this.preferredArea,
    required this.budgetMin,
    required this.budgetMax,
    required this.femaleTrainerOnly,
    required this.languagePreference,
    required this.message,
  });

  final String goal;
  final List<String> preferredDays;
  final String preferredTime;

  final String trainingLocationId;
  final String trainingLocationName;
  final String preferredArea;

  final int? budgetMin;
  final int? budgetMax;

  final bool femaleTrainerOnly;
  final String? languagePreference;
  final String? message;

  String? get trainerGenderPreference {
    return femaleTrainerOnly ? 'female' : null;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'request_type': 'concierge_match',
      'goal': goal.trim(),
      'preferred_days': preferredDays.map((day) => day.trim().toLowerCase()).toList(),

      'preferred_time': preferredTime.trim().toLowerCase(),
      'training_location_id': trainingLocationId,
      'preferred_area': preferredArea.trim(),
    };

    if (trainerGenderPreference != null) {
      json['trainer_gender_preference'] = trainerGenderPreference;
    }

    if (budgetMin != null) {
      json['budget_min'] = budgetMin;
    }

    if (budgetMax != null) {
      json['budget_max'] = budgetMax;
    }

    if (languagePreference != null && languagePreference!.trim().isNotEmpty) {
      json['language_preference'] = languagePreference!.trim();
    }

    if (message != null && message!.trim().isNotEmpty) {
      json['message'] = message!.trim();
    }

    return json;
  }

  ConciergeMatchPayload copyWith({
    String? goal,
    List<String>? preferredDays,
    String? preferredTime,
    String? trainingLocationId,
    String? trainingLocationName,
    String? preferredArea,
    int? budgetMin,
    int? budgetMax,
    bool? femaleTrainerOnly,
    String? languagePreference,
    String? message,
  }) {
    return ConciergeMatchPayload(
      goal: goal ?? this.goal,
      preferredDays: preferredDays ?? this.preferredDays,
      preferredTime: preferredTime ?? this.preferredTime,
      trainingLocationId: trainingLocationId ?? this.trainingLocationId,
      trainingLocationName: trainingLocationName ?? this.trainingLocationName,
      preferredArea: preferredArea ?? this.preferredArea,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      femaleTrainerOnly: femaleTrainerOnly ?? this.femaleTrainerOnly,
      languagePreference: languagePreference ?? this.languagePreference,
      message: message ?? this.message,
    );
  }
}
