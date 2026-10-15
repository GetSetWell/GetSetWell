import 'package:mobile/core/utils/gsw_format.dart';
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

/// Everything the payment step needs to charge and confirm one session.
///
/// Times: [scheduledAt] and [availableStarts] are Dubai wall-clock values
/// produced by [GSWTime] (UTC-flagged DateTimes whose fields read as Dubai
/// time). Use [scheduledAtUtcIso] when talking to the backend.
///
/// Money: amounts are in dirhams, already rounded to whole fils with
/// [GSWMoney]. After a successful booking the payment screen replaces them
/// with the server-calculated amounts.
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
    this.availableStarts = const [],
    this.isRepeatBooking = false,
  });

  final Trainer trainer;

  final CustomerTrainingPlace customerTrainingPlace;
  final BookingVenueChoice venueChoice;

  final String locationLabel;

  final double sessionRate;
  final double serviceFee;
  final double total;

  /// Session start, Dubai wall-clock time.
  final DateTime scheduledAt;

  final BookingPaymentMethod paymentMethod;

  final String? goal;
  final String? notes;
  final String? sourceConciergeRequestId;

  /// The trainer's open start times (Dubai wall-clock) when the person
  /// continued to payment. Used to offer alternatives if the slot goes.
  final List<DateTime> availableStarts;

  /// Booked from "Book again": the confirmation shows 11.4 Booked again.
  final bool isRepeatBooking;

  /// The session start as an ISO 8601 UTC instant, for the edge function.
  String get scheduledAtUtcIso => GSWTime.dubaiToUtc(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
        scheduledAt.hour,
        scheduledAt.minute,
      ).toIso8601String();

  BookingCheckoutData copyWith({
    DateTime? scheduledAt,
    double? sessionRate,
    double? serviceFee,
    double? total,
    String? locationLabel,
    List<DateTime>? availableStarts,
  }) {
    return BookingCheckoutData(
      trainer: trainer,
      customerTrainingPlace: customerTrainingPlace,
      venueChoice: venueChoice,
      locationLabel: locationLabel ?? this.locationLabel,
      sessionRate: sessionRate ?? this.sessionRate,
      serviceFee: serviceFee ?? this.serviceFee,
      total: total ?? this.total,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      paymentMethod: paymentMethod,
      goal: goal,
      notes: notes,
      sourceConciergeRequestId: sourceConciergeRequestId,
      availableStarts: availableStarts ?? this.availableStarts,
      isRepeatBooking: isRepeatBooking,
    );
  }
}

/// What the payment screen hands back to the booking flow when it pops.
enum BookingPaymentOutcome {
  /// The server price differs from what was shown. Reload and review again.
  priceChanged,

  /// The chosen time is gone. Go back to the time step.
  pickAnotherTime,

  /// The person wants to change how they pay.
  changePaymentMethod,
}

/// Shared booking copy so the review step and confirmation agree.
class BookingCopy {
  BookingCopy._();

  /// "His gym, Dubai Marina", "Your home, JLT", "Outdoors, Kite Beach".
  static String whereLabel({
    required BookingVenueChoice venueChoice,
    required CustomerTrainingPlace customerTrainingPlace,
    required String locationLabel,
    required Object? trainerGender,
  }) {
    final place = switch (venueChoice) {
      BookingVenueChoice.trainerPrivateGym =>
        '${GSWPronoun.capitalise(GSWPronoun.possessive(trainerGender))} gym',
      BookingVenueChoice.customerChoice => switch (customerTrainingPlace) {
          CustomerTrainingPlace.gym => 'Your gym',
          CustomerTrainingPlace.home => 'Your home',
          CustomerTrainingPlace.outdoors => 'Outdoors',
        },
    };

    final location = locationLabel.trim();

    return location.isEmpty ? place : '$place, $location';
  }

  /// First name, or "your trainer" when the name is missing.
  static String firstName(String fullName) {
    final name = fullName.trim();

    if (name.isEmpty) return 'your trainer';

    return name.split(RegExp(r'\s+')).first;
  }
}
