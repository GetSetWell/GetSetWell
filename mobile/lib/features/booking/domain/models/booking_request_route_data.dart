import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';

class BookingRequestRouteData {
  const BookingRequestRouteData({
    required this.trainer,
    this.sourceConciergeRequestId,
    this.initialGoal,
    this.initialTrainingPlace,
    this.initialVenueChoice,
    this.initialLocationLabel,
    this.initialNotes,
    this.isRepeatBooking = false,
  });

  final Trainer trainer;

  final String? sourceConciergeRequestId;

  /// Used when we already know the customer's goal,
  /// for example when repeating a previous session.
  final String? initialGoal;

  /// Previous training-place choice.
  final CustomerTrainingPlace? initialTrainingPlace;

  /// Previous venue choice, if applicable.
  final BookingVenueChoice? initialVenueChoice;

  /// Previous area / gym / location label.
  final String? initialLocationLabel;

  /// Previous optional booking notes.
  final String? initialNotes;

  /// True when entering the booking flow from "Book again".
  ///
  /// Date and time must still be selected again from
  /// the trainer's current availability.
  final bool isRepeatBooking;

  /// Reads sessions.customer_training_place ('gym' | 'home' | 'outdoors').
  static CustomerTrainingPlace? trainingPlaceFromDb(Object? value) {
    return switch (value?.toString().trim()) {
      'gym' => CustomerTrainingPlace.gym,
      'home' => CustomerTrainingPlace.home,
      'outdoors' => CustomerTrainingPlace.outdoors,
      _ => null,
    };
  }

  /// Reads sessions.venue_choice ('customer_choice' | 'trainer_private_gym').
  static BookingVenueChoice? venueChoiceFromDb(Object? value) {
    return switch (value?.toString().trim()) {
      'customer_choice' => BookingVenueChoice.customerChoice,
      'trainer_private_gym' => BookingVenueChoice.trainerPrivateGym,
      _ => null,
    };
  }
}
