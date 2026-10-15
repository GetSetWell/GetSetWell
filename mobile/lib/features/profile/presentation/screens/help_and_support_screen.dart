import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/legal/presentation/screens/legal_document_parts.dart';
import 'package:url_launcher/url_launcher.dart';

/// 12.4 Help & support, laid out like the legal documents (12.5a): top bar,
/// title block, a contact card in place of the short version, search,
/// "All N questions / Expand all" and numbered accordion rows.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const String _whatsAppNumber = '971505251393';
  static const String _supportEmail = 'support@getsetwell.com';

  // Answers follow the current policy: 5% non-refundable service fee, session
  // rate back 24h or more before, half back inside 24h, one move per booking.
  static const List<_HelpFaq> _faqs = [
    _HelpFaq(
      question: 'How does payment work?',
      answer: [
        'You pay through GetSetWell when you book: the session rate plus a 5% service fee.',
        'The service fee is not refundable.',
      ],
    ),
    _HelpFaq(
      question: 'How do I cancel, and what do I get back?',
      answer: [
        'Open the session in Sessions and tap Cancel. The screen shows the exact refund before you confirm.',
        'Cancel 24 hours or more before the session and the session rate comes back. Inside 24 hours, half of the session rate comes back. The service fee is not refunded.',
      ],
    ),
    _HelpFaq(
      question: 'What if my trainer cancels?',
      answer: [
        'If your trainer cancels or does not turn up, you get a full refund, including the service fee.',
      ],
    ),
    _HelpFaq(
      question: 'Can I change my session time?',
      answer: [
        'You can move each booking once. It is free 24 hours or more before the session.',
        'Inside 24 hours, a move follows the late cancellation rule: you pay the kept half of the session rate again, with no second service fee.',
      ],
    ),
    _HelpFaq(
      question: 'What if one of us is running late?',
      answer: [
        'You each have 15 minutes of grace. If you need longer, message us on WhatsApp and we will help sort it out.',
      ],
    ),
    _HelpFaq(
      question: 'How do you check trainers?',
      answer: [
        'Before a trainer is listed on GetSetWell, we check their ID, qualifications and references.',
        'We check documents and references. We do not meet trainers in person.',
      ],
    ),
    _HelpFaq(
      question: 'How does Help me choose work?',
      answer: [
        'Tell us your goal, area, days and budget. A person reads every request and suggests a trainer who fits.',
        'You can have one open request at a time.',
      ],
    ),
    _HelpFaq(
      question: 'How do I delete my account?',
      answer: [
        'Go to Profile, then Delete account. If you have a booked session, cancel it first.',
        'Your account, name, mobile number and email are deleted within 30 days.',
      ],
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _expanded = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _visibleIndexes {
    final query = _searchQuery.trim().toLowerCase();
    final all = List.generate(_faqs.length, (index) => index);
    if (query.isEmpty) return all;

    return all.where((index) {
      final faq = _faqs[index];
      return [faq.question, ...faq.answer].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  bool get _allExpanded {
    final visible = _visibleIndexes;
    return visible.isNotEmpty && visible.every(_expanded.contains);
  }

  void _toggleAll() {
    final visible = _visibleIndexes;
    setState(() {
      if (_allExpanded) {
        _expanded.removeAll(visible);
      } else {
        _expanded.addAll(visible);
      }
    });
  }

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) _expanded.add(index);
    });
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsAppNumber'
      '?text=${Uri.encodeComponent('Hi GetSetWell, I need some help.')}',
    );

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Open WhatsApp failed: $error');
    }

    if (!opened) _showMessage('Could not open WhatsApp. Please contact +971 50 525 1393.');
  }

  Future<void> _openEmail() async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'mailto', path: _supportEmail));
    } catch (error) {
      debugPrint('Open email failed: $error');
    }

    if (!opened) _showMessage('Could not open your email app. Write to $_supportEmail.');
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
            borderRadius: BorderRadius.circular(GSWRadius.control),
            side: const BorderSide(color: GSWColors.borderPrimary),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visibleIndexes = _visibleIndexes;

    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const LegalDocTopBar(showArabic: false),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: kLegalContentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LegalDocTitle(
                        title: 'Help & support',
                        version: 'Every day, 9:00 AM to 6:00 PM, Dubai time',
                        intro: 'Answers to the questions we hear most, and a person on WhatsApp when you need one.',
                      ),
                      const SizedBox(height: kLegalBlockGap),
                      _buildContactCard(),
                      const SizedBox(height: kLegalBlockGap),
                      LegalSearchField(
                        controller: _searchController,
                        hintText: 'Search questions',
                        onChanged: (value) => setState(() => _searchQuery = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                      const SizedBox(height: kLegalBlockGap),
                      LegalSectionsHeader(
                        label: _searchQuery.trim().isEmpty
                            ? 'All ${_faqs.length} questions'
                            : '${visibleIndexes.length} of ${_faqs.length} questions',
                        allExpanded: _allExpanded,
                        onToggle: _toggleAll,
                      ),
                      const SizedBox(height: 4),
                      if (visibleIndexes.isEmpty)
                        _buildNoMatches()
                      else ...[
                        const LegalDivider(),
                        for (final index in visibleIndexes) ...[
                          LegalAccordionSection(
                            number: (index + 1).toString().padLeft(2, '0'),
                            title: _faqs[index].question,
                            expanded: _expanded.contains(index),
                            onTap: () => _toggle(index),
                            children: [
                              for (final paragraph in _faqs[index].answer) LegalParagraph(paragraph),
                            ],
                          ),
                          const LegalDivider(),
                        ],
                      ],
                      const SizedBox(height: kLegalBlockGap),
                      LegalReadWith(
                        links: [
                          LegalLink('Terms of Service', () => context.push(GSWRoutes.termsOfService)),
                          LegalLink(
                            'Cancellation and Refunds Policy',
                            () => context.push(GSWRoutes.cancellationAndRefund),
                          ),
                          LegalLink('Privacy Policy', () => context.push(GSWRoutes.privacyPolicy)),
                        ],
                      ),
                      const SizedBox(height: kLegalBlockGap),
                      const LegalDocFooter(
                        contactHeading: 'Still need help?',
                        contactLine: '$_supportEmail · WhatsApp +971 50 525 1393',
                        note: 'Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams).',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sits where the legal screens show "THE SHORT VERSION": same card, with
  /// the main action inside it.
  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Talk to a person',
            style: GSWTextStyles.labelLarge.copyWith(height: 20 / 16, color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'We reply the same day before 6:00 PM, and by 6:00 PM the next day after that.',
            style: GSWTextStyles.bodyMedium.copyWith(height: 20 / 14, color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'Message us on WhatsApp',
            onPressed: _openWhatsApp,
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
          ),
          const SizedBox(height: 8),
          GSWButton(
            label: 'Email $_supportEmail',
            onPressed: _openEmail,
            variant: GSWButtonVariant.tertiary,
            size: GSWButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatches() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'No matching questions.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Message us on WhatsApp and a person will answer.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _HelpFaq {
  const _HelpFaq({required this.question, required this.answer});

  final String question;
  final List<String> answer;
}
