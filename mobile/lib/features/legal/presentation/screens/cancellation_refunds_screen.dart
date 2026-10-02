import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class CancellationRefundsScreen extends StatefulWidget {
  const CancellationRefundsScreen({super.key, this.onReadArabic});

  final VoidCallback? onReadArabic;

  @override
  State<CancellationRefundsScreen> createState() => _CancellationRefundsScreenState();
}

class _CancellationRefundsScreenState extends State<CancellationRefundsScreen> {
  final TextEditingController _searchController = TextEditingController();

  final Set<int> _expandedSections = <int>{};

  bool _workedExamplesExpanded = false;

  String _searchQuery = '';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '01',
      title: 'When this policy applies',
      paragraphs: [
        '1.1  This policy applies from the moment your booking is confirmed, which is when your payment has succeeded. Before that, you can withdraw a request at any time and nothing is owed.',
        '1.2  It applies only to sessions booked and paid through GetSetWell. Sessions you arrange directly with a trainer are not covered (section 13).',
      ],
    ),
    _LegalSection(
      number: '02',
      title: 'How the price is made up',
      paragraphs: ['2.1  Every booking has two parts, always shown separately:'],
      bullets: [
        'the session rate, set by the trainer',
        'our service fee, which is 5% of the session rate',
      ],
      trailingParagraphs: [
        'The total is the two added together: AED 280 plus AED 14 is AED 294. It includes any VAT that applies.',
        '2.2  The service fee pays for our work in finding or checking your trainer and in arranging and managing your booking. That work is done once your booking is confirmed. So the service fee is not refunded when you cancel, reschedule less than 24 hours before, or do not turn up. It is refunded in full if your trainer cancels or does not turn up, if we cancel, or if an event outside anyone\'s control stops the session.',
        '2.3  Wherever this policy says you get everything you paid back, that does not include any part of the session rate already kept under section 5.3 because you rescheduled less than 24 hours before.',
      ],
    ),
    _LegalSection(
      number: '03',
      title: 'Timing rules',
      paragraphs: [
        '3.1  All times are Dubai time.',
        '3.2  Notice is measured from the moment we receive your cancellation or reschedule to the scheduled start time of the session.',
        '3.3  Exactly 24 hours counts as 24 hours or more.',
        '3.4  Cancel or reschedule in the app. If you cannot, message us on WhatsApp at +971 50 525 1393. The time we receive your message is the time that counts, even outside our support hours.',
      ],
    ),
    _LegalSection(
      number: '04',
      title: 'If you cancel',
      cards: [
        _PolicyCard(
          title: '24 hours or more before',
          lines: [
            'You get back:  The session rate. AED 280',
            'Your trainer receives:  Nothing',
            'We keep:  The service fee. AED 14',
          ],
        ),
        _PolicyCard(
          title: 'Less than 24 hours before',
          lines: [
            'You get back:  Half the session rate. AED 140',
            'Your trainer receives:  Half the session rate, less our 5% of that half. AED 133',
            'We keep:  The service fee and our 5%. AED 21',
          ],
        ),
        _PolicyCard(
          title: 'You do not turn up',
          lines: [
            'You get back:  Nothing',
            'Your trainer receives:  The session rate, less our commission of at least 10%. AED 210 to AED 252, depending on the trainer\'s plan',
            'We keep:  The service fee and our commission. AED 42 to AED 84',
          ],
        ),
      ],
      trailingParagraphs: [
        '4.1  Before you confirm a cancellation, the app shows you exactly what you will get back, in dirhams.',
        '4.2  Why we keep part of the price when you cancel late. A trainer who has held a time for you can rarely fill it at short notice. The part of the session rate that is kept compensates your trainer for that.',
      ],
    ),
    _LegalSection(
      number: '05',
      title: 'Rescheduling',
      paragraphs: [
        '5.1  Each booking can be rescheduled once.',
        '5.2  24 hours or more before the session. Rescheduling is free. The booking moves to the new time.',
        '5.3  Less than 24 hours before the session. Rescheduling is treated like a late cancellation. Half the session rate (AED 140) is kept and paid to your trainer, less our 5%. The other half stays on your booking. To confirm the new time, you pay the half that was kept (AED 140). The service fee is not charged again.',
        '5.4  You choose the new time when you reschedule. It must be with the same trainer, at a time they have available, and within 30 days of the original session.',
        '5.5  Once a booking has been rescheduled, it cannot be rescheduled again. You can still cancel it under section 4, measured from the new time.',
        '5.6  If your trainer asks to move a session, section 7.3 applies. A session moved under section 7, 8.2 or 9 does not use up your reschedule.',
      ],
    ),
    _LegalSection(
      number: '06',
      title: 'Lateness',
      paragraphs: [
        '6.1  You and your trainer each have 15 minutes\' grace after the scheduled start time. Arriving exactly 15 minutes after the start time counts as within it.',
        '6.2  If you are running late, tell your trainer and us as soon as you can.',
        '6.3  If you arrive late, the session still ends at its scheduled time.',
        '6.4  If you have not arrived 15 minutes after the start time, your trainer may leave, after trying to contact you and letting us know. This is treated as you not turning up. If you arrive later than that and your trainer agrees to go ahead, it is treated as a normal session, and it still ends at its scheduled time.',
        '6.5  If your trainer arrives late but within 15 minutes, the session goes ahead and your trainer makes up the lost time. If you can\'t stay longer, the missed minutes are added to your next session with them, or, if you have no next session booked, we refund them as a share of the session rate. For example, 14 minutes of a AED 280 session is AED 65.33.',
        '6.6  If your trainer has not arrived 15 minutes after the start time, you may leave. Please tell us straight away. This is treated as your trainer not turning up, and section 7 applies. If you choose to wait and train anyway, it is treated as a normal session.',
      ],
    ),
    _LegalSection(
      number: '07',
      title: 'If your trainer cancels, asks to move, or does not turn up',
      paragraphs: [
        '7.1  If your trainer lets you down, whenever it happens and however much notice they give, you choose one of these:',
      ],
      bullets: [
        'a full refund of everything you paid for the booking, including the service fee. AED 294. If you had already rescheduled it less than 24 hours before the original time, the half of the session rate kept then is not refunded.',
        'a new time with the same trainer, at no extra cost',
        'another trainer. We will prioritise finding you one. If the trainer you choose charges more, we pay the difference, up to AED 75. We tell you any amount above that before you book, and you pay it only if you agree. If they charge less, we refund you the difference.',
      ],
      trailingParagraphs: [
        '7.2  Your trainer receives nothing for that booking. Repeated cancellations by a trainer are handled under our trainer reliability process.',
        '7.3  If your trainer asks to move a session, we ask you first. You can accept the new time, or refuse it and choose any option in section 7.1.',
        '7.4  What we do when it happens:',
      ],
      trailingBullets: [
        '24 hours or more before your session: we tell you straight away and help you choose.',
        'Less than 24 hours before your session: we contact you first, and try to find another trainer for the same time.',
        'If your trainer does not turn up: as soon as we know, we contact you to apologise and sort it out. We do this within an hour of being told, or, if we are told outside our support hours, within an hour of them starting.',
      ],
    ),
    _LegalSection(
      number: '08',
      title: 'If we cancel, or something outside anyone\'s control stops the session',
      paragraphs: [
        '8.1  If we cancel your booking, for example because a trainer\'s listing is suspended, you are refunded everything you paid, including the service fee, and we offer to find you another trainer. If we cannot, the refund stands and nothing further is owed.',
        '8.2  If an event outside anyone\'s control stops a session from taking place, for example an official severe weather warning or a government restriction, you can choose a full refund of everything you paid, including the service fee, or a new time with the same trainer. Your trainer receives nothing for the original time. We decide, reasonably, whether an event is outside anyone\'s control.',
      ],
    ),
    _LegalSection(
      number: '09',
      title: 'If something serious and unforeseeable happens',
      paragraphs: [
        '9.1  If something serious and unforeseeable stops you attending, for example a medical emergency or a bereavement, tell us as soon as you can.',
        '9.2  We will consider it, and may, at our discretion, move your session to a new time without applying sections 4 to 6. If we do, your trainer still receives half the session rate for the missed time, and we pay it, not you.',
        '9.3  This is goodwill, decided case by case. It does not change the rules in sections 4 to 6. We will not normally ask for documents.',
      ],
    ),
    _LegalSection(
      number: '10',
      title: 'Confirming a session, and disagreements about attendance',
      paragraphs: [
        '10.1  After each session we ask you and your trainer whether it took place.',
        '10.2  Either of you can tell us, within 24 hours after the scheduled end time, that the session did not take place or that something went wrong.',
        '10.3  If neither of you does, the session is treated as completed and your trainer is paid. This only decides when your trainer is paid. You can still tell us later about an injury or a problem with the session, and your rights under UAE law are not affected.',
        '10.4  If you tell us your trainer did not turn up, we tell your trainer. If they do not dispute it within 12 hours, you are refunded under section 7.',
        '10.5  If your trainer tells us you did not turn up, we tell you. If you disagree, tell us within 24 hours of our message. If you do not reply, we decide on the information we have, within 24 hours after that.',
        '10.6  If you disagree with each other, we decide. We give our decision within 24 hours of the disagreement being raised, and explain it to you both.',
        '10.7  How we decide. We look at what each of you tells us, messages between you, your trainer and us, call records, and anything else either of you gives us, such as photographs. Decisions are made by the Manager of Get Set Fit LLC, or by a person the Manager appoints.',
        '10.8  Your trainer is not paid while we look into it.',
        '10.9  Our decision settles how the booking is treated on GetSetWell. It does not affect your rights under UAE law, including your right to complain under section 12 of our Terms of Service.',
      ],
    ),
    _LegalSection(
      number: '11',
      title: 'How refunds are paid',
      paragraphs: [
        '11.1  Refunds are paid to the payment method you used. We do not refund in cash, to a different card or account, or as account credit.',
        '11.2  When you cancel, your refund is started straight away. When we have looked into a report, it is started when we decide.',
        '11.3  Refunds are processed by our payment provider. They usually take 5 to 10 working days to reach you, depending on your bank.',
        '11.4  A receipt for every refund is available in the app.',
      ],
    ),
    _LegalSection(
      number: '12',
      title: 'If a session took place but went wrong',
      paragraphs: [
        '12.1  If your session went ahead but was not delivered as booked because of your trainer, for example it was much shorter than booked, tell us. If you tell us within 24 hours after the scheduled end time, we ask our payment provider to hold your trainer\'s payment while we look into it. You can still tell us after that.',
        '12.2  We look into it with you and your trainer, and tell you what we decide and why. If the session was not delivered as booked because of your trainer, you choose either a free repeat of the session, or a refund of the session rate or of the part of it that reflects what was not delivered.',
        '12.3  This does not affect your rights under UAE consumer protection law, including your right to complain to the authorities.',
      ],
    ),
    _LegalSection(
      number: '13',
      title: 'Sessions arranged outside GetSetWell',
      paragraphs: [
        '13.1  This policy does not cover sessions you arrange directly with a trainer. We cannot help with payment, cancellations, refunds or disputes for them. Booking through GetSetWell is what protects you if your trainer cancels or does not turn up.',
      ],
    ),
    _LegalSection(
      number: '14',
      title: 'Packages',
      paragraphs: [
        '14.1  We do not currently sell packages or bundles of sessions. If we do, their cancellation terms will be published before they go on sale, and will not change the terms of sessions already bought.',
      ],
    ),
    _LegalSection(
      number: '15',
      title: 'Your rights under UAE law',
      paragraphs: [
        '15.1  Nothing in this policy affects your rights under Federal Law 15 of 2020 on Consumer Protection and its Executive Regulations, or under Federal Decree-Law 14 of 2023 on Trading by Modern Technological Means.',
      ],
    ),
    _LegalSection(
      number: '16',
      title: 'Contact',
      paragraphs: [
        'Email support@getsetwell.com · WhatsApp +971 50 525 1393 · in the app, under Help.',
        'You can message us at any time. Our support hours are 9:00 am to 6:00 pm Dubai time, every day. We reply the same day to messages received before 6:00 pm, and by 6:00 pm the next day to messages received after 6:00 pm.',
      ],
    ),
    _LegalSection(
      number: '17',
      title: 'Language',
      paragraphs: [
        '17.1  This policy is published in Arabic and English. For clients, if the two versions differ, the Arabic version applies. For trainers, the language clause in the Trainer Agreement applies.',
      ],
    ),
    _LegalSection(
      number: '18',
      title: 'How sessions are delivered',
      paragraphs: [
        '18.1  What you book through GetSetWell is a 60-minute session with the trainer you chose, in person, at the date, time and place in your booking. Nothing is shipped.',
        '18.2  Your booking is confirmed when your payment succeeds. We confirm it in the app and by WhatsApp, and remind you before the session.',
        '18.3  Your trainer delivers the session. We arrange the booking, take payment through our payment provider, and handle changes, refunds and complaints.',
        '18.4  A session counts as delivered 24 hours after its scheduled end, unless you or your trainer report a problem under section 10. If it did not go ahead, or was not delivered as booked, sections 7, 10 and 12 apply.',
      ],
    ),
  ];

  static const List<String> _workedExamples = [
    '1. You cancel on Thursday for a Saturday session. You get AED 280 back. The service fee is not refunded.',
    '2. You cancel on Saturday morning for a Saturday afternoon session. You get AED 140 back. Your trainer receives AED 133 for holding the time.',
    '3. You do not turn up. Nothing is refunded. Your trainer receives between AED 210 and AED 252, depending on their plan.',
    '4. On Thursday, you move a Saturday session to the following Tuesday. No charge. You cannot move it again, but you can still cancel it.',
    '5. On Saturday morning, you move a Saturday afternoon session to Tuesday. You pay AED 140 to confirm Tuesday. Your trainer receives AED 133 for the Saturday time.',
    '6. You arrive 10 minutes late. The session goes ahead and ends at the scheduled time.',
    '7. Your trainer has not arrived 15 minutes after the start time. You can leave. You get AED 294 back, or a new time with the same trainer, or another trainer.',
    '8. Your trainer cancels on Friday for Saturday, and you choose another trainer who charges AED 330. Their total would be AED 346.50. You pay nothing more. We pay the AED 52.50 difference.',
    '9. Your trainer cancels, and the replacement you choose charges AED 400. Their total would be AED 420. The difference is AED 126. We pay AED 75, and we tell you about the remaining AED 51 before you book. You pay it only if you agree, or you can take the full AED 294 refund instead.',
    '10. Your trainer arrives 14 minutes late and you can\'t stay longer. The missed 14 minutes are added to your next session with them or, if you have none booked, you get AED 65.33 back.',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _allExpanded => _expandedSections.length == _sections.length;

  List<int> get _visibleIndexes {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return List.generate(_sections.length, (index) => index);
    }

    final matches = <int>[];

    for (var index = 0; index < _sections.length; index++) {
      final section = _sections[index];

      final searchableText = [
        section.number,
        section.title,
        ...section.paragraphs,
        ...section.bullets,
        ...section.trailingParagraphs,
        ...section.trailingBullets,
        ...section.cards.expand((card) => [card.title, ...card.lines]),
      ].join(' ').toLowerCase();

      if (searchableText.contains(query)) {
        matches.add(index);
      }
    }

    return matches;
  }

  bool get _workedExamplesMatch {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    return [
      'Worked examples',
      'For a session rate of AED 280, service fee AED 14, total AED 294.',
      ..._workedExamples,
    ].join(' ').toLowerCase().contains(query);
  }

  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expandedSections.clear();
        _workedExamplesExpanded = false;
      } else {
        _expandedSections
          ..clear()
          ..addAll(List.generate(_sections.length, (index) => index));

        _workedExamplesExpanded = true;
      }
    });
  }

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  void _handleReadArabic() {
    if (widget.onReadArabic != null) {
      widget.onReadArabic!();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Arabic version will be available here.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: GSWColors.surfaceElevated,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: GSWColors.borderSecondary),
          ),
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
            _buildTopBar(context),

            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancellation and Refunds',
                        style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Version 1.2 · 28 September 2026',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'This policy forms part of our Terms of Service and of the Trainer Agreement. Where it differs from the Terms on a cancellation, reschedule, late arrival, missed session or refund, this policy applies.',
                        style: GSWTextStyles.bodyMedium.copyWith(
                          color: GSWColors.textSecondary,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Every example uses the same booking: a session rate of AED 280, a service fee of AED 14, and a total of AED 294.',
                        style: GSWTextStyles.bodyMedium.copyWith(
                          color: GSWColors.textSecondary,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildShortVersionCard(),

                      const SizedBox(height: 24),

                      _buildSearchField(),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Text(
                            _allExpanded
                                ? 'All 18 sections, expanded'
                                : '${_expandedSections.length} of 18 sections expanded',
                            style: GSWTextStyles.labelMedium.copyWith(
                              color: GSWColors.textSecondary,
                            ),
                          ),

                          const Spacer(),

                          GestureDetector(
                            onTap: _toggleAll,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _allExpanded ? 'Collapse all' : 'Expand all',
                                style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (visibleIndexes.isEmpty && !_workedExamplesMatch)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              'No matching sections.',
                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: GSWColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        for (final index in visibleIndexes) ...[
                          _buildSection(index, _sections[index]),
                          const Divider(height: 1, color: GSWColors.borderSecondary),
                        ],

                        if (_workedExamplesMatch) _buildWorkedExamples(),
                      ],
                      const SizedBox(height: 32),

                      _buildFooter(),
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

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildBackButton(context),

            const Spacer(),

            TextButton(
              onPressed: _handleReadArabic,
              style: TextButton.styleFrom(
                foregroundColor: GSWColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Read in Arabic',
                style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortVersionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE SHORT VERSION',
            style: GSWTextStyles.labelSmall.copyWith(
              color: GSWColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          _summaryItem(
            'Cancel 24 hours or more before and you get the session rate back. The 5% service fee is kept.',
          ),

          _summaryItem(
            'Cancel less than 24 hours before and you get half the session rate back. If you don\'t turn up, nothing is refunded.',
          ),

          _summaryItem(
            'You can move a booking once. It\'s free 24 hours or more before. Later than that, you pay half the rate again to confirm the new time.',
          ),

          _summaryItem('You and your trainer each have 15 minutes\' grace.'),

          _summaryItem(
            'If your trainer cancels or doesn\'t turn up: a full refund, a new time, or another trainer, with up to AED 75 of any price difference covered.',
          ),

          _summaryItem(
            'Refunds go back to the card you paid with, usually in 5 to 10 working days.',
          ),

          const SizedBox(height: 8),

          Text(
            'A summary to help you. The full policy below is what applies.',
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              text,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: GSWColors.primary,
        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search the policy',
          hintStyle: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: GSWColors.textSecondary, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close_rounded, color: GSWColors.textSecondary, size: 18),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildSection(int index, _LegalSection section) {
    final expanded = _expandedSections.contains(index);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSection(index),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    section.number,
                    style: GSWTextStyles.titleSmall.copyWith(
                      color: GSWColors.primary,
                      fontFamily: 'BebasNeue',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      section.title,
                      style: GSWTextStyles.labelLarge.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  expanded ? Icons.remove_rounded : Icons.add_rounded,
                  size: 20,
                  color: GSWColors.textSecondary,
                ),
              ],
            ),
          ),

          if (expanded) ...[
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final paragraph in section.paragraphs) _paragraph(paragraph),

                  for (final bullet in section.bullets) _bullet(bullet),

                  for (final card in section.cards) _policyCard(card),

                  for (final paragraph in section.trailingParagraphs) _paragraph(paragraph),

                  for (final bullet in section.trailingBullets) _bullet(bullet),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
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

  Widget _policyCard(_PolicyCard card) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: GSWTextStyles.labelMedium.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          for (var index = 0; index < card.lines.length; index++) ...[
            Text(
              card.lines[index],
              style: GSWTextStyles.bodyMedium.copyWith(
                color: GSWColors.textSecondary,
                height: 1.45,
              ),
            ),

            if (index != card.lines.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkedExamples() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _workedExamplesExpanded = !_workedExamplesExpanded;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 28),

                const SizedBox(width: 8),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Worked examples',
                      style: GSWTextStyles.labelLarge.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  _workedExamplesExpanded ? Icons.remove_rounded : Icons.add_rounded,
                  size: 20,
                  color: GSWColors.textSecondary,
                ),
              ],
            ),
          ),

          if (_workedExamplesExpanded) ...[
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paragraph('For a session rate of AED 280, service fee AED 14, total AED 294.'),

                  for (final example in _workedExamples) _paragraph(example),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: GSWColors.textSecondary, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerDivider() {
    return const Divider(height: 1, color: GSWColors.borderSecondary);
  }

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READ WITH THESE',
          style: GSWTextStyles.labelMedium.copyWith(
            color: GSWColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 16),

        _buildFooterLink(
          label: 'Terms of Service',
          onTap: () {
            context.push(GSWRoutes.termsOfService);
          },
        ),

        _footerDivider(),

        _buildFooterLink(
          label: 'Privacy Policy',
          onTap: () {
            context.push(GSWRoutes.privacyPolicy);
          },
        ),

        _footerDivider(),

        _buildFooterLink(
          label: 'Prohibited Services Policy',
          onTap: () {
            context.push(GSWRoutes.prohibitedServices);
          },
        ),

        _footerDivider(),

        const SizedBox(height: 24),

        Text(
          'Questions about a cancellation or refund?',
          style: GSWTextStyles.labelLarge.copyWith(
            color: GSWColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'info@getsetwell.com · WhatsApp +971 50 525 1393',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.primary),
        ),

        const SizedBox(height: 24),

        Text(
          'Published in Arabic and English. For clients, if the two differ, the Arabic version applies. Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams).',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.number,
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
    this.trailingParagraphs = const [],
    this.trailingBullets = const [],
    this.cards = const [],
  });

  final String number;
  final String title;

  final List<String> paragraphs;
  final List<String> bullets;

  final List<String> trailingParagraphs;
  final List<String> trailingBullets;

  final List<_PolicyCard> cards;
}

class _PolicyCard {
  const _PolicyCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}
