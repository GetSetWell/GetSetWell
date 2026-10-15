import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_photo.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_area.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct booking, Figma Story 5 (5.1 to 5.4) and 11.2e (booking again).
///
/// Four stable steps, numbered once each:
/// 1 Session (where: trainer's gym or a place you choose, with price)
/// 2 Location (Home / Gym / Outdoors and the area or address)
/// 3 Time (Dubai time, 60 minute sessions)
/// 4 Review and pay
class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    super.key,
    required this.trainer,
    this.initialGoal,
    this.sourceConciergeRequestId,
    this.initialTrainingPlace,
    this.initialVenueChoice,
    this.initialLocationLabel,
    this.initialNotes,
    this.isRepeatBooking = false,
  });

  final Trainer trainer;
  final String? initialGoal;
  final String? sourceConciergeRequestId;
  final CustomerTrainingPlace? initialTrainingPlace;
  final BookingVenueChoice? initialVenueChoice;
  final String? initialLocationLabel;
  final String? initialNotes;
  final bool isRepeatBooking;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

enum _LoadState { loading, ready, signInRequired, failed }

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  static const int _totalSteps = 4;
  static const int _stepSession = 1;
  static const int _stepLocation = 2;
  static const int _stepTime = 3;
  static const int _stepReview = 4;

  static const Duration _sessionLength = Duration(hours: 1);
  static const int _maxLocationLength = 150;
  static const int _minHomeAddressLength = 8;

  final SupabaseClient _client = Supabase.instance.client;

  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  _LoadState _loadState = _LoadState.loading;

  int _currentStep = _stepSession;

  /// True when "Book again" skipped straight to the time step. The step
  /// count is hidden then (11.2e), because the numbering would mislead.
  bool _skippedToTime = false;

  CustomerTrainingPlace? _customerTrainingPlace;
  BookingVenueChoice _venueChoice = BookingVenueChoice.customerChoice;

  /// Selected start, Dubai wall-clock time.
  DateTime? _selectedDate;
  DateTime? _selectedStart;

  BookingPaymentMethod _paymentMethod = BookingPaymentMethod.card;

  double? _standardRateFresh;
  double? _gymRate;
  String? _gymLocationLabel;

  /// Open start times, Dubai wall-clock time.
  List<DateTime> _availabilityStarts = const [];

  bool _isOpeningPayment = false;
  bool _showPriceChangedNotice = false;

  /// Area typed for a place the person chooses, kept while the trainer's gym
  /// is selected so switching back restores it.
  String _customerArea = '';

  Trainer get trainer => widget.trainer;

  Object? get _gender => trainer.gender;

  // ===========================================================================
  // TRAINER DATA
  // ===========================================================================

  String get _firstName => BookingCopy.firstName(trainer.fullName);

  String get _service {
    final value = trainer.primaryService?.trim();

    if (value == null || value.isEmpty) return 'Personal training';

    return GSWPronoun.capitalise(value);
  }

  String get _subtitle => '${trainer.fullName}, ${_service.toLowerCase()}';

  double get _standardRate =>
      _roundToFils(_standardRateFresh ?? trainer.pricePerSession?.toDouble() ?? 0);

  bool get _hasPrivateGym =>
      _gymRate != null &&
      _gymRate! > 0 &&
      _gymLocationLabel != null &&
      _gymLocationLabel!.trim().isNotEmpty;

  bool get _atTrainerGym =>
      _venueChoice == BookingVenueChoice.trainerPrivateGym && _hasPrivateGym;

  // ===========================================================================
  // PRICE (all maths in fils through GSWMoney)
  // ===========================================================================

  static double _roundToFils(num value) => GSWMoney.fromFils(GSWMoney.toFils(value));

  double get _sessionRate => _atTrainerGym ? _roundToFils(_gymRate!) : _standardRate;

  double get _serviceFee => GSWMoney.serviceFee(_sessionRate);

  double get _total => GSWMoney.totalWithFee(_sessionRate);

  // ===========================================================================
  // LOCATION
  // ===========================================================================

  String get _finalLocationLabel =>
      _atTrainerGym ? _gymLocationLabel!.trim() : _areaController.text.trim();

  CustomerTrainingPlace? get _effectiveTrainingPlace =>
      _atTrainerGym ? CustomerTrainingPlace.gym : _customerTrainingPlace;

  /// "at his gym", "at your place", "at your gym", "outdoors".
  String get _sessionPlacePhrase {
    if (_atTrainerGym) return 'at ${GSWPronoun.possessive(_gender)} gym';

    return _customerPlacePhrase;
  }

  String get _customerPlacePhrase {
    switch (_customerTrainingPlace) {
      case CustomerTrainingPlace.gym:
        return 'at your gym';
      case CustomerTrainingPlace.outdoors:
        return 'outdoors';
      case CustomerTrainingPlace.home:
      case null:
        return 'at your place';
    }
  }

  String get _whereLabel => BookingCopy.whereLabel(
        venueChoice: _atTrainerGym
            ? BookingVenueChoice.trainerPrivateGym
            : BookingVenueChoice.customerChoice,
        customerTrainingPlace: _effectiveTrainingPlace ?? CustomerTrainingPlace.gym,
        locationLabel: _finalLocationLabel,
        trainerGender: _gender,
      );

  String? get _locationError {
    final value = _areaController.text.trim();

    if (value.length > _maxLocationLength) {
      return 'Keep this under $_maxLocationLength characters.';
    }

    return null;
  }

  // ===========================================================================
  // DATES (Dubai wall-clock time from GSWTime)
  // ===========================================================================

  List<DateTime> get _dates {
    final now = GSWTime.nowDubai();
    final today = DateTime.utc(now.year, now.month, now.day);

    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  List<DateTime> _startsOn(DateTime date) =>
      _availabilityStarts.where((value) => GSWTime.isSameDay(value, date)).toList()..sort();

  bool _dateHasAvailability(DateTime date) =>
      _availabilityStarts.any((value) => GSWTime.isSameDay(value, date));

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  bool get _stepComplete {
    switch (_currentStep) {
      case _stepSession:
        return _sessionRate > 0;

      case _stepLocation:
        if (_atTrainerGym) return true;
        if (_customerTrainingPlace == null) return false;
        final area = _areaController.text.trim();
        if (area.isEmpty || _locationError != null) return false;
        if (_customerTrainingPlace == CustomerTrainingPlace.home &&
            area.length < _minHomeAddressLength) {
          return false;
        }
        return true;

      case _stepTime:
        return _selectedStart != null;

      default:
        return true;
    }
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _customerTrainingPlace = widget.initialTrainingPlace;
    _venueChoice = widget.initialVenueChoice ?? BookingVenueChoice.customerChoice;

    final initialLocation = widget.initialLocationLabel?.trim() ?? '';

    if (_venueChoice == BookingVenueChoice.customerChoice && initialLocation.isNotEmpty) {
      _areaController.text = initialLocation;
      _customerArea = initialLocation;
    }

    final initialNotes = widget.initialNotes?.trim() ?? '';

    if (initialNotes.isNotEmpty) {
      _notesController.text =
          initialNotes.length > 250 ? initialNotes.substring(0, 250) : initialNotes;
    }

    _loadTrainerBookingData(isInitialLoad: true);
  }

  @override
  void dispose() {
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // BACKEND
  // ===========================================================================

  Future<void> _loadTrainerBookingData({bool isInitialLoad = false}) async {
    if (_loadState != _LoadState.loading) {
      setState(() {
        _loadState = _LoadState.loading;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('trainers')
            .select('price_per_session, gym_price_per_session, gym_location_label')
            .eq('id', trainer.id)
            .maybeSingle(),
        _client.rpc('get_trainer_booking_availability', params: {'p_trainer_id': trainer.id}),
      ]);

      final trainerRow = results[0] as Map<String, dynamic>?;
      final availabilityResult = results[1];

      final standardRate = GSWMoney.parse(trainerRow?['price_per_session']);
      final gymRate = GSWMoney.parse(trainerRow?['gym_price_per_session']);
      final gymLocation = trainerRow?['gym_location_label']?.toString().trim();

      final starts = <DateTime>[];

      if (availabilityResult is List) {
        for (final row in availabilityResult) {
          if (row is! Map) continue;
          final startsAt = GSWTime.parseToDubai(row['starts_at']);
          if (startsAt != null) starts.add(startsAt);
        }
      }

      starts.sort();

      if (!mounted) return;

      setState(() {
        if (standardRate != null && standardRate > 0) {
          _standardRateFresh = standardRate;
        }

        if (gymRate != null && gymRate > 0 && gymLocation != null && gymLocation.isNotEmpty) {
          _gymRate = gymRate;
          _gymLocationLabel = gymLocation;
        } else {
          _gymRate = null;
          _gymLocationLabel = null;
        }

        // A repeat booking may carry the trainer's gym from last time. If the
        // gym option no longer loads, fall back to a place the person chooses.
        if (!_hasPrivateGym) {
          _venueChoice = BookingVenueChoice.customerChoice;
        }

        _availabilityStarts = starts;

        // Drop a selection that is no longer offered.
        if (_selectedStart != null && !starts.contains(_selectedStart)) {
          _selectedStart = null;
        }

        if (_selectedDate == null || !_dateHasAvailability(_selectedDate!)) {
          _selectedDate = _firstAvailableDate();
        }

        if (isInitialLoad && widget.isRepeatBooking) {
          final canReuseLocation = _atTrainerGym ||
              (_customerTrainingPlace != null && _areaController.text.trim().isNotEmpty);

          if (canReuseLocation) {
            _currentStep = _stepTime;
            _skippedToTime = true;
          }
        }

        _loadState = _LoadState.ready;
      });
    } catch (error) {
      debugPrint('Booking trainer data load failed: $error');

      if (!mounted) return;

      setState(() {
        _loadState = _isAuthRequired(error) ? _LoadState.signInRequired : _LoadState.failed;
      });
    }
  }

  bool _isAuthRequired(Object error) {
    if (error is PostgrestException) {
      return error.message.contains('AUTH_REQUIRED') ||
          (error.details?.toString().contains('AUTH_REQUIRED') ?? false);
    }

    return error.toString().contains('AUTH_REQUIRED');
  }

  DateTime? _firstAvailableDate() {
    for (final date in _dates) {
      if (_dateHasAvailability(date)) return date;
    }

    return null;
  }

  Future<void> _signIn() async {
    await context.push(GSWRoutes.userAuth, extra: const AuthFlowIntent.returnToCaller());

    if (!mounted) return;

    _loadTrainerBookingData(isInitialLoad: true);
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _goNext() {
    if (!_stepComplete || _currentStep >= _totalSteps) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _currentStep++;
    });
  }

  void _goBack() {
    if (_currentStep <= _stepSession) {
      _closeFlow();
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _currentStep--;
      if (_currentStep < _stepTime) _skippedToTime = false;
    });
  }

  void _closeFlow() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(GSWRoutes.home);
    }
  }

  void _editBooking() {
    setState(() {
      _currentStep = _stepSession;
      _skippedToTime = false;
    });
  }

  // ===========================================================================
  // CHOICES
  // ===========================================================================

  void _selectVenue(BookingVenueChoice choice) {
    setState(() {
      if (choice == _venueChoice) return;

      if (choice == BookingVenueChoice.trainerPrivateGym) {
        _customerArea = _areaController.text;
      } else {
        _areaController.text = _customerArea;
      }

      _venueChoice = choice;
    });
  }

  void _selectTrainingPlace(CustomerTrainingPlace place) {
    setState(() {
      if (_customerTrainingPlace != place && place == CustomerTrainingPlace.home) {
        // A home session needs a real address, not an area.
        if (_customerTrainingPlace != null) _areaController.clear();
      }

      _customerTrainingPlace = place;
    });
  }

  // ===========================================================================
  // PAYMENT
  // ===========================================================================

  Future<void> _continueToPayment() async {
    if (_isOpeningPayment) return;

    final start = _selectedStart;
    final place = _effectiveTrainingPlace;

    if (start == null || place == null || _finalLocationLabel.isEmpty || _sessionRate <= 0) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isOpeningPayment = true;
      _showPriceChangedNotice = false;
    });

    final notes = _notesController.text.trim();

    final checkoutData = BookingCheckoutData(
      trainer: trainer,
      customerTrainingPlace: place,
      venueChoice:
          _atTrainerGym ? BookingVenueChoice.trainerPrivateGym : BookingVenueChoice.customerChoice,
      locationLabel: _finalLocationLabel,
      sessionRate: _sessionRate,
      serviceFee: _serviceFee,
      total: _total,
      scheduledAt: start,
      paymentMethod: _paymentMethod,
      goal: widget.initialGoal?.trim().isEmpty == true ? null : widget.initialGoal?.trim(),
      notes: notes.isEmpty ? null : notes,
      sourceConciergeRequestId: widget.sourceConciergeRequestId,
      availableStarts: _availabilityStarts,
      isRepeatBooking: widget.isRepeatBooking,
    );

    final outcome = await context.push<BookingPaymentOutcome>(
      GSWRoutes.bookingPayment,
      extra: checkoutData,
    );

    if (!mounted) return;

    setState(() {
      _isOpeningPayment = false;
    });

    switch (outcome) {
      case BookingPaymentOutcome.priceChanged:
        await _loadTrainerBookingData();
        if (!mounted) return;
        setState(() {
          _currentStep = _stepReview;
          _showPriceChangedNotice = true;
        });

      case BookingPaymentOutcome.pickAnotherTime:
        setState(() {
          _selectedStart = null;
          _currentStep = _stepTime;
        });
        await _loadTrainerBookingData();

      case BookingPaymentOutcome.changePaymentMethod:
      case null:
        break;
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: switch (_loadState) {
          _LoadState.loading => const Center(
              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          _LoadState.signInRequired => _buildSignInState(),
          _LoadState.failed => _buildLoadFailedState(),
          _LoadState.ready => _buildCurrentStep(),
        },
      ),
      bottomNavigationBar: _loadState == _LoadState.ready ? _buildBottomBar() : null,
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _stepSession:
        return _buildSessionStep();
      case _stepLocation:
        return _buildLocationStep();
      case _stepTime:
        return _buildTimeStep();
      default:
        return _buildReviewStep();
    }
  }

  // ===========================================================================
  // LOAD STATES
  // ===========================================================================

  Widget _buildSignInState() {
    return _buildMessageState(
      title: 'Sign in to book',
      body: 'Sign in with your mobile number to see $_firstName’s open times and book a session.',
      primaryLabel: 'Sign in',
      onPrimary: _signIn,
    );
  }

  Widget _buildLoadFailedState() {
    return _buildMessageState(
      title: 'We couldn’t load $_firstName’s times',
      body: 'Check your connection and try again.',
      primaryLabel: 'Try again',
      onPrimary: () => _loadTrainerBookingData(isInitialLoad: true),
    );
  }

  Widget _buildMessageState({
    required String title,
    required String body,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(alignment: Alignment.centerLeft, child: _buildCloseButton()),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GSWTextStyles.titleLarge.copyWith(
                    color: GSWColors.textPrimary,
                    height: 30 / 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        _bottomBarShell(
          children: [
            GSWButton(
              label: primaryLabel,
              onPressed: onPrimary,
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
            ),
            GSWButton(
              label: 'Back to $_firstName',
              onPressed: _closeFlow,
              variant: GSWButtonVariant.secondary,
              size: GSWButtonSize.large,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER (close or back, progress, step count)
  // ===========================================================================

  Widget _buildHeader() {
    final isReview = _currentStep == _stepReview;
    final showProgress = !_skippedToTime;

    return Row(
      children: [
        isReview ? _buildBackButton() : _buildCloseButton(),
        const SizedBox(width: 16),
        Expanded(
          child: showProgress
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(GSWRadius.full),
                  child: Container(
                    height: 8,
                    color: GSWColors.surfaceInteractive,
                    child: Row(
                      children: [
                        for (var step = 1; step <= _totalSteps; step++)
                          Expanded(
                            child: Container(
                              height: 8,
                              color: step <= _currentStep
                                  ? GSWColors.primary
                                  : GSWColors.surfaceInteractive,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (showProgress) ...[
          const SizedBox(width: 16),
          Text(
            '$_currentStep of $_totalSteps',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        ],
      ],
    );
  }

  Widget _buildCloseButton() {
    return Semantics(
      button: true,
      label: 'Close booking',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _closeFlow,
          customBorder: const CircleBorder(),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GSWColors.backgroundOverlay,
              border: Border.all(color: GSWColors.borderSecondary),
            ),
            child: SvgPicture.asset(
              GSWIcons.close,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _goBack,
          customBorder: const CircleBorder(),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GSWColors.borderSecondary),
            ),
            child: SvgPicture.asset(
              GSWIcons.arrowheadLeft,
              width: 30,
              height: 30,
              colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1, SESSION (5.1)
  // ===========================================================================

  Widget _buildSessionStep() {
    final goal = widget.initialGoal?.trim() ?? '';

    final customerArea = _venueChoice == BookingVenueChoice.customerChoice
        ? _areaController.text.trim()
        : _customerArea.trim();

    return _stepScroll(
      children: [
        _buildHeading(title: 'How would you like to train?', subtitle: _subtitle),
        if (goal.isNotEmpty)
          Text(
            'For: $goal',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        if (_hasPrivateGym)
          _buildVenueCard(
            choice: BookingVenueChoice.trainerPrivateGym,
            title: '60 minutes at ${GSWPronoun.possessive(_gender)} gym',
            location: _gymLocationLabel!,
            price: _roundToFils(_gymRate!),
          ),
        _buildVenueCard(
          choice: BookingVenueChoice.customerChoice,
          title: '60 minutes $_customerPlacePhrase',
          location: customerArea.isEmpty ? 'Home, your gym or outdoors' : customerArea,
          price: _standardRate,
        ),
        Text(
          'Prices are the session rate. A 5% service fee is added at checkout, and the total is shown before you pay.',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
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
    final selected = _venueChoice == choice || (!_hasPrivateGym && choice == BookingVenueChoice.customerChoice);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectVenue(choice),
          borderRadius: BorderRadius.circular(GSWRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(GSWRadius.control),
              border: Border.all(
                width: 1.5,
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
                        style: GSWTextStyles.labelLarge.copyWith(
                          color: GSWColors.textPrimary,
                          height: 22 / 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: GSWTextStyles.bodySmall.copyWith(
                          color: GSWColors.textSecondary,
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  GSWMoney.aed(price),
                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textAccent,
                    fontWeight: FontWeight.w600,
                    height: 22 / 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 2, LOCATION (5.2)
  // ===========================================================================

  Widget _buildLocationStep() {
    final atGym = _atTrainerGym;
    final place = _effectiveTrainingPlace;
    final isHome = !atGym && place == CustomerTrainingPlace.home;

    return _stepScroll(
      children: [
        _buildHeading(title: 'Confirm where you are training'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [
                  CustomerTrainingPlace.home,
                  CustomerTrainingPlace.gym,
                  CustomerTrainingPlace.outdoors,
                ])
                  _buildPlaceChip(
                    place: option,
                    selected: place == option,
                    enabled: !atGym || option == CustomerTrainingPlace.gym,
                  ),
              ],
            ),
          ],
        ),
        if (atGym)
          _buildFixedLocation()
        else
          GSWTextField(
            size: GSWTextFieldSize.large,
            controller: _areaController,
            label: isHome ? 'Your address' : 'Preferred area',
            leadingIcon: GSWIcons.location,
            enabled: place != null,
            hintText: _areaHint(place),
            helpingText: _areaHelpingText(place),
            errorText: _locationError,
            keyboardType: isHome ? TextInputType.streetAddress : TextInputType.text,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onComplete: (_) {
              if (_stepComplete) _goNext();
            },
          ),
      ],
    );
  }

  /// The trainer's own gym: the address is fixed, so it is shown, not edited.
  Widget _buildFixedLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred area',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.control),
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                GSWIcons.location,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gymLocationLabel ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _areaHelpingText(null) ?? '',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPlaceChip({
    required CustomerTrainingPlace place,
    required bool selected,
    required bool enabled,
  }) {
    final label = switch (place) {
      CustomerTrainingPlace.home => 'Home',
      CustomerTrainingPlace.gym => 'Gym',
      CustomerTrainingPlace.outdoors => 'Outdoors',
    };

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => _selectTrainingPlace(place) : null,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? GSWColors.primary : GSWColors.surfaceElevated,
                borderRadius: BorderRadius.circular(GSWRadius.full),
                border: Border.all(
                  color: selected ? GSWColors.primary : GSWColors.borderSecondary,
                ),
              ),
              child: Text(
                label,
                style: GSWTextStyles.labelLarge.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _areaHint(CustomerTrainingPlace? place) {
    if (_atTrainerGym) return _gymLocationLabel ?? '';

    switch (place) {
      case CustomerTrainingPlace.home:
        return 'Villa or building, street and area';
      case CustomerTrainingPlace.gym:
        return 'Gym name and area, e.g. Dubai Marina';
      case CustomerTrainingPlace.outdoors:
        return 'Park or area, e.g. Kite Beach';
      case null:
        return 'Choose where first';
    }
  }

  String? _areaHelpingText(CustomerTrainingPlace? place) {
    if (_atTrainerGym) {
      return 'You are training at ${GSWPronoun.possessive(_gender)} gym. Go back to change this.';
    }

    if (place == CustomerTrainingPlace.home) {
      final length = _areaController.text.trim().length;
      if (length > 0 && length < _minHomeAddressLength) {
        return 'Add your building or villa and street so $_firstName can find you.';
      }
      return '$_firstName needs your full address for a home session.';
    }

    return null;
  }

  // ===========================================================================
  // STEP 3, TIME (5.3)
  // ===========================================================================

  Widget _buildTimeStep() {
    final selectedDate = _selectedDate;
    final starts = selectedDate == null ? const <DateTime>[] : _startsOn(selectedDate);

    return _stepScroll(
      children: [
        _buildHeading(title: 'Pick a time', subtitle: _subtitle, titleHeight: 30),
        Text(
          '60 minutes $_sessionPlacePhrase, $_finalLocationLabel',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),
        Row(
          children: [
            for (var index = 0; index < _dates.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: _buildDateCell(_dates[index])),
            ],
          ],
        ),
        if (_availabilityStarts.isEmpty)
          _buildNoTimesCard()
        else if (selectedDate != null) ...[
          Text(
            GSWTime.dayLong(selectedDate),
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = (constraints.maxWidth - 16) / 3;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final start in starts)
                    SizedBox(width: slotWidth, child: _buildSlot(start)),
                ],
              );
            },
          ),
        ],
        Text(
          'Times are in Dubai time and show when $_firstName is free this week.',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildNoTimesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No open times this week',
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '$_firstName has no free 60 minute slots in the next 7 days. Check again later, or go back and pick another trainer.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'Check again',
            onPressed: () => _loadTrainerBookingData(),
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.medium,
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(DateTime date) {
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    final selected = _selectedDate != null && GSWTime.isSameDay(_selectedDate!, date);
    final available = _dateHasAvailability(date);

    final topColor = selected
        ? GSWColors.textInverse
        : available
            ? GSWColors.textSecondary
            : GSWColors.textTertiary;

    final bottomColor = selected
        ? GSWColors.textInverse
        : available
            ? GSWColors.textPrimary
            : GSWColors.textTertiary;

    return Semantics(
      selected: selected,
      enabled: available,
      button: true,
      label: GSWTime.dayLong(date),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: available
              ? () {
                  setState(() {
                    _selectedDate = date;
                    if (_selectedStart != null && !GSWTime.isSameDay(_selectedStart!, date)) {
                      _selectedStart = null;
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(GSWRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 60,
            decoration: BoxDecoration(
              color: selected ? GSWColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(GSWRadius.control),
              border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[date.weekday - 1],
                  style: GSWTextStyles.bodyExtraSmall.copyWith(color: topColor, height: 14 / 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: GSWTextStyles.labelLarge.copyWith(
                    color: bottomColor,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(DateTime start) {
    final selected = _selectedStart == start;

    return Semantics(
      selected: selected,
      button: true,
      label: '${GSWTime.dayLong(start)}, ${GSWTime.time(start)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedStart = start;
            });
          },
          borderRadius: BorderRadius.circular(GSWRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            // 64 at the default text size, taller rather than overflowing when
            // the person uses a larger font.
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? GSWColors.primary : GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(GSWRadius.control),
              border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    GSWTime.time(start),
                    style: GSWTextStyles.titleExtraSmall.copyWith(
                      color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 24 / 18,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '60 min',
                  style: GSWTextStyles.bodyExtraSmall.copyWith(
                    color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                    height: 14 / 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 4, REVIEW AND PAY (5.4, 11.2e)
  // ===========================================================================

  Widget _buildReviewStep() {
    return _stepScroll(
      topPadding: 8,
      children: [
        Text(
          'Review and pay',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),
        if (_showPriceChangedNotice) _buildPriceChangedNotice(),
        _buildSummaryCard(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GSWTextArea(
              size: GSWTextAreaSize.medium,
              controller: _notesController,
              label: 'Anything $_firstName should know?',
              hintText: 'Anything $_firstName should know before the session...',
              helpingText: 'Please don’t include health details here.',
              maxLength: 250,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              '$_firstName receives your name and mobile number so ${GSWPronoun.subject(_gender)} can reach you on the day.',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 18 / 12),
            ),
          ],
        ),
        _buildPriceCard(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancellation',
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
            ),
            const SizedBox(height: 8),
            Text(
              _cancellationCopy,
              style: GSWTextStyles.bodySmall.copyWith(
                color: GSWColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay with',
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethod(method: BookingPaymentMethod.card, label: 'Card'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethod(
                    method: BookingPaymentMethod.applePay,
                    label: 'Apple Pay',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// v1.2 cancellation policy, with this booking's numbers.
  String get _cancellationCopy {
    final rate = GSWMoney.aed(_sessionRate);
    final half = GSWMoney.aed(GSWMoney.half(_sessionRate));
    final fee = GSWMoney.aed(_serviceFee);
    final total = GSWMoney.aed(_total);

    return '24 hours or more before: the $rate session rate back. '
        'Less than 24 hours before: $half back, half the session rate. '
        'If you don’t turn up: nothing back. '
        'The $fee service fee isn’t refunded when you cancel. '
        'You can move the booking once, free up to 24 hours before. '
        'A later move costs the same as a late cancellation. '
        'If $_firstName cancels or doesn’t turn up, you choose: the full $total back, a new time, or another trainer.';
  }

  Widget _buildPriceChangedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.backgroundWarning,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.borderWarning),
      ),
      child: Text(
        '$_firstName’s price has changed since you started. Check the new total below, then pay. You have not been charged.',
        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final start = _selectedStart;
    final goal = widget.initialGoal?.trim() ?? '';
    final imageUrl = trainer.profileImageUrl?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // TrainerPhoto falls back to initials if the image fails.
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: TrainerPhoto(
                    name: trainer.fullName,
                    imageUrl: imageUrl.isEmpty ? null : imageUrl,
                    initialsStyle: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
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
                      style: GSWTextStyles.labelLarge.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 22 / 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _service,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit booking',
                child: InkWell(
                  onTap: _editBooking,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Edit',
                      style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textAccent, height: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: GSWColors.surfaceInteractive),
          const SizedBox(height: 12),
          _buildSummaryRow(
            label: 'When',
            value: start == null
                ? ''
                : '${GSWTime.dayShort(start)}, ${GSWTime.timeRange(start, _sessionLength)}',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(label: 'Where', value: _whereLabel),
          if (goal.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(label: 'Goal', value: GSWPronoun.capitalise(goal)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 1),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        children: [
          _buildPriceRow(label: 'Session, 60 minutes', amount: _sessionRate),
          const SizedBox(height: 10),
          _buildPriceRow(label: 'Service fee (5%)', amount: _serviceFee),
          const SizedBox(height: 10),
          Container(height: 1, color: GSWColors.surfaceInteractive),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                ),
              ),
              Text(
                GSWMoney.aed(_total),
                style: GSWTextStyles.headingSmall.copyWith(color: GSWColors.textAccent, height: 1),
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
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        ),
        Text(
          GSWMoney.aed(amount),
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod({required BookingPaymentMethod method, required String label}) {
    final selected = _paymentMethod == method;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _paymentMethod = method),
          borderRadius: BorderRadius.circular(GSWRadius.control),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(GSWRadius.control),
              border: Border.all(
                width: selected ? 1.5 : 1,
                color: selected ? GSWColors.primary : GSWColors.surfaceInteractive,
              ),
            ),
            child: Text(
              label,
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM BAR
  // ===========================================================================

  Widget _buildBottomBar() {
    if (_currentStep == _stepReview) {
      final canPay = _selectedStart != null && _sessionRate > 0 && !_isOpeningPayment;

      return Container(
        color: GSWColors.surfacePrimary,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GSWButton(
                  label: 'Pay ${GSWMoney.aed(_total)} and confirm',
                  onPressed: canPay ? _continueToPayment : null,
                  variant: canPay ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
                  size: GSWButtonSize.large,
                  isLoading: _isOpeningPayment,
                ),
                const SizedBox(height: 8),
                Text(
                  'Payments are processed securely by our payment provider. Your card details never reach GetSetWell.',
                  textAlign: TextAlign.center,
                  style: GSWTextStyles.bodyExtraSmall.copyWith(
                    color: GSWColors.textSecondary,
                    height: 14 / 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _bottomBarShell(
      children: [
        GSWButton(
          label: _currentStep == _stepSession ? 'Back to $_firstName' : 'Back',
          onPressed: _goBack,
          variant: GSWButtonVariant.secondary,
          size: GSWButtonSize.large,
        ),
        GSWButton(
          label: 'Continue',
          onPressed: _stepComplete ? _goNext : null,
          variant: _stepComplete ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
          size: GSWButtonSize.large,
        ),
      ],
    );
  }

  Widget _bottomBarShell({required List<Widget> children}) {
    return Container(
      decoration: const BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.card)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                children[index],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARED LAYOUT
  // ===========================================================================

  Widget _stepScroll({required List<Widget> children, double topPadding = 16}) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            for (final child in children) ...[
              const SizedBox(height: 24),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeading({required String title, String? subtitle, double titleHeight = 24}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GSWTextStyles.titleLarge.copyWith(
            color: GSWColors.textPrimary,
            height: titleHeight / 24,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        ],
      ],
    );
  }
}
