class TrainerRequestPayload {
  const TrainerRequestPayload({
    required this.trainerId,
    required this.customerName,
    required this.phone,
    required this.goal,
    required this.preferredDays,
    required this.preferredTime,
    required this.trainingLocationId,
    required this.preferredArea,
    required this.shareDetailsConsent,
    this.message,
  });

  final String trainerId;

  final String customerName;
  final String phone;
  final String goal;

  final List<String> preferredDays;
  final String preferredTime;

  final String trainingLocationId;
  final String preferredArea;

  final String? message;

  final bool shareDetailsConsent;

  Map<String, dynamic> toJson() {
    return {
      'request_type': 'trainer_request',

      'trainer_id': trainerId,

      'customer_name': customerName.trim(),
      'phone': phone.trim(),
      'goal': goal.trim(),

      'preferred_days': preferredDays,
      'preferred_time': preferredTime,

      'training_location_id': trainingLocationId,
      'preferred_area': preferredArea.trim(),

      if (message != null && message!.trim().isNotEmpty)
        'message': message!.trim(),

      'share_details_consent': shareDetailsConsent,
    };
  }
}