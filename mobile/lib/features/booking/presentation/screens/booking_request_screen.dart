import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_checkbox.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_area.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/booking/data/services/booking_request_service.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:mobile/features/booking/domain/models/trainer_request_payload.dart';
import 'package:mobile/features/booking/domain/validators/uae_phone_validator.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/domain/models/training_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({super.key, required this.trainer});

  final Trainer trainer;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  // All booking-request state belongs inside this State class.
  String? _selectedGoal;
  int _currentStep = 1;
  TrainingLocation? _selectedLocation;
  String _formattedSelectedDays() {
    return _selectedDays
        .map((day) {
          switch (day) {
            case 'Monday':
              return 'Mon';
            case 'Tuesday':
              return 'Tue';
            case 'Wednesday':
              return 'Wed';
            case 'Thursday':
              return 'Thu';
            case 'Friday':
              return 'Fri';
            case 'Saturday':
              return 'Sat';
            case 'Sunday':
              return 'Sun';
            default:
              return day;
          }
        })
        .join(', ');
  }

  List<TrainingLocation> _availableTrainingLocations = [];

  late final TrainerRepository _trainerRepository;
  late final BookingRequestService _bookingRequestService;

  String? _selectedTime;
  final Set<String> _selectedDays = {};

  final TextEditingController _preferredAreaController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _shareDetailsConsent = false;
  bool _showPhoneError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _trainerRepository = TrainerRepository(Supabase.instance.client);

    _bookingRequestService = BookingRequestService(Supabase.instance.client);

    _loadTrainerTrainingLocations();
  }

  @override
  void dispose() {
    _preferredAreaController.dispose();
    _nameController.dispose();
    _whatsAppController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  TrainerRequestPayload _buildRequestPayload() {
    return TrainerRequestPayload(
      trainerId: widget.trainer.id,
      customerName: _nameController.text.trim(),
      phone: UAEPhoneValidator.toE164(_whatsAppController.text),
      goal: _selectedGoal!,
      preferredDays: _selectedDays.map((day) => day.toLowerCase()).toList(),
      preferredTime: _selectedTime!.toLowerCase(),
      trainingLocationId: _selectedLocation!.id,
      preferredArea: _preferredAreaController.text.trim(),
      message: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      shareDetailsConsent: _shareDetailsConsent,
    );
  }

  Future<void> _loadTrainerTrainingLocations() async {
    try {
      final locations = await _trainerRepository.getTrainerTrainingLocations(widget.trainer.id);

      if (!mounted) return;

      setState(() {
        _availableTrainingLocations = locations;
      });
    } catch (error) {
      debugPrint('Failed to load trainer training locations: $error');

      if (!mounted) return;

      setState(() {
        _availableTrainingLocations = [];
      });
    }
  }

  Widget _buildTrainingLocationOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableTrainingLocations.map((location) {
        final isSelected = _selectedLocation?.id == location.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedLocation = location;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? GSWColors.borderFocused : GSWColors.borderSecondary,
              ),
            ),
            child: Text(
              location.name,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressHeader(),

              const SizedBox(height: 24),

              Expanded(
                child: switch (_currentStep) {
                  1 => _buildStepOne(),
                  2 => _buildStepTwo(),
                  3 => _buildStepThree(),
                  _ => _buildStepOne(),
                },
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomActions(),
    );
  }

  /// Close means abandon the entire request.
  ///
  /// Because all request state now lives inside this State object,
  /// popping this route disposes it. Opening Request a Session again
  /// creates a completely fresh booking request.
  void _closeRequest() {
    Navigator.of(context).pop();
  }

  Widget _buildProgressHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          child: IconButton(
            onPressed: _closeRequest,
            icon: SvgPicture.asset(
              GSWIcons.close,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _currentStep / 3,
              minHeight: 8,
              backgroundColor: GSWColors.surfaceInteractive,
              valueColor: const AlwaysStoppedAnimation<Color>(GSWColors.primary),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Text(
          '$_currentStep of 3',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStepOne() {
    final trainer = widget.trainer;

    final goals = [...trainer.specialties.map((specialty) => specialty.name), 'Something else'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'What do you want\nto ',
                style: GSWTextStyles.displayLarge.copyWith(
                  color: GSWColors.textPrimary,
                  height: 0.9,
                ),
              ),
              TextSpan(
                text: 'work on?',
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.primary, height: 0.9),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'with ${trainer.fullName}, ${trainer.primaryService ?? ''}',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        Expanded(
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final goal = goals[index];

              return _buildGoalOption(
                label: goal,
                isSelected: _selectedGoal == goal,
                onTap: () {
                  setState(() {
                    _selectedGoal = goal;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelMedium.copyWith(
              color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelLarge.copyWith(
              color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTwo() {
    const days = [
      ('Mo', 'Monday'),
      ('Tu', 'Tuesday'),
      ('We', 'Wednesday'),
      ('Th', 'Thursday'),
      ('Fr', 'Friday'),
      ('Sa', 'Saturday'),
      ('Su', 'Sunday'),
    ];

    const times = ['Morning', 'Afternoon', 'Evening'];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADING
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'WHEN AND WHERE\n',
                  style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.primary, height: 1),
                ),
                TextSpan(
                  text: 'CAN YOU TRAIN?',
                  style: GSWTextStyles.displayLarge.copyWith(
                    color: GSWColors.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // DAYS
          Text(
            'Days that work',
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in days)
                _buildDayOption(
                  label: day.$1,
                  isSelected: _selectedDays.contains(day.$2),
                  onTap: () {
                    setState(() {
                      if (_selectedDays.contains(day.$2)) {
                        _selectedDays.remove(day.$2);
                      } else {
                        _selectedDays.add(day.$2);
                      }
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 24),

          // TIME
          Text(
            'Time of day',
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in times)
                _buildCompactOption(
                  label: time,
                  isSelected: _selectedTime == time,
                  onTap: () {
                    setState(() {
                      _selectedTime = time;
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 24),

          // WHERE
          Text('Where', style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary)),

          const SizedBox(height: 8),

          _buildTrainingLocationOptions(),

          const SizedBox(height: 24),

          // PREFERRED AREA
          GSWTextField(
            size: GSWTextFieldSize.large,
            label: 'Preferred area ',
            controller: _preferredAreaController,
            hintText: 'Dubai Marina',
            leadingIcon: GSWIcons.location,
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRequestSummaryItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary)),

        const SizedBox(height: 4),

        Text(
          value,
          style: GSWTextStyles.bodyMedium.copyWith(color: valueColor ?? GSWColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    final trainer = widget.trainer;
    final selectedDays = _selectedDays
        .map((day) {
          switch (day) {
            case 'Monday':
              return 'Mon';
            case 'Tuesday':
              return 'Tue';
            case 'Wednesday':
              return 'Wed';
            case 'Thursday':
              return 'Thu';
            case 'Friday':
              return 'Fri';
            case 'Saturday':
              return 'Sat';
            case 'Sunday':
              return 'Sun';
            default:
              return day;
          }
        })
        .join(', ');

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------------------
            // HEADING
            // ---------------------------------------------------------------------
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'LAST BIT. HOW CAN\n',
                    style: GSWTextStyles.displayLarge.copyWith(
                      color: GSWColors.textPrimary,
                      height: 0.9,
                    ),
                  ),
                  TextSpan(
                    text: 'WE REACH YOU?',
                    style: GSWTextStyles.displayLarge.copyWith(
                      color: GSWColors.primary,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ---------------------------------------------------------------------
            // REQUEST SUMMARY
            // ---------------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GSWColors.surfacePrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your request',
                          style: GSWTextStyles.titleExtraSmall.copyWith(
                            color: GSWColors.textSecondary,
                          ),
                        ),
                      ),

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _currentStep = 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Edit',
                                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
                              ),

                              const SizedBox(width: 6),

                              SvgPicture.asset(
                                GSWIcons.edit,
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  GSWColors.iconAccent,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Divider(height: 1, color: GSWColors.borderSecondary),

                  const SizedBox(height: 12),

                  Text(
                    trainer.fullName,
                    style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 12),

                  Divider(height: 1, color: GSWColors.borderSecondary),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildRequestSummaryItem(label: 'Goal', value: _selectedGoal ?? ''),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildRequestSummaryItem(label: 'Days', value: selectedDays),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildRequestSummaryItem(label: 'Time', value: _selectedTime ?? ''),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _buildRequestSummaryItem(
                          label: 'Where',
                          value: _selectedLocation?.name ?? '',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildRequestSummaryItem(
                          label: 'Preferred area',
                          value: _preferredAreaController.text.trim(),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _buildRequestSummaryItem(
                          label: 'Rate',
                          value: 'AED ${trainer.pricePerSession?.toInt() ?? 0}/session',
                          valueColor: GSWColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------------------------------------------------------------
            // FULL NAME
            // ---------------------------------------------------------------------
            GSWTextField(
              size: GSWTextFieldSize.large,
              controller: _nameController,
              label: 'Full name',
              hintText: 'Your name',
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 20),

            // ---------------------------------------------------------------------
            // WHATSAPP
            // ---------------------------------------------------------------------
            Text(
              'WhatsApp number',
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GSWColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GSWColors.borderDisabled),
                  ),
                  child: Text(
                    '+971',
                    style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textTertiary),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: GSWTextField(
                    size: GSWTextFieldSize.large,
                    controller: _whatsAppController,
                    hintText: '50 123 4567',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    errorText:
                        _showPhoneError && !UAEPhoneValidator.isValid(_whatsAppController.text)
                        ? 'Enter a valid UAE mobile number'
                        : null,
                    onChanged: (_) {
                      setState(() {
                        if (_showPhoneError) {
                          _showPhoneError = !UAEPhoneValidator.isValid(_whatsAppController.text);
                        }
                      });
                    },
                    onComplete: (_) {
                      setState(() {
                        _showPhoneError = !UAEPhoneValidator.isValid(_whatsAppController.text);
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ---------------------------------------------------------------------
            // OPTIONAL NOTE
            // ---------------------------------------------------------------------
            GSWTextArea(
              size: GSWTextAreaSize.large,
              controller: _notesController,
              label: 'Anything ${trainer.fullName.split(' ').first} should know?',
              hintText: 'Optional...',
              helpingText:
                  'Please do not put detailed medical information here. '
                  '${trainer.fullName.split(' ').first} will do a health screening '
                  'before your first session.',
              maxLength: 250,
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelLarge.copyWith(
              color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final trainer = widget.trainer;
    final trainerFirstName = trainer.fullName.split(' ').first;

    final stepOneComplete = _selectedGoal != null;

    final stepTwoComplete =
        _selectedDays.isNotEmpty &&
        _selectedTime != null &&
        _selectedLocation != null &&
        _preferredAreaController.text.trim().isNotEmpty;

    final stepThreeComplete =
        _nameController.text.trim().isNotEmpty &&
        UAEPhoneValidator.isValid(_whatsAppController.text) &&
        _shareDetailsConsent;

    final canContinue = switch (_currentStep) {
      1 => stepOneComplete,
      2 => stepTwoComplete,
      3 => stepThreeComplete && !_isSubmitting,
      _ => false,
    };

    return Container(
      color: GSWColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -----------------------------------------------------------------
              // STEP 3 CONSENT
              // -----------------------------------------------------------------
              if (_currentStep == 3) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: GSWCheckbox(
                        value: _shareDetailsConsent,
                        size: 24,
                        iconSize: 14,
                        onChanged: (value) {
                          setState(() {
                            _shareDetailsConsent = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'I agree to share my details with GetSetWell and '
                        '$trainerFirstName so they can respond to my request.',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],

              // -----------------------------------------------------------------
              // BACK
              // -----------------------------------------------------------------
              GSWButton(
                variant: _currentStep == 1 ? GSWButtonVariant.disabled : GSWButtonVariant.secondary,
                size: GSWButtonSize.medium,
                label: 'Back',
                onPressed: _currentStep == 1
                    ? null
                    : () {
                        setState(() {
                          _currentStep--;
                        });
                      },
              ),

              const SizedBox(height: 8),

              // -----------------------------------------------------------------
              // CONTINUE / SEND REQUEST
              // -----------------------------------------------------------------
              GSWButton(
                size: GSWButtonSize.medium,
                label: _currentStep == 3
                    ? (_isSubmitting ? 'Sending...' : 'Send Request')
                    : 'Continue',
                onPressed: !canContinue
                    ? null
                    : () {
                        if (_currentStep < 3) {
                          setState(() {
                            _currentStep++;
                          });

                          return;
                        }

                        _submitRequest();
                      },
              ),

              // -----------------------------------------------------------------
              // STEP 3 HELPER
              // -----------------------------------------------------------------
              if (_currentStep == 3) ...[
                const SizedBox(height: 12),

                Text(
                  'No account needed  •  No payment now  •  '
                  'A person replies on WhatsApp',
                  textAlign: TextAlign.center,
                  style: GSWTextStyles.labelExtraSmall.copyWith(color: GSWColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    final payload = _buildRequestPayload();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _bookingRequestService.submitTrainerRequest(payload);

      if (!mounted) return;

      final trainer = widget.trainer;

      context.go(
        GSWRoutes.bookingSuccess,
        extra: TrainerRequestSuccessData(
          requestId: result.requestId,
          referenceCode: result.referenceCode,
          trainerName: trainer.fullName,
          rate: 'AED ${trainer.pricePerSession?.toInt() ?? 0}/session',
          goal: _selectedGoal!,
          days: _formattedSelectedDays(),
          time: _selectedTime!,
          trainingLocation: _selectedLocation!.name,
          preferredArea: _preferredAreaController.text.trim(),
        ),
      );
    } on BookingRequestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Unexpected trainer request error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not send your request. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
