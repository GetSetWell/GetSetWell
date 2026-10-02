import 'package:mobile/features/trainers/domain/models/trainer.dart';

enum BookingPaymentMethod {
  card,
  applePay,
}

enum CustomerTrainingPlace {
  gym,
  home,
  outdoors,
}

enum BookingVenueChoice {
  customerChoice,
  trainerPrivateGym,
}

class BookingCheckoutData {
  const BookingCheckoutData({
    required this.trainer,
    required this.customerTrainingPlace,
    required this.venueChoice,
    required this.locationLabel,
    required this.sessionRate,
    required this.serviceFee,
    required this.total,
    required this.scheduledAt,
    required this.paymentMethod,
    this.goal,
    this.notes,
    this.sourceConciergeRequestId,
  });

  final Trainer trainer;

  final CustomerTrainingPlace customerTrainingPlace;
  final BookingVenueChoice venueChoice;

  final String locationLabel;

  final double sessionRate;
  final double serviceFee;
  final double total;

  final DateTime scheduledAt;

  final BookingPaymentMethod paymentMethod;

  final String? goal;
  final String? notes;
      final String? sourceConciergeRequestId;

}