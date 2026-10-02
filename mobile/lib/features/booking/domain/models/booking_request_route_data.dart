import 'package:mobile/features/trainers/domain/models/trainer.dart';

class BookingRequestRouteData {
  const BookingRequestRouteData({
    required this.trainer,
    this.sourceConciergeRequestId,
  });

  final Trainer trainer;
  final String? sourceConciergeRequestId;
}