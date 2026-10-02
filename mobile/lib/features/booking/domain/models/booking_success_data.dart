sealed class BookingSuccessData {
  const BookingSuccessData({
    required this.requestId,
    required this.referenceCode,
  });

  final String requestId;
  final String referenceCode;
}

class ConciergeMatchSuccessData extends BookingSuccessData {
  const ConciergeMatchSuccessData({
    required super.requestId,
    required super.referenceCode,
    required this.goal,
    required this.days,
    required this.time,
    required this.trainingLocation,
    required this.preferredArea,
    this.trainerPreference,
    this.budget,
    this.language,
  });

  final String goal;
  final String days;
  final String time;
  final String trainingLocation;
  final String preferredArea;

  final String? trainerPreference;
  final String? budget;
  final String? language;
}

class TrainerRequestSuccessData extends BookingSuccessData {
  const TrainerRequestSuccessData({
    required super.requestId,
    required super.referenceCode,
    required this.trainerName,
    required this.rate,
    required this.goal,
    required this.days,
    required this.time,
    required this.trainingLocation,
    required this.preferredArea,
  });

  final String trainerName;
  final String rate;

  final String goal;
  final String days;
  final String time;
  final String trainingLocation;
  final String preferredArea;
}
