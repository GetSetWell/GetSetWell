import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../../trainers/domain/models/trainer.dart';

enum TrainingOptionType { trainerGym, customerLocation }

class BookingTrainingSelection {
  const BookingTrainingSelection({
    required this.trainer,
    required this.type,
    required this.price,
    required this.locationLabel,
    this.goal,
  });

  final Trainer trainer;
  final TrainingOptionType type;
  final double price;
  final String locationLabel;
  final String? goal;
}

class BookingTrainingOptionScreen extends StatefulWidget {
  const BookingTrainingOptionScreen({super.key, required this.trainer, this.goal, this.onContinue});

  final Trainer trainer;

  /// Pass the customer's current booking goal when available.
  /// If null, the "For:" line is hidden rather than showing fake data.
  final String? goal;

  /// Lets the next booking step consume the selected option.
  ///
  /// If omitted, Continue simply returns the selection to the caller.
  final ValueChanged<BookingTrainingSelection>? onContinue;

  @override
  State<BookingTrainingOptionScreen> createState() => _BookingTrainingOptionScreenState();
}

class _BookingTrainingOptionScreenState extends State<BookingTrainingOptionScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;

  double? _gymPrice;
  String? _gymLocation;

  TrainingOptionType? _selectedOption;

  Trainer get trainer => widget.trainer;

  double get _standardPrice => trainer.pricePerSession?.toDouble() ?? 0;

  bool get _hasGymOption =>
      _gymPrice != null &&
      _gymPrice! > 0 &&
      _gymLocation != null &&
      _gymLocation!.trim().isNotEmpty;

  String get _trainerFirstName {
    final name = trainer.fullName.trim();

    if (name.isEmpty) {
      return 'trainer';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  String get _serviceLabel =>
      trainer.primaryService?.trim().isNotEmpty == true ? trainer.primaryService! : 'training';

  String get _customerLocationLabel {
    final value = trainer.serviceArea?.trim();

    if (value == null || value.isEmpty) {
      return 'Dubai';
    }

    return value;
  }

  bool get _canContinue => !_isLoading && _selectedOption != null;

  @override
  void initState() {
    super.initState();

    _loadGymOffer();
  }

  Future<void> _loadGymOffer() async {
    try {
      final row = await _client
          .from('trainers')
          .select('gym_price_per_session, gym_location_label')
          .eq('id', trainer.id)
          .maybeSingle();

      if (!mounted) return;

      final rawPrice = row?['gym_price_per_session'];

      final gymPrice = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '');

      final gymLocation = row?['gym_location_label']?.toString().trim();

      final hasGym =
          gymPrice != null && gymPrice > 0 && gymLocation != null && gymLocation.isNotEmpty;

      setState(() {
        _gymPrice = hasGym ? gymPrice : null;

        _gymLocation = hasGym ? gymLocation : null;

        // Match the design:
        // if a gym option exists, select it first.
        _selectedOption = hasGym
            ? TrainingOptionType.trainerGym
            : TrainingOptionType.customerLocation;

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Gym offer load failed: $error');

      if (!mounted) return;

      // A failure loading the optional gym offer must not
      // block the standard booking option.
      setState(() {
        _gymPrice = null;
        _gymLocation = null;
        _selectedOption = TrainingOptionType.customerLocation;
        _isLoading = false;
      });
    }
  }

  void _continue() {
    final option = _selectedOption;

    if (option == null) {
      return;
    }

    final selection = BookingTrainingSelection(
      trainer: trainer,
      type: option,
      price: option == TrainingOptionType.trainerGym ? _gymPrice! : _standardPrice,
      locationLabel: option == TrainingOptionType.trainerGym
          ? _gymLocation!
          : _customerLocationLabel,
      goal: widget.goal,
    );

    if (widget.onContinue != null) {
      widget.onContinue!(selection);
      return;
    }

    // Useful while the rest of the 4-step flow is being built.
    // The caller receives the complete selection.
    context.pop(selection);
  }

  void _close() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressHeader(),

                      const SizedBox(height: 30),

                      Text(
                        'How would you like to train?',
                        style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '${trainer.fullName}, $_serviceLabel',
                        style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                      ),

                      if (widget.goal?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 28),

                        Text(
                          'For: ${widget.goal!.trim()}',
                          style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                        ),
                      ],

                      const SizedBox(height: 28),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 72),
                          child: Center(child: CircularProgressIndicator(color: GSWColors.primary)),
                        )
                      else ...[
                        if (_hasGymOption) ...[
                          _buildOptionCard(
                            type: TrainingOptionType.trainerGym,
                            title: '60 minutes at his gym',
                            location: _gymLocation!,
                            price: _gymPrice!,
                          ),

                          const SizedBox(height: 18),
                        ],

                        _buildOptionCard(
                          type: TrainingOptionType.customerLocation,
                          title: '60 minutes at your place',
                          location: _customerLocationLabel,
                          price: _standardPrice,
                        ),

                        const SizedBox(height: 26),

                        Text(
                          'Prices are the session rate. A 5% service fee is added at checkout, and the total is shown before you pay.',
                          style: GSWTextStyles.bodyMedium.copyWith(
                            color: GSWColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if (!_isLoading) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _close,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GSWColors.borderSecondary),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, color: GSWColors.primary, size: 28),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: 0.25,
                backgroundColor: GSWColors.surfaceInteractive,
                valueColor: const AlwaysStoppedAnimation<Color>(GSWColors.primary),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        Text('1 of 4', style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary)),
      ],
    );
  }

  Widget _buildOptionCard({
    required TrainingOptionType type,
    required String title,
    required String location,
    required double price,
  }) {
    final selected = _selectedOption == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOption = type;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? GSWColors.primary : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      location,
                      style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Text(
                'AED ${_formatPrice(price)}',
                textAlign: TextAlign.right,
                style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GSWButton(
            label: 'Back to $_trainerFirstName',
            onPressed: _close,
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
          ),

          const SizedBox(height: 10),

          GSWButton(
            label: 'Continue',
            onPressed: _canContinue ? _continue : null,
            variant: _canContinue ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
            size: GSWButtonSize.large,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
