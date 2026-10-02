import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_area.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    super.key,
    required this.trainer,
    this.initialGoal,
    this.sourceConciergeRequestId,
  });

  final Trainer trainer;
  final String? initialGoal;
  final String? sourceConciergeRequestId;

  @override
  State<BookingRequestScreen> createState() =>
      _BookingRequestScreenState();
}

// =============================================================================
// PUBLIC CHECKOUT DATA
// =============================================================================

// =============================================================================
// STATE
// =============================================================================

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  final TextEditingController _preferredAreaController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;

  int _currentStep = 1;

  CustomerTrainingPlace? _customerTrainingPlace;

  BookingVenueChoice _venueChoice = BookingVenueChoice.customerChoice;

  DateTime? _selectedDate;
  String? _selectedTime;

  BookingPaymentMethod _paymentMethod = BookingPaymentMethod.card;

  double? _gymPrice;
  String? _gymLocationLabel;

  static const List<String> _timeSlots = ['6:00 AM', '7:00 AM', '6:30 PM'];

  Trainer get trainer => widget.trainer;

  // =============================================================================
  // BASIC TRAINER DATA
  // =============================================================================

  String get _trainerFirstName {
    final name = trainer.fullName.trim();

    if (name.isEmpty) {
      return 'trainer';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  String get _trainerService {
    final value = trainer.primaryService?.trim();

    if (value == null || value.isEmpty) {
      return 'training';
    }

    return value;
  }

  double get _standardPrice {
    return trainer.pricePerSession?.toDouble() ?? 0;
  }

  bool get _hasPrivateGym {
    return _gymPrice != null &&
        _gymPrice! > 0 &&
        _gymLocationLabel != null &&
        _gymLocationLabel!.trim().isNotEmpty;
  }

  // =============================================================================
  // DYNAMIC FLOW
  // =============================================================================

  int get _totalSteps {
    return _hasPrivateGym ? 4 : 3;
  }

  bool get _isVenueChoiceStep {
    return _hasPrivateGym && _currentStep == 2;
  }

  bool get _isTimeStep {
    if (_hasPrivateGym) {
      return _currentStep == 3;
    }

    return _currentStep == 2;
  }

  bool get _isReviewStep {
    return _currentStep == _totalSteps;
  }

  // =============================================================================
  // LOCATION
  // =============================================================================

  String get _customerLocationLabel {
    return _preferredAreaController.text.trim();
  }

  String get _finalLocationLabel {
    if (_venueChoice == BookingVenueChoice.trainerPrivateGym && _hasPrivateGym) {
      return _gymLocationLabel!;
    }

    return _customerLocationLabel;
  }

  String get _customerTrainingPlaceLabel {
    switch (_customerTrainingPlace) {
      case CustomerTrainingPlace.gym:
        return 'Gym';

      case CustomerTrainingPlace.home:
        return 'Home';

      case CustomerTrainingPlace.outdoors:
        return 'Outdoors';

      case null:
        return '';
    }
  }

  String get _customerVenueDescription {
    switch (_customerTrainingPlace) {
      case CustomerTrainingPlace.gym:
        return 'your preferred gym';

      case CustomerTrainingPlace.home:
        return 'your place';

      case CustomerTrainingPlace.outdoors:
        return 'outdoors';

      case null:
        return '';
    }
  }

  // =============================================================================
  // PRICE
  // =============================================================================

  double get _activeSessionRate {
    if (_venueChoice == BookingVenueChoice.trainerPrivateGym && _hasPrivateGym) {
      return _gymPrice!;
    }

    return _standardPrice;
  }

  double get _serviceFee {
    return _activeSessionRate * 0.05;
  }

  double get _total {
    return _activeSessionRate + _serviceFee;
  }

  // =============================================================================
  // DATE
  // =============================================================================

  List<DateTime> get _availableDates {
    final now = DateTime.now();

    return List.generate(7, (index) => DateTime(now.year, now.month, now.day + index));
  }

  // =============================================================================
  // VALIDATION
  // =============================================================================

  bool get _stepComplete {
    // STEP 1:
    // customer must pick location type AND enter preferred area.
    if (_currentStep == 1) {
      return _customerTrainingPlace != null && _preferredAreaController.text.trim().isNotEmpty;
    }

    // Optional private-gym comparison.
    if (_isVenueChoiceStep) {
      return true;
    }

    // Time.
    if (_isTimeStep) {
      return _selectedDate != null && _selectedTime != null;
    }

    // Review.
    if (_isReviewStep) {
      return true;
    }

    return false;
  }

  // =============================================================================
  // LIFECYCLE
  // =============================================================================

  @override
  void initState() {
    super.initState();

    _loadTrainerBookingData();
  }

  @override
  void dispose() {
    _preferredAreaController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  // =============================================================================
  // BACKEND
  // =============================================================================

  Future<void> _loadTrainerBookingData() async {
    try {
      final trainerRow = await _client
          .from('trainers')
          .select('''
            gym_price_per_session,
            gym_location_label
            ''')
          .eq('id', trainer.id)
          .maybeSingle();

      final rawGymPrice = trainerRow?['gym_price_per_session'];

      final gymPrice = rawGymPrice is num
          ? rawGymPrice.toDouble()
          : double.tryParse(rawGymPrice?.toString() ?? '');

      final gymLocation = trainerRow?['gym_location_label']?.toString().trim();

      if (!mounted) return;

      setState(() {
        if (gymPrice != null && gymPrice > 0 && gymLocation != null && gymLocation.isNotEmpty) {
          _gymPrice = gymPrice;
          _gymLocationLabel = gymLocation;
        } else {
          _gymPrice = null;
          _gymLocationLabel = null;
        }

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Booking trainer data load failed: $error');

      if (!mounted) return;

      setState(() {
        // Gym data is optional.
        // Failure here must not block booking.
        _gymPrice = null;
        _gymLocationLabel = null;

        _isLoading = false;
      });
    }
  }

  // =============================================================================
  // NAVIGATION
  // =============================================================================

  void _goNext() {
    if (!_stepComplete) {
      return;
    }

    if (_currentStep >= _totalSteps) {
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _goBack() {
    if (_currentStep <= 1) {
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  void _closeFlow() {
    if (context.canPop()) {
      context.pop();
    }
  }

  // =============================================================================
  // USER CHOICES
  // =============================================================================

  void _selectCustomerTrainingPlace(CustomerTrainingPlace place) {
    setState(() {
      _customerTrainingPlace = place;

      // If the user changes their original
      // training preference, default the later
      // venue decision back to that choice.
      _venueChoice = BookingVenueChoice.customerChoice;
    });
  }

  void _selectVenueChoice(BookingVenueChoice choice) {
    setState(() {
      _venueChoice = choice;
    });
  }

  DateTime _combineDateAndTime(DateTime date, String timeLabel) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s+(AM|PM)$',
    ).firstMatch(timeLabel.trim().toUpperCase());

    if (match == null) {
      throw FormatException('Invalid booking time: $timeLabel');
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }
  // =============================================================================
  // PAYMENT
  // =============================================================================

  void _continueToPayment() {
    if (_selectedDate == null ||
        _selectedTime == null ||
        _customerTrainingPlace == null ||
        _finalLocationLabel.trim().isEmpty) {
      return;
    }

    final scheduledAt = _combineDateAndTime(_selectedDate!, _selectedTime!);

    final checkoutData = BookingCheckoutData(
      trainer: trainer,
      customerTrainingPlace: _customerTrainingPlace!,
      venueChoice: _venueChoice,
      locationLabel: _finalLocationLabel,
      sessionRate: _activeSessionRate,
      serviceFee: _serviceFee,
      total: _total,
      scheduledAt: scheduledAt,
      paymentMethod: _paymentMethod,
      goal: widget.initialGoal,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      sourceConciergeRequestId: widget.sourceConciergeRequestId,
    );

    context.push(GSWRoutes.bookingPayment, extra: checkoutData);
  }

  // =============================================================================
  // BUILD
  // =============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildProgressHeader(),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GSWColors.primary))
                  : _buildCurrentStep(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isLoading ? null : _buildBottomActions(),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 1) {
      return _buildLocationPreferenceStep();
    }

    if (_isVenueChoiceStep) {
      return _buildPrivateGymChoiceStep();
    }

    if (_isTimeStep) {
      return _buildTimeStep();
    }

    return _buildReviewStep();
  }

  // =============================================================================
  // PROGRESS HEADER
  // =============================================================================

  Widget _buildProgressHeader() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _currentStep == 1 ? _closeFlow : _goBack,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GSWColors.borderSecondary),
              ),
              alignment: Alignment.center,
              child: _currentStep == 1
                  ? SvgPicture.asset(
                      GSWIcons.close,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
                    )
                  : const Icon(Icons.chevron_left_rounded, size: 30, color: GSWColors.primary),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _currentStep / _totalSteps,
              minHeight: 8,
              backgroundColor: GSWColors.surfaceInteractive,
              valueColor: const AlwaysStoppedAnimation<Color>(GSWColors.primary),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Text(
          '$_currentStep of $_totalSteps',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  // =============================================================================
  // STEP 1 — CUSTOMER LOCATION PREFERENCE
  // =============================================================================

  Widget _buildLocationPreferenceStep() {
    return _stepScroll(
      children: [
        _buildPageHeading(
          title: 'Confirm where you are training',
          subtitle: '${trainer.fullName}, $_trainerService',
        ),

        const SizedBox(height: 24),

        Text('Where', style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary)),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Gym',
                selected: _customerTrainingPlace == CustomerTrainingPlace.gym,
                onTap: () => _selectCustomerTrainingPlace(CustomerTrainingPlace.gym),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _buildChoiceChip(
                label: 'Home',
                selected: _customerTrainingPlace == CustomerTrainingPlace.home,
                onTap: () => _selectCustomerTrainingPlace(CustomerTrainingPlace.home),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _buildChoiceChip(
                label: 'Outdoors',
                selected: _customerTrainingPlace == CustomerTrainingPlace.outdoors,
                onTap: () => _selectCustomerTrainingPlace(CustomerTrainingPlace.outdoors),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        Text(
          'Preferred area',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 8),

        GSWTextField(
          size: GSWTextFieldSize.large,
          controller: _preferredAreaController,
          enabled: _customerTrainingPlace != null,
          hintText: _customerTrainingPlace == null ? 'Choose where first' : _areaHint,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            setState(() {});
          },
          onComplete: (_) {
            if (_stepComplete) {
              _goNext();
            }
          },
        ),

        const SizedBox(height: 10),

        Text(
          _areaHelpingText,
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }

  String get _areaHint {
    switch (_customerTrainingPlace) {
      case CustomerTrainingPlace.gym:
        return 'e.g. Dubai Marina';

      case CustomerTrainingPlace.home:
        return 'e.g. Marina and JLT';

      case CustomerTrainingPlace.outdoors:
        return 'e.g. Dubai Marina';

      case null:
        return 'Preferred area';
    }
  }

  String get _areaHelpingText {
    switch (_customerTrainingPlace) {
      case CustomerTrainingPlace.gym:
        return 'Tell us the area where you would prefer to train at a gym.';

      case CustomerTrainingPlace.home:
        return 'Tell us the area where your home is located.';

      case CustomerTrainingPlace.outdoors:
        return 'Tell us the area where you would prefer to train outdoors.';

      case null:
        return 'Choose where you would like to train first.';
    }
  }

  // =============================================================================
  // OPTIONAL STEP — TRAINER PRIVATE GYM
  // =============================================================================

  Widget _buildPrivateGymChoiceStep() {
    return _stepScroll(
      children: [
        _buildPageHeading(
          title: 'How would you like to train?',
          subtitle: '${trainer.fullName}, $_trainerService',
        ),

        if (widget.initialGoal?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 28),

          Text(
            'For: ${widget.initialGoal!.trim()}',
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
          ),
        ],

        const SizedBox(height: 28),

        _buildVenueCard(
          choice: BookingVenueChoice.trainerPrivateGym,
          title: '60 minutes at his gym',
          location: _gymLocationLabel!,
          price: _gymPrice!,
        ),

        const SizedBox(height: 18),

        _buildVenueCard(
          choice: BookingVenueChoice.customerChoice,
          title: '60 minutes $_customerVenueDescription',
          location: _customerLocationLabel,
          price: _standardPrice,
        ),

        const SizedBox(height: 26),

        Text(
          'Prices are the session rate. A 5% service fee is added at checkout, and the total is shown before you pay.',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildVenueCard({
    required BookingVenueChoice choice,
    required String title,
    required String location,
    required double price,
  }) {
    final selected = _venueChoice == choice;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectVenueChoice(choice),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? GSWColors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      location,
                      style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Text(
                'AED $price',
                style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // TIME
  // =============================================================================

  Widget _buildTimeStep() {
    return _stepScroll(
      children: [
        _buildPageHeading(title: 'Pick a time', subtitle: '${trainer.fullName}, $_trainerService'),

        const SizedBox(height: 24),

        Text(
          '60 minutes $_finalTrainingDescription, $_finalLocationLabel',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: _availableDates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return _buildDateCard(_availableDates[index]);
            },
          ),
        ),

        const SizedBox(height: 24),

        if (_selectedDate != null) ...[
          Text(
            _fullDate(_selectedDate!),
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              for (int index = 0; index < _timeSlots.length; index++) ...[
                Expanded(child: _buildTimeCard(_timeSlots[index])),

                if (index != _timeSlots.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Times shown allow trainer travel time between clients. The slot is held for 10 minutes once you continue.',
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.45),
          ),
        ],
      ],
    );
  }

  String get _finalTrainingDescription {
    if (_venueChoice == BookingVenueChoice.trainerPrivateGym && _hasPrivateGym) {
      return 'at his gym';
    }

    return _customerVenueDescription;
  }

  Widget _buildDateCard(DateTime date) {
    final selected = _selectedDate != null && _sameDate(_selectedDate!, date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDate = date;

            _selectedTime = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _shortWeekday(date),
                style: GSWTextStyles.bodyExtraSmall.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${date.day}',
                style: GSWTextStyles.bodyLarge.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(String time) {
    final selected = _selectedTime == time;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTime = time;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
          ),
          child: Column(
            children: [
              Text(
                time,
                textAlign: TextAlign.center,
                style: GSWTextStyles.titleExtraSmall.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                '60 min',
                style: GSWTextStyles.bodyExtraSmall.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // REVIEW
  // =============================================================================

  Widget _buildReviewStep() {
    return _stepScroll(
      children: [
        _buildPageHeading(title: 'Review and pay'),

        const SizedBox(height: 24),

        _buildBookingSummaryCard(),

        const SizedBox(height: 24),

        GSWTextArea(
          size: GSWTextAreaSize.large,
          controller: _notesController,
          label: 'Anything $_trainerFirstName should know?',
          hintText: 'Anything $_trainerFirstName should know before the session...',
          helpingText: 'Please don’t include health details here.',
          maxLength: 250,
          onChanged: (_) {
            setState(() {});
          },
        ),

        const SizedBox(height: 8),

        Text(
          '$_trainerFirstName receives your name and mobile number so they can reach you on the day.',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        _buildPriceBreakdown(),

        const SizedBox(height: 24),

        Text(
          'Cancellation',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 8),

        Text(
          '24 hours or more before: the session fee is refunded. '
          'Less than 24 hours before: half the session fee is refunded. '
          'If you don’t turn up: nothing is refunded. '
          'The 5% service fee is not refunded when you cancel. '
          'You can move the booking once. '
          'If $_trainerFirstName cancels or doesn’t turn up, you choose a full refund, a new time, or another trainer.',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.5),
        ),

        const SizedBox(height: 24),

        Text('Pay with', style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary)),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildPaymentMethod(method: BookingPaymentMethod.card, label: 'Card'),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _buildPaymentMethod(method: BookingPaymentMethod.applePay, label: 'Apple Pay'),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBookingSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GSWColors.surfaceInteractive,
                  image: trainer.profileImageUrl?.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(trainer.profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: trainer.profileImageUrl?.isNotEmpty == true
                    ? null
                    : Text(
                        trainer.fullName.trim().isEmpty
                            ? ''
                            : trainer.fullName.trim()[0].toUpperCase(),
                        style: GSWTextStyles.bodyLarge.copyWith(
                          color: GSWColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.fullName,
                      style: GSWTextStyles.bodyLarge.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      _trainerService,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Edit',
                    style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.primary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: GSWColors.borderSecondary),

          const SizedBox(height: 14),

          _buildSummaryRow(
            label: 'When',
            value: _selectedDate == null || _selectedTime == null
                ? ''
                : '${_fullDate(_selectedDate!)}, $_selectedTime',
          ),

          const SizedBox(height: 10),

          _buildSummaryRow(label: 'Where', value: _finalLocationLabel),

          const SizedBox(height: 10),

          _buildSummaryRow(
            label: 'Training',
            value: _venueChoice == BookingVenueChoice.trainerPrivateGym
                ? 'Trainer gym'
                : '$_customerTrainingPlaceLabel · $_customerLocationLabel',
          ),

          if (widget.initialGoal?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),

            _buildSummaryRow(label: 'Goal', value: widget.initialGoal!.trim()),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),

        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildPriceRow(label: 'Session, 60 minutes', amount: _activeSessionRate),

          const SizedBox(height: 10),

          _buildPriceRow(label: 'Service fee (5%)', amount: _serviceFee),

          const SizedBox(height: 10),

          const Divider(height: 1, color: GSWColors.surfaceInteractive),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
                ),
              ),

              Text(
                'AED $_total',
                style: GSWTextStyles.headingSmall.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({required String label, required double amount}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),

        Text(
          'AED $amount',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod({required BookingPaymentMethod method, required String label}) {
    final selected = _paymentMethod == method;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _paymentMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.surfaceInteractive),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // BOTTOM ACTIONS
  // =============================================================================

  Widget _buildBottomActions() {
    return Container(
      color: GSWColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _isReviewStep
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GSWButton(
                      label: 'Continue to payment',
                      onPressed: _continueToPayment,
                      variant: GSWButtonVariant.primary,
                      size: GSWButtonSize.large,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Payments are processed securely by our payment provider. Your card details never reach GetSetWell.',
                      textAlign: TextAlign.center,
                      style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textTertiary),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GSWButton(
                      label: _currentStep == 1 ? 'Back to $_trainerFirstName' : 'Back',
                      onPressed: _currentStep == 1 ? _closeFlow : _goBack,
                      variant: GSWButtonVariant.secondary,
                      size: GSWButtonSize.large,
                    ),

                    const SizedBox(height: 8),

                    GSWButton(
                      label: 'Continue',
                      onPressed: _stepComplete ? _goNext : null,
                      variant: _stepComplete ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
                      size: GSWButtonSize.large,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // =============================================================================
  // SHARED UI
  // =============================================================================

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelLarge.copyWith(
              color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepScroll({required List<Widget> children}) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _buildPageHeading({required String title, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary)),

        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 8),

          Text(subtitle, style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary)),
        ],
      ],
    );
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year && first.month == second.month && first.day == second.day;
  }

  String _shortWeekday(DateTime date) {
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return weekdays[date.weekday - 1];
  }

  String _fullDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${date.day} '
        '${months[date.month - 1]}';
  }
}
