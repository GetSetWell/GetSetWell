import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key, this.onReadArabic});

  final VoidCallback? onReadArabic;

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final TextEditingController _searchController = TextEditingController();

  final Set<int> _expandedSections = <int>{};

  String _searchQuery = '';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '01',
      title: 'Who we are',
      paragraphs: [
        '1.1  GetSetWell is operated by Get Set Fit LLC, a limited liability company licensed by Sharjah Media City (Shams) under licence number 2541939, with its registered address at Sharjah Media City (Shams), Sharjah, United Arab Emirates.',
        '1.2  We decide how and why your personal data is used, which makes us responsible for it under Federal Decree-Law 45 of 2021 on the Protection of Personal Data (the "PDPL").',
        '1.3  Privacy contact: info@getsetwell.com',
      ],
    ),
    _LegalSection(
      number: '02',
      title: 'What this policy covers',
      paragraphs: [
        '2.1  How we collect and use personal data when you use getsetwell.com or the GetSetWell app, create an account, ask us to match you, book and pay for sessions, or contact us.',
        '2.2  It also covers trainers who join GetSetWell (section 5). Trainers also sign a separate agreement with us.',
      ],
    ),
    _LegalSection(
      number: '03',
      title: 'What we collect about clients',
      paragraphs: ['3.1  When you create an account'],
      bullets: [
        'your name',
        'your mobile number, which we verify with a one-time code sent by WhatsApp',
        'your confirmation that you are 18 or over',
      ],
      trailingParagraphs: ['3.2  What we do not ask for'],
      trailingBullets: [
        'your email address, unless you choose to email us',
        'which emirate you live in, because we currently operate in Dubai only',
        'your date of birth',
        'your device location. We do not track where you are.',
        'your card details, which go directly to our payment provider',
      ],
      secondaryParagraphs: ['3.3  When you ask us to match you'],
      secondaryBullets: [
        'your goal',
        'the days and times you can train',
        'where you would like to train (at home, at a gym or outdoors) and your area, in your own words',
        'any preferences, such as a female trainer or a language',
        'your budget per session',
        'anything you add in the optional note',
      ],
      tertiaryParagraphs: ['3.4  When you book'],
      tertiaryBullets: [
        'the trainer and the type of session',
        'the date and time (all sessions are 60 minutes)',
        'the location of the session, which may be your home address if you choose to train at home',
        'the session rate, service fee and total',
        'the booking\'s status, and any cancellation, reschedule or refund, with any reason you give',
      ],
      finalParagraphs: [
        '3.5  When you pay',
        'Your card details are entered directly with our payment provider. We do not collect or store them. The provider tells us the amount, date, status and reference of each payment and refund.',
        '3.6  After your sessions',
      ],
      finalBullets: [
        'whether each session took place, and any report of lateness or a missed session',
        'any disagreement about attendance, and our decision',
        'any feedback you choose to give',
        'any complaint or report you make',
      ],
      endingParagraphs: [
        '3.7  When you contact us',
        'Messages between you and us on WhatsApp, by email, by phone or in the app, and our notes of them. If you email us, we will have your email address.',
        '3.8  Our own records',
      ],
      endingBullets: [
        'when we match you, which trainers we considered and why',
        'which trainer we introduced you to, and when. We need this to work out what trainers owe us.',
      ],
      lastParagraphs: [
        '3.9  Technical information',
        'Information about your device and app needed to send you notifications, the app version, and basic logs needed to keep the app working and secure. For our website, see section 15.',
      ],
    ),
    _LegalSection(
      number: '04',
      title: 'Information about your health',
      paragraphs: [
        '4.1  We do not ask about your health. Please do not include health details in a request, a note or a message to us.',
        '4.2  Pre and postnatal training. Some trainers coach clients who are pregnant or have recently given birth. If that applies to you, tell your trainer directly. We do not ask about it or record it.',
        '4.3  If you tell us about your health anyway, we use it only to deal with your request or message. We pass it to your trainer only if you ask us to. We delete it within 30 days after the related request or booking ends, or sooner if you ask.',
        '4.4  Injuries and incidents. If you report an injury or incident during a session, we use what you tell us to deal with it, to keep people safe, and to handle any claim. We keep it only as long as section 10 allows.',
        '4.5  Your trainer\'s own health questions. Your trainer may ask you about your health before you start. They do that as an independent professional, and they are responsible for that information. We do not receive it unless you or your trainer report an incident to us.',
        '4.6  We never use health information for marketing, and it never appears in any payment record.',
      ],
    ),
    _LegalSection(
      number: '05',
      title: 'What we collect about trainers',
      paragraphs: [
        '5.1  Name; contact details, including email address; identity document details; trade licence or freelance permit and its expiry; qualification records and the results of our checks on them; references; insurance details; first aid, CPR and lifesaving records; Dubai Sports Council registration, if any; photographs and biography; specialisms, areas, languages, and whether you appear in searches for a female trainer; session types, rates and availability; your status with the payment provider; VAT registration, if any; Bookings, Payouts and statements; Direct Session reports and invoices; reliability records; and complaints and feedback about your sessions.',
        '5.2  You give your bank details for Payouts directly to the payment provider.',
        '5.3  We use this information to review you, build your profile, run Bookings and Payouts, calculate commission and issue invoices, handle complaints, and meet our legal obligations.',
        '5.4  Your profile is public once you are listed.',
      ],
    ),
    _LegalSection(
      number: '06',
      title: 'Why we use personal data',
      paragraphs: [
        'The table shows what we use personal data for, and what allows us to under the PDPL.',
      ],
      bullets: [
        'Create and verify your account — Needed to provide the service you asked for',
        'Match you with a trainer — Needed to provide the service',
        'Arrange and manage bookings, reminders and rescheduling — Needed to provide the service',
        'Share booking details with your trainer — Needed to provide the service',
        'Arrange payments and refunds through our payment provider — Needed to provide the service',
        'Confirm whether sessions took place, and decide disagreements — Needed to provide the service, and to establish or defend legal claims',
        'Work out the commission a trainer owes us, including asking you whether you have trained with a trainer we introduced — Needed for our agreements with trainers. Answering our question is always optional for you.',
        'Handle complaints, incidents and safety concerns — Needed to provide the service, to protect someone\'s vital interests, and to establish or defend legal claims',
        'Send you messages about your account and bookings — Needed to provide the service',
        'Send you marketing — Your consent, which you can withdraw at any time',
        'Keep financial and tax records, and respond to authorities — Our legal obligations',
        'Review trainers, and run their Bookings, Payouts and invoices — Needed to perform our agreement with the trainer, and our legal obligations',
      ],
      trailingParagraphs: [
        '6.1  No decisions by computer alone. A person reads every request. We do not make decisions about you by automated means alone.',
      ],
    ),
    _LegalSection(
      number: '07',
      title: 'Messages from us',
      paragraphs: [
        '7.1  Service messages. We send messages about your account and bookings in the app, by push notification and by WhatsApp, including your verification codes. If you turn push notifications off, we will use WhatsApp for messages you need about a booking.',
        '7.2  Marketing. We send marketing only if you have agreed to it. You can stop it at any time by replying to any marketing message or by telling us.',
        '7.3  WhatsApp is operated by Meta. Messages pass through its systems, and its own terms and privacy policy apply.',
      ],
    ),
    _LegalSection(
      number: '08',
      title: 'Who we share personal data with',
      paragraphs: [
        '8.1  Trainers. When we are considering a trainer for you, we share what they need to decide whether they can help, such as your goal, availability, area, preferences and budget, without your name or number. When you book, your trainer receives your name, mobile number, the booking details and location, your goal, and anything you have asked us to pass on. They never receive your payment details.',
        '8.2  Our payment provider, which collects your payment, holds it, and pays the trainer\'s share. It receives your card and payment details directly. It uses them to process payments for us, and also for its own legal obligations, for which it is responsible.',
        '8.3  Service providers who help us run GetSetWell and use personal data only on our instructions:',
      ],
      bullets: [
        'Supabase — Our database and account verification',
        'Our messaging provider — Sending verification codes by WhatsApp',
        'GoDaddy — Hosting our website',
        'Titan — Our email',
        'Meta (WhatsApp) — Messaging',
        'Apple and Google — Push notifications',
      ],
      trailingParagraphs: [
        '8.4  Professional advisers, such as our lawyers and accountants, who are bound to keep it confidential.',
        '8.5  Authorities, where UAE law requires it.',
        '8.6  A buyer of our business, who would have to use it in line with this policy.',
        '8.7  We do not sell personal data, and we do not share it with advertisers.',
      ],
    ),
    _LegalSection(
      number: '09',
      title: 'Where your data is stored',
      paragraphs: ['9.1  Some of our providers store or process data outside the UAE:'],
      bullets: [
        'Supabase — Outside the UAE',
        'GoDaddy — Outside the UAE',
        'Titan — Outside the UAE',
        'Meta (WhatsApp) — Outside the UAE',
        'Our messaging provider — Outside the UAE',
        'Apple and Google — Outside the UAE',
        'Our payment provider — As set out in its own privacy policy',
      ],
      trailingParagraphs: [
        '9.2  Where personal data leaves the UAE, we transfer it only as the PDPL allows: for example, to a country with adequate data protection, under contractual safeguards, or where the transfer is needed to perform our agreement with you.',
      ],
    ),
    _LegalSection(
      number: '10',
      title: 'How long we keep it',
      bullets: [
        'Your account details — While your account is open, then deleted within 30 days of closure, except as below',
        'Requests and our matching notes — 12 months from the request',
        'Which trainer we introduced you to, and when — For as long as commission can arise from that introduction, then as part of our financial records',
        'Health information you gave us without being asked — Up to 30 days after the related request or booking ends',
        'Booking, payment, refund and commission records — 7 years from the end of the tax period they relate to',
        'Records of attendance and disagreements — 2 years from the session, or longer if a claim is made',
        'Reports of injuries and incidents — Until the time for bringing a claim has passed',
        'Messages with us — 2 years from our last contact',
        'Marketing consent — Until you withdraw it',
        'Trainer records — While the trainer is on GetSetWell, then for as long as our financial records and possible claims require, up to 7 years',
        'Technical logs — 12 months',
      ],
    ),
    _LegalSection(
      number: '11',
      title: 'Your rights',
      paragraphs: ['11.1  Under the PDPL you can ask us to:'],
      bullets: [
        'give you a copy of your personal data',
        'correct it',
        'delete it',
        'restrict how we use it',
        'stop using it, including for marketing, or for decisions made by automated means',
        'give it to you in a format you can pass to someone else',
        'stop relying on your consent, where we rely on it',
      ],
      trailingParagraphs: [
        '11.2  How to ask. Email info@getsetwell.com. To protect you, we may ask you to confirm your identity, for example with a code sent by WhatsApp to the mobile number on your account.',
        '11.3  How quickly we respond. We reply within 3 business days (Monday to Friday, excluding UAE public holidays). We complete your request within 30 days. If it will take longer, we tell you why. There is no charge.',
        '11.4  If you are not satisfied, you can complain to the UAE Data Office.',
      ],
    ),
    _LegalSection(
      number: '12',
      title: 'Closing your account',
      paragraphs: [
        '12.1  You can close your account in the app. Any future booking must be cancelled first.',
        '12.2  We then delete your account and personal data within 30 days, except the records we must keep under section 10.',
      ],
    ),
    _LegalSection(
      number: '13',
      title: 'Security',
      paragraphs: [
        '13.1  Personal data is held on access-controlled systems, encrypted in transit, and available only to people who need it. Card details never reach our systems.',
        '13.2  If a security breach is likely to affect you, we will tell you, and tell the authorities as the law requires.',
        '13.3  No system is completely secure, and we cannot guarantee the security of information sent over the internet or by WhatsApp.',
      ],
    ),
    _LegalSection(
      number: '14',
      title: 'Children',
      paragraphs: [
        '14.1  GetSetWell is for adults only. We do not knowingly collect personal data from anyone under 18. If we learn that we have, we delete it.',
      ],
    ),
    _LegalSection(
      number: '15',
      title: 'Cookies and analytics',
      paragraphs: [
        '15.1  Our website uses only the cookies it needs to work. Our app does not use advertising identifiers or third-party advertising trackers.',
        '15.2  If we add analytics or any non-essential cookies, we will update this policy first and ask for your consent where the law requires it.',
      ],
    ),
    _LegalSection(
      number: '16',
      title: 'Changes to this policy',
      paragraphs: [
        '16.1  We may update this policy. If a change affects how we use personal data you have already given us, we will tell you in the app or by WhatsApp before it takes effect. The current version always shows its version number and date.',
      ],
    ),
    _LegalSection(
      number: '17',
      title: 'Contact',
      paragraphs: [
        'Privacy questions and requests: info@getsetwell.com',
        'Help with a booking, and complaints: support@getsetwell.com, or WhatsApp +971 50 525 1393',
        'Post: Get Set Fit LLC, Sharjah Media City (Shams), Sharjah, United Arab Emirates',
      ],
    ),
    _LegalSection(
      number: '18',
      title: 'Law and language',
      paragraphs: [
        '18.1  This policy is governed by the laws of the United Arab Emirates.',
        '18.2  It is published in Arabic and English. If the two versions differ, the Arabic version applies.',
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
        ...section.secondaryParagraphs,
        ...section.secondaryBullets,
        ...section.tertiaryParagraphs,
        ...section.tertiaryBullets,
        ...section.finalParagraphs,
        ...section.finalBullets,
        ...section.endingParagraphs,
        ...section.endingBullets,
        ...section.lastParagraphs,
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
                        'Privacy Policy',
                        style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Version 1.2 · 28 September 2026',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'What personal data we collect, why we use it, who sees it, and your rights under UAE law.',
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
            'To create your account we ask for your name and mobile number. No email, no date of birth, and we never track your location.',
          ),
          _summaryItem(
            'We don\'t ask about your health. Please don\'t put health details in a request or message.',
          ),
          _summaryItem('Your trainer gets your name and number only when you book with them.'),
          _summaryItem(
            'Card details go straight to our payment provider. We never see or store them.',
          ),
          _summaryItem('We don\'t sell your data, and we don\'t share it with advertisers.'),
          _summaryItem(
            'You can ask for a copy of your data, or for it to be deleted, at any time.',
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

                  for (final paragraph in section.trailingParagraphs) _paragraph(paragraph),

                  for (final bullet in section.trailingBullets) _bullet(bullet),

                  for (final paragraph in section.secondaryParagraphs) _paragraph(paragraph),

                  for (final bullet in section.secondaryBullets) _bullet(bullet),

                  for (final paragraph in section.tertiaryParagraphs) _paragraph(paragraph),

                  for (final bullet in section.tertiaryBullets) _bullet(bullet),

                  for (final paragraph in section.finalParagraphs) _paragraph(paragraph),

                  for (final bullet in section.finalBullets) _bullet(bullet),

                  for (final paragraph in section.endingParagraphs) _paragraph(paragraph),

                  for (final bullet in section.endingBullets) _bullet(bullet),

                  for (final paragraph in section.lastParagraphs) _paragraph(paragraph),
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
          'Privacy questions and requests',
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
    this.secondaryParagraphs = const [],
    this.secondaryBullets = const [],
    this.tertiaryParagraphs = const [],
    this.tertiaryBullets = const [],
    this.finalParagraphs = const [],
    this.finalBullets = const [],
    this.endingParagraphs = const [],
    this.endingBullets = const [],
    this.lastParagraphs = const [],
  });

  final String number;
  final String title;

  final List<String> paragraphs;
  final List<String> bullets;

  final List<String> trailingParagraphs;
  final List<String> trailingBullets;

  final List<String> secondaryParagraphs;
  final List<String> secondaryBullets;

  final List<String> tertiaryParagraphs;
  final List<String> tertiaryBullets;

  final List<String> finalParagraphs;
  final List<String> finalBullets;

  final List<String> endingParagraphs;
  final List<String> endingBullets;

  final List<String> lastParagraphs;
}
