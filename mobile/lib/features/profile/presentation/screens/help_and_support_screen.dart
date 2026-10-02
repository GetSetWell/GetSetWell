import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _expandedIndex;

  static const String _whatsAppNumber = '971505251393';

  static const List<_HelpFaq> _faqs = [
    _HelpFaq(
      question: 'How does payment work?',
      answer:
          'You pay for your session through GetSetWell. Your booking details and payment information are confirmed before the session takes place.',
    ),
    _HelpFaq(
      question: 'What if my trainer cancels?',
      answer:
          'If your trainer cancels, we will help you reschedule or arrange the appropriate refund based on your booking.',
    ),
    _HelpFaq(
      question: 'How do you check trainers?',
      answer:
          'We review trainer information before they appear on GetSetWell, including the details and documents required for their profile and services.',
    ),
    _HelpFaq(
      question: 'Can I change my session time?',
      answer:
          'Yes. Session changes depend on trainer availability and the timing of your request. Open your booking to view the available options.',
    ),
  ];

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsAppNumber'
      '?text=${Uri.encodeComponent('Hi GetSetWell, I need some help.')}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      _showMessage('Could not open WhatsApp. Please contact +971 50 525 1393.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: GSWColors.surfaceElevated,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: GSWColors.borderPrimary),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),

                const SizedBox(height: 40),

                Text(
                  'Help & support',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 24),

                GSWButton(
                  label: 'Message us on WhatsApp',
                  onPressed: _openWhatsApp,
                  variant: GSWButtonVariant.primary,
                  size: GSWButtonSize.large,
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Support is open every day, 9:00 AM to 6:00 PM. '
                    'We reply the same day before 6:00 PM, and by 6:00 PM '
                    'the next day after that. support@getsetwell.com · '
                    '+971 50 525 1393',
                    textAlign: TextAlign.center,
                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),
                ),

                const SizedBox(height: 32),

                _buildFaqList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 30),
        ),
      ),
    );
  }

  Widget _buildFaqList() {
    return Column(
      children: [
        for (var index = 0; index < _faqs.length; index++) ...[
          _buildFaqItem(index: index, faq: _faqs[index]),

          if (index != _faqs.length - 1) const Divider(height: 1, color: GSWColors.borderSecondary),
        ],
      ],
    );
  }

  Widget _buildFaqItem({required int index, required _HelpFaq faq}) {
    final isExpanded = _expandedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                faq.question,
                style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
              ),
            ),

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  faq.answer,
                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: GSWColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpFaq {
  const _HelpFaq({required this.question, required this.answer});

  final String question;
  final String answer;
}
