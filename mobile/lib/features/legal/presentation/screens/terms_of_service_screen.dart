import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key, this.onReadArabic});

  final VoidCallback? onReadArabic;

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  final TextEditingController _searchController = TextEditingController();

  final Set<int> _expandedSections = <int>{};

  String _searchQuery = '';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '01',
      title: 'Who we are and what these terms cover',
      paragraphs: [
        '1.1  GetSetWell is operated by Get Set Fit LLC, a limited liability company licensed by Sharjah Media City (Shams) under licence number 2541939, with its registered address at Sharjah Media City (Shams), Sharjah, United Arab Emirates ("GetSetWell", "we", "us", "our").',
        '1.2  You can contact us by email at support@getsetwell.com, on WhatsApp at +971 50 525 1393, or through getsetwell.com.',
        '1.3  "You" means the person using our website or app.',
        '1.4  These terms apply when you use getsetwell.com or the GetSetWell app, create an account, send a request, book or pay for a session, or contact us.',
        '1.5  These terms, together with the following documents, form the agreement between you and us:',
      ],
      bullets: [
        'our Privacy Policy',
        'our Cancellation and Refunds Policy',
        'our Prohibited Services Policy',
      ],
      trailingParagraphs: [
        'If these terms and the Cancellation and Refunds Policy say different things about a cancellation, reschedule, late arrival, missed session or refund, the Cancellation and Refunds Policy applies.',
        '1.6  You accept these terms when you create an account, by confirming that you have read and accept them.',
      ],
    ),
    _LegalSection(
      number: '02',
      title: 'What GetSetWell is, and what it is not',
      paragraphs: [
        '2.1  GetSetWell introduces people looking for fitness coaching to independent trainers in Dubai, and lets you book and pay for sessions with them in one place.',
        '2.2  Trainers are independent professionals. We require every trainer to hold their own UAE trade licence or freelance permit, and we check it before they are listed. Trainers provide coaching on their own account. They are not our employees, agents or partners. We do not provide fitness, medical, nutritional or therapeutic services ourselves, and we do not supervise or direct how a trainer delivers a session.',
        '2.3  Your coaching agreement is with the trainer. We find or check the trainer, arrange and manage your booking, handle the scheduling, arrange for your payment to be processed, and help if something goes wrong. We are not a party to the coaching itself.',
        '2.4  We do not hold your money. Your payment is collected, held and settled by a payment service provider licensed by the Central Bank of the UAE. It is held by that provider, not by Get Set Fit LLC, and the trainer\'s share is paid to the trainer by that provider.',
        '2.5  How we are paid. We are paid in two ways, and we tell you about both:',
        '(a) a service fee of 5% of the trainer\'s session rate, which you pay and which is always shown separately on your booking; and',
        '(b) payments from trainers: a commission on sessions with clients we introduced to them, and, for trainers who choose it, a monthly plan fee.',
        '2.6  What that means for our recommendations. The commission a trainer pays us depends on the plan that trainer has chosen and on how long they have been working with you, so it is not the same for every trainer or every session. It does not decide who we recommend. We recommend trainers based on what you have told us and on each trainer\'s experience, specialisms, location, availability and price. No trainer can pay to be recommended to you or to appear higher in our listings.',
      ],
    ),
    _LegalSection(
      number: '03',
      title: 'Your account',
      paragraphs: [
        '3.1  You must be 18 or over to create an account or book a session. We do not arrange sessions for anyone under 18. We do not ask for your date of birth. You confirm your age when you create your account.',
        '3.2  We verify your mobile number with a one-time code sent by WhatsApp, so you need WhatsApp to use GetSetWell. Keep your phone and your codes secure. You are responsible for bookings made from your account.',
        '3.3  You can only book sessions for yourself. Anyone else who wants to train needs their own account.',
        '3.4  You can close your account in the app at any time. Any future booking must be cancelled first, under the Cancellation and Refunds Policy.',
      ],
    ),
    _LegalSection(
      number: '04',
      title: 'Requests and bookings',
      paragraphs: [
        '4.1  Asking us to match you. Tell us your goal, when and where you would like to train, any preferences you have, and your budget per session. A member of our team reads every request and recommends a trainer, and tells you why. You decide whether to book. There is no obligation.',
        '4.2  Choosing a trainer yourself. You can browse trainer profiles and book a trainer directly.',
        '4.3  Open requests. You can have up to two open requests at a time.',
        '4.4  When a booking is confirmed. A booking is confirmed when your payment has succeeded, and the app then shows it as confirmed. A request, a recommendation or a message from a trainer is not a booking.',
        '4.5  Sessions are 60 minutes, in Dubai, at the location shown on your booking.',
        '4.6  We cannot promise that a suitable trainer will be available for every request, or at every time you would like.',
      ],
    ),
    _LegalSection(
      number: '05',
      title: 'What our review of a trainer means',
      paragraphs: [
        '5.1  Before a trainer is listed on GetSetWell, we carry out a review.',
        'For every trainer, we:',
      ],
      bullets: [
        'check a government issued identity document against the name and details on the profile',
        'check that the trainer holds their own UAE trade licence or freelance permit, and record its number and expiry date',
        'record each qualification\'s name, the organisation that issued it, its status and dates, and check it against an official register or with the issuing organisation where one is available',
        'take two professional references',
        'have a conversation with the trainer, in person or by video',
        'agree our conduct standards, and record the trainer\'s pricing, areas and availability',
        'confirm the trainer\'s insurance before their first paid session',
      ],
      trailingParagraphs: ['Where relevant, we also:'],
      trailingBullets: [
        'record first aid or CPR documentation where the trainer holds it',
        'require a current lifesaving qualification for swimming',
        'check education and experience relevant to any specialist service the trainer offers',
        'confirm Dubai Sports Council registration for trainers who coach at a gym or other sports facility',
      ],
      finalParagraphs: [
        '5.2  Each trainer\'s profile shows what was checked for that trainer, and what was not.',
        '5.3  What our review does not do. It does not guarantee a result. It does not replace medical advice or clearance. It is not a promise that a trainer is safe, competent, or right for you personally, and it is not an endorsement of a trainer\'s professional judgement. It reduces the uncertainty. It does not remove it. Your choice of trainer remains yours.',
      ],
    ),
    _LegalSection(
      number: '06',
      title: 'Prices, payment and receipts',
      paragraphs: ['6.1  The trainer sets their session rate. Every booking shows:'],
      bullets: [
        'the trainer\'s session rate',
        'our service fee, which is 5% of the session rate',
        'the total, which is the amount you pay',
      ],
      trailingParagraphs: [
        '6.2  The total is the full price. It includes any VAT that applies. We will not add any charge that was not shown to you before you paid. If a trainer charges for anything outside the booking, for example entry to a gym paid at the venue, it is shown on the trainer\'s profile and on the booking before you pay.',
        '6.3  Payment. You pay the total when you book, through our payment service provider. Your card details go directly to the provider. We do not collect or store them.',
        '6.4  Receipts. A dated receipt for every payment and every refund is available in the app. It shows the trainer, the session, the session rate, the service fee and the total.',
        '6.5  What the service fee pays for. The service fee pays for our work in finding or checking your trainer and in arranging and managing your booking. It is the same however you pay, and it is not a charge for using a payment method. That work is done once your booking is confirmed, so the service fee is not refunded if you cancel, reschedule less than 24 hours before, or do not turn up. It is refunded in full if your trainer cancels or does not turn up, if we cancel your booking, or if an event outside anyone\'s control stops the session.',
      ],
    ),
    _LegalSection(
      number: '07',
      title: 'Cancellations, rescheduling, lateness and refunds',
      paragraphs: [
        '7.1  These are set out in full in the Cancellation and Refunds Policy. In summary:',
      ],
      bullets: [
        'You cancel 24 hours or more before the session — You get the session rate back. The service fee is not refunded.',
        'You cancel less than 24 hours before the session — You get half the session rate back. The service fee is not refunded.',
        'You reschedule 24 hours or more before the session — No charge.',
        'You reschedule less than 24 hours before the session — Treated like a late cancellation. Half the session rate is kept, and you pay that half again to confirm the new time.',
        'You do not turn up — Nothing is refunded.',
        'Your trainer cancels, at any time, or does not turn up — You get everything back, including the service fee. Or, if you prefer, a new time with the same trainer, or another trainer.',
        'We cancel your booking — You get everything back, including the service fee.',
      ],
      trailingParagraphs: [
        '7.2  Rescheduling. Each booking can be rescheduled once.',
        '7.3  Lateness. You and your trainer each have 15 minutes\' grace, and arriving exactly 15 minutes after the start time counts as within it. If your trainer arrives late within the grace period, they make up the lost time. If you can\'t stay longer, the missed minutes are added to your next session with them, or refunded if you have none booked. If your trainer has not arrived by the end of the grace period, it counts as your trainer not turning up. If you have not arrived by then, your trainer may leave, and it counts as you not turning up.',
        '7.4  How refunds are paid. Refunds are paid to the payment method you used. We do not give cash refunds or account credit.',
        '7.5  How to cancel or reschedule. Use the app. If you cannot, message us on WhatsApp. The time we receive your message is the time that counts.',
        '7.6  What "everything back" means. Wherever these terms say you get everything back, that does not include any part of the session rate already kept because you rescheduled less than 24 hours before.',
      ],
    ),
    _LegalSection(
      number: '08',
      title: 'After your session',
      paragraphs: [
        '8.1  After each session we ask you, and your trainer, whether it took place.',
        '8.2  If neither of you tells us within 24 hours after the scheduled end of the session that it did not take place, it is treated as completed and your trainer is paid. This only decides when your trainer is paid. It is not a deadline for complaints: you can still tell us later about an injury or a problem with a session, and your rights under UAE law are not affected.',
        '8.3  If you tell us within that time that the session did not take place, we ask your trainer for their account, which they must give us within 12 hours. If they do not dispute your report, you are refunded. If they do, we decide within 24 hours of hearing from them, and explain our decision. Your trainer is not paid while we look into it.',
        '8.4  If your trainer tells us that you did not turn up and you disagree, tell us within 24 hours of our message to you.',
        '8.5  The full process is in the Cancellation and Refunds Policy.',
        '8.6  We may also ask how your session went. Answering is optional.',
      ],
    ),
    _LegalSection(
      number: '09',
      title: 'Sessions arranged outside GetSetWell',
      paragraphs: [
        '9.1  Our protections apply only to sessions booked and paid through GetSetWell. They include refunds under the Cancellation and Refunds Policy, a full refund if your trainer cancels or does not turn up, help finding another trainer, and help resolving a dispute.',
        '9.2  If you arrange a session directly with a trainer, outside the GetSetWell app, that session is between you and the trainer. We cannot help with payment, cancellations, refunds or disputes for it.',
        '9.3  Trainers pay us commission on sessions with clients we introduced to them, including sessions arranged directly. This does not change anything you pay. We may occasionally ask whether you have trained with a trainer we introduced you to. Answering is optional.',
      ],
    ),
    _LegalSection(
      number: '10',
      title: 'Health and safety',
      paragraphs: [
        '10.1  Exercise carries risk. Speak to a doctor before you start or return to training, especially if you have an injury or a health condition, are pregnant or have recently given birth, or have not exercised for a long time.',
        '10.2  We ask only what we need to match you. We do not ask about your health, and you should not include health details in a request or a message to us.',
        '10.3  Tell your trainer directly, before your first session, about anything that affects how you should train. Your trainer may ask you health questions before you start. They do so as an independent professional.',
        '10.4  Trainers on GetSetWell provide fitness coaching. They do not provide medical care. Our Prohibited Services Policy explains what trainers may and may not offer.',
        '10.5  Follow your trainer\'s safety instructions. Stop and tell them straight away if you feel unwell. In an emergency, call 998 for an ambulance or 999 for the police.',
      ],
    ),
    _LegalSection(
      number: '11',
      title: 'Your responsibilities',
      paragraphs: ['11.1  You agree to:'],
      bullets: [
        'give us accurate information',
        'treat trainers and our team with respect',
        'turn up to sessions you have booked, on time, or cancel or reschedule in good time',
        'make sure that any place you choose for a session, including your home, is safe and suitable for exercise',
        'use GetSetWell only to find and book fitness coaching',
        'tell us if a trainer offers you something that sounds like medical treatment, or tries to sell you supplements or other products',
      ],
    ),
    _LegalSection(
      number: '12',
      title: 'Help and complaints',
      paragraphs: ['12.1  For help with a booking, or to make a complaint, contact us:'],
      bullets: [
        'by email at support@getsetwell.com',
        'on WhatsApp at +971 50 525 1393',
        'in the app, under Help, or by reporting a booking',
      ],
      trailingParagraphs: [
        '12.2  You can message us at any time. Our support hours are 9:00 am to 6:00 pm Dubai time, every day. We reply the same day to messages received before 6:00 pm, and by 6:00 pm the next day to messages received after 6:00 pm.',
        '12.3  How we handle a complaint. We acknowledge it, look into it, speak to the trainer where relevant, and tell you what we found and what we are doing about it. We aim to resolve complaints within 5 business days, and will tell you if it will take longer.',
        '12.4  If you are not satisfied with how we have handled your complaint, you can refer it to the Department of Economy and Tourism in Dubai, or to the Ministry of Economy and Tourism.',
      ],
    ),
    _LegalSection(
      number: '13',
      title: 'Our responsibility to you',
      paragraphs: [
        '13.1  We will provide our service with reasonable care and skill.',
        '13.2  Each trainer is responsible for the sessions they deliver. We are not responsible for what a trainer does or fails to do during a session, unless we are at fault ourselves, for example if we misstated what we checked about that trainer.',
        '13.3  We are not responsible for indirect loss, or for loss of profit, business or opportunity.',
        '13.4  Nothing in these terms limits or excludes:',
      ],
      bullets: [
        'liability for death or personal injury caused by our negligence',
        'liability for fraud',
        'your rights as a consumer under UAE law',
        'anything else that UAE law does not allow us to limit or exclude',
      ],
    ),
    _LegalSection(
      number: '14',
      title: 'Loss you cause us',
      paragraphs: [
        '14.1  If you break these terms, or give us information you know is false, and that causes us loss, you are responsible for that loss to the extent UAE law allows.',
      ],
    ),
    _LegalSection(
      number: '15',
      title: 'Our content',
      paragraphs: [
        '15.1  The GetSetWell name, logo, app, website, content and design belong to Get Set Fit LLC. Trainer photographs and biographies are used with the trainer\'s permission. You may not copy, scrape or reuse any of it without our written permission.',
      ],
    ),
    _LegalSection(
      number: '16',
      title: 'Suspending or closing your account',
      paragraphs: [
        '16.1  We may suspend or close your account, or cancel a booking, if you seriously or repeatedly break these terms, behave abusively towards a trainer or our team, or give us information you know is false. We will tell you why, unless the law or someone\'s safety prevents us.',
        '16.2  If we cancel a confirmed booking for any reason, you are refunded everything you paid, including the service fee.',
      ],
    ),
    _LegalSection(
      number: '17',
      title: 'Changes to these terms',
      paragraphs: [
        '17.1  We may update these terms from time to time. We will tell you at least 14 days before a change takes effect, in the app or by WhatsApp. A change required by law, or one that only benefits you, may take effect sooner.',
        '17.2  A change never applies to a booking you have already made. That booking stays on the terms that applied when you made it.',
        '17.3  If you do not accept a change, you can stop using GetSetWell and close your account.',
        '17.4  The current version is always available at https://getsetwell.com/terms.html, with its version number and date.',
      ],
    ),
    _LegalSection(
      number: '18',
      title: 'Events outside anyone\'s control',
      paragraphs: [
        '18.1  Neither of us is responsible for a failure or delay caused by an event beyond reasonable control, such as natural disaster, extreme weather, epidemic, war, civil unrest, action by a government, or a failure of public infrastructure, payment systems or telecommunications. If such an event stops a confirmed session from taking place, you are refunded everything you paid, including the service fee, or you can move the session to a new time.',
      ],
    ),
    _LegalSection(
      number: '19',
      title: 'Other legal terms',
      paragraphs: [
        '19.1  Severance. If a court finds any part of these terms invalid or unenforceable, it will be changed only as far as needed to make it enforceable, or removed if that is not possible. The rest continues to apply.',
        '19.2  Transfer. You may not transfer your rights under these terms. We may transfer ours to any company that acquires our business or assets. We will tell you, and it will not reduce your rights or change a booking you have already made.',
        '19.3  Whole agreement. These terms and the documents listed in clause 1.5 are the whole agreement between you and us about our service.',
      ],
    ),
    _LegalSection(
      number: '20',
      title: 'Notices',
      paragraphs: [
        '20.1  We contact you in the app or by WhatsApp, using the mobile number on your account.',
        '20.2  Formal notices to us must be sent by email to support@getsetwell.com, marked "Legal notice", or by post to Get Set Fit LLC, Sharjah Media City (Shams), Sharjah, United Arab Emirates.',
      ],
    ),
    _LegalSection(
      number: '21',
      title: 'Law, disputes and language',
      paragraphs: [
        '21.1  These terms are governed by the laws of the United Arab Emirates.',
        '21.2  Disputes may be brought before the competent courts of the United Arab Emirates. This does not affect your right to refer a complaint to the consumer protection authorities under clause 12.4.',
        '21.3  These terms are published in Arabic and English. If the two versions differ, the Arabic version applies.',
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        ...section.finalParagraphs,
      ].join(' ').toLowerCase();

      if (searchableText.contains(query)) {
        matches.add(index);
      }
    }

    return matches;
  }

  bool get _allExpanded => _expandedSections.length == _sections.length;

  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expandedSections.clear();
      } else {
        _expandedSections
          ..clear()
          ..addAll(List.generate(_sections.length, (index) => index));
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
            'Arabic version will be available soon.',
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
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms of Service',
                        style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Version 1.2 · 28 September 2026',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'The agreement between you and Get Set Fit LLC when you use GetSetWell.',
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
                                ? 'All 21 sections, expanded'
                                : '${_expandedSections.length} of 21 sections expanded',
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

                      if (visibleIndexes.isEmpty)
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
                      else
                        for (final index in visibleIndexes) ...[
                          _buildSection(index, _sections[index]),

                          if (index != visibleIndexes.last)
                            const Divider(height: 1, color: GSWColors.borderSecondary),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            'Trainers are independent professionals. Your coaching agreement is with them. We find and check them, and run your booking.',
          ),
          _summaryItem(
            'You pay the trainer\'s rate plus a 5% service fee. The fee is kept if you cancel, reschedule late or don\'t turn up.',
          ),
          _summaryItem(
            'Cancel 24 hours or more before and you get the session rate back. Less than 24 hours, half. No-show, nothing.',
          ),
          _summaryItem(
            'If your trainer cancels or doesn\'t turn up, you get everything back, or a new time, or another trainer.',
          ),
          _summaryItem('You must be 18 or over, and you need WhatsApp to sign in.'),
          _summaryItem('Sessions you arrange with a trainer outside the app aren\'t covered.'),

          const SizedBox(height: 8),

          Text(
            'A summary to help you. The full terms below are what apply.',
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
          hintText: 'Search the terms',
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

                  if (section.bullets.isNotEmpty)
                    for (final bullet in section.bullets) _bullet(bullet),

                  for (final paragraph in section.trailingParagraphs) _paragraph(paragraph),

                  if (section.trailingBullets.isNotEmpty)
                    for (final bullet in section.trailingBullets) _bullet(bullet),

                  for (final paragraph in section.finalParagraphs) _paragraph(paragraph),
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
          label: 'Privacy Policy',
          onTap: () {
            context.push(GSWRoutes.privacyPolicy);
          },
        ),

        _footerDivider(),

        _buildFooterLink(
          label: 'Cancellation and Refunds Policy',
          onTap: () {
            context.push(GSWRoutes.cancellationAndRefund);
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
          'Questions about these terms?',
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
          'Published in Arabic and English. If the two differ, the Arabic version applies. Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams).',
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
    this.finalParagraphs = const [],
  });

  final String number;
  final String title;

  final List<String> paragraphs;
  final List<String> bullets;
  final List<String> trailingParagraphs;
  final List<String> trailingBullets;
  final List<String> finalParagraphs;
}
