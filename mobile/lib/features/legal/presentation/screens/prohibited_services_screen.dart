import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class ProhibitedServicesScreen extends StatefulWidget {
  const ProhibitedServicesScreen({super.key, this.onReadArabic});

  final VoidCallback? onReadArabic;

  @override
  State<ProhibitedServicesScreen> createState() => _ProhibitedServicesScreenState();
}

class _ProhibitedServicesScreenState extends State<ProhibitedServicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  final Set<int> _expandedSections = <int>{};

  String _searchQuery = '';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '01',
      title: 'Why this exists',
      paragraphs: [
        '1.1  GetSetWell lists fitness professionals. It does not list healthcare providers, and no healthcare service may be provided through it.',
        '1.2  In the UAE, whether an activity needs a healthcare licence depends on what is actually done, not what it is called. Renaming a service does not exempt it. Dietitians and physiotherapists need a licence from the Dubai Health Authority (DHA) or the Ministry of Health and Prevention (MOHAP). Non-clinical fitness coaching does not.',
        '1.3  Our exposure rises wherever we present someone as qualified. So this policy is drawn tightly, and we enforce it on profile wording as well as on conduct.',
      ],
    ),
    _LegalSection(
      number: '02',
      title: 'What trainers may provide',
      bullets: [
        'Personal training, strength and conditioning, and general fitness coaching',
        'Group and one-to-one exercise instruction',
        'Yoga and Pilates instruction',
        'Running coaching, including technique, endurance and race preparation',
        'Swimming instruction and coaching, under the conditions in section 3.1',
        'Cycling coaching, indoors and outdoors, under the conditions in section 3.2',
        'Mobility, flexibility and general conditioning, including hands-on assisted stretching as part of a session, with the client\'s agreement, and not presented as treatment',
        'General wellness and lifestyle guidance',
        'Exercise programming for healthy adults, and for adults who have been cleared to exercise by a clinician',
        'Pre and postnatal fitness coaching, under the conditions in section 3.4',
      ],
    ),
    _LegalSection(
      number: '03',
      title: 'Conditions for particular activities',
      paragraphs: ['3.1  Swimming'],
      bullets: [
        'You hold a recognised swimming teaching or coaching qualification, and a current lifesaving or water rescue qualification and CPR.',
        'Sessions take place only at pools with a lifeguard or equivalent safety cover on duty, such as those at gyms, hotels and clubs. Villa, community and other private pools, and open water, are not offered through GetSetWell for now.',
        'You follow the pool\'s rules and have its permission to coach there.',
        'You assess the client\'s swimming ability at the start of the first session, and keep the session within it.',
      ],
      trailingParagraphs: ['3.2  Cycling'],
      trailingBullets: [
        'Outdoors, you and your client follow the Roads and Transport Authority\'s rules for cyclists, including wearing a helmet and cycling only where cycling is permitted.',
        'You check that the equipment is safe before starting, and use lights and visible clothing after dark.',
        'You choose routes suited to the client\'s ability.',
      ],
      secondaryParagraphs: ['3.3  Running and all outdoor sessions'],
      secondaryBullets: [
        'You take reasonable precautions for heat and hydration. In the hottest months, you schedule outdoor sessions at cooler times of day or move them indoors.',
        'You hold any permit or permission needed to train in the place you use, such as a public park, beach or community facility.',
      ],
      tertiaryParagraphs: ['3.4  Pre and postnatal'],
      tertiaryBullets: [
        'You hold a specific pre and postnatal qualification, recorded on your profile.',
        'The client has been cleared to exercise by her clinician.',
        'You give fitness coaching only. No advice on the medical management of pregnancy or recovery.',
      ],
      finalParagraphs: ['3.5  Sessions in a client\'s home'],
      finalBullets: [
        'You behave professionally, respect the client\'s privacy and property, and check that the space and any equipment are safe before starting.',
      ],
    ),
    _LegalSection(
      number: '04',
      title: 'What trainers may not provide',
      paragraphs: [
        'These are prohibited through GetSetWell, and in coaching you provide to a client we introduced. This applies even if you hold a healthcare licence. You may name a UAE healthcare licence in the qualifications section of your profile, once we have verified it, but what you offer through GetSetWell is fitness coaching only. Any licensed healthcare service you provide is outside GetSetWell, and we do not arrange it or take commission on it.',
        '4.1  Medical and clinical services',
        'No diagnosis of any condition. No treatment of injury, illness or pain. No clinical assessment. No prescribing, supplying or recommending prescription medication. No advice that a client should stop, start or change a medication or medical treatment.',
        '4.2  Physiotherapy and rehabilitation',
        'No treatment of an injury. No clinical rehabilitation programme. No manual therapy, manipulation or soft tissue treatment presented as treatment. No clinical pelvic floor rehabilitation.',
        'What is permitted: general strengthening and conditioning with a client who has been discharged by their clinician and cleared to exercise, described without clinical terms.',
        '4.3  Nutrition and dietetics',
        'No therapeutic meal plans. No dietary management of a diagnosed condition such as diabetes, coeliac disease, kidney disease or an eating disorder. No calorie or macronutrient prescription presented as a clinical intervention. No supplement prescribing.',
        'What is permitted: general wellness and lifestyle guidance about food, while it stays general and is not presented as clinical or therapeutic.',
        '4.4  Pre and postnatal',
        'No midwifery or nursing services. No clinical pelvic floor rehabilitation. No advice on the medical management of pregnancy or recovery.',
        '4.5  Psychological services',
        'No counselling, psychotherapy, or treatment of a mental health condition. General motivation and accountability are fine. Presenting yourself as a therapist is not.',
        '4.6  Substances',
        'No supplying, recommending or helping a client obtain any prohibited or controlled substance, including anabolic steroids, or any prescription product.',
        '4.7  Other',
        'No medical or therapeutic massage. No injections, IV therapy or any invasive procedure. No diagnostic testing. No coaching of anyone under 18 through GetSetWell, or with a client we introduced.',
        '4.8  Products',
        'No selling, supplying or promoting supplements or other products to clients we introduced, for now.',
      ],
    ),
    _LegalSection(
      number: '05',
      title: 'Language that may not appear on a profile or in marketing',
      paragraphs: [
        '5.1  These words imply a clinical service and may not be used to describe what you offer. If you hold a verified UAE healthcare licence, you may name it in the qualifications section of your profile, for example "DHA licensed physiotherapist", and nowhere else.',
        'Not permitted: treat, treatment, therapy, therapist, therapeutic, rehab, rehabilitate, rehabilitation, cure, heal, diagnose, diagnosis, prescribe, prescription, clinic, clinical, patient, medical, physio, physiotherapy, physiotherapist, osteopath, chiropractor, dietitian, dietician, nutritionist, psychologist, counsellor, nurse, midwife, injury specialist, doctor, and "Dr" as a title.',
        '5.2  Also not permitted: any promise of a guaranteed result, any before-and-after claim presented as typical, and any suggestion that GetSetWell has verified a clinical skill it has not.',
        '5.3  How to say it instead:',
      ],
      cards: [
        _PolicyCard(
          title: '"Rehabilitates injuries"',
          lines: ['"Works with clients returning from injury, after medical clearance"'],
        ),
        _PolicyCard(title: '"Therapist"', lines: ['"Coach" or "instructor"']),
        _PolicyCard(
          title: '"Treats back pain"',
          lines: ['"Focuses on mobility and core strength"'],
        ),
        _PolicyCard(title: '"Meal plans"', lines: ['"General nutrition guidance"']),
        _PolicyCard(
          title: '"Guaranteed weight loss"',
          lines: ['"Works with clients on weight goals"'],
        ),
      ],
      trailingParagraphs: ['5.4  Known items to fix before launch:'],
      trailingBullets: [
        '"Yoga Therapist" appears in one trainer\'s existing description and must be changed. The qualification can still be recorded as held. The title cannot be used to describe the service.',
        'The app category once called Rehabilitation is now Recovery and Mobility. The old name must not reappear in copy, filters or metadata.',
      ],
    ),
    _LegalSection(
      number: '06',
      title: 'What we check',
      paragraphs: ['Before listing, we check:'],
      bullets: [
        'your identity, and your own trade licence or freelance permit',
        'qualification names, issuers, status and dates, checked against an official register or with the issuer where one exists',
        'for swimming, a current lifesaving or water rescue qualification and CPR',
        'for a specialist service, education and experience specific to that service',
        'if you coach at a gym or other sports facility, your Dubai Sports Council registration',
        'where you name a healthcare licence on your profile, or any service is close to healthcare, the DHA or MOHAP licence and its expiry, checked through the issuing authority\'s own online verification rather than from a document you supply',
        'a signed declaration from you setting out your non-medical scope of practice',
      ],
      trailingParagraphs: [
        'We check your licence or permit, and any qualification with an expiry date, again at least once a year and whenever one is due to expire. Insurance is checked under the Trainer Agreement.',
        'We keep a copy of the result of each check, not only the document we were given.',
      ],
    ),
    _LegalSection(
      number: '07',
      title: 'Your obligations as a trainer',
      paragraphs: ['You will:'],
      bullets: [
        'work only within your qualifications and your licence',
        'refer a client to a clinician where their needs fall outside what you may lawfully provide',
        'decline a client whose needs you are not qualified to meet, and tell us, so we can match them properly',
        'keep your profile and marketing free of the language in section 5',
        'follow the conditions in section 3 for the activities you offer',
        'tell us immediately if any licence, permit or qualification lapses, is suspended or is withdrawn',
        'never describe yourself in a way that suggests GetSetWell has verified something it has not',
      ],
    ),
    _LegalSection(
      number: '08',
      title: 'What happens if this policy is broken',
      cards: [
        _PolicyCard(
          title: 'Prohibited language on a profile',
          lines: ['We ask you to change it, and correct it ourselves if needed'],
        ),
        _PolicyCard(
          title: 'Repeated after a warning',
          lines: ['Profile suspended until it is fixed'],
        ),
        _PolicyCard(
          title: 'Not following a condition in section 3',
          lines: ['Warning, and suspension if it continues or puts a client at risk'],
        ),
        _PolicyCard(
          title: 'Providing a service you are not licensed to provide',
          lines: ['Immediate removal and termination of your agreement'],
        ),
        _PolicyCard(
          title: 'Any conduct that puts a client at risk',
          lines: ['Immediate removal, and we tell the client'],
        ),
      ],
      trailingParagraphs: [
        '8.1  We do not impose fines or financial penalties for breaking this policy. If a breach causes loss, clause 19 of the Trainer Agreement still applies.',
        '8.2  Where a client has been affected, we will tell them what happened.',
      ],
    ),
    _LegalSection(
      number: '09',
      title: 'For clients',
      paragraphs: [
        '9.1  Through GetSetWell, trainers act only as fitness coaches. Some hold other qualifications, which their profiles show, but nothing they provide through GetSetWell is medical care.',
        '9.2  If you have an injury or a health condition, are pregnant or have recently given birth, or have not exercised for a long time, speak to a doctor before you start. Tell your trainer directly about anything that affects how you should train. We do not ask for your medical history.',
        '9.3  If a trainer ever offers you something that sounds like medical treatment, or tries to sell you supplements or other products, please tell us.',
      ],
    ),
    _LegalSection(
      number: '10',
      title: 'Contact',
      paragraphs: [
        'To report anything under this policy: email support@getsetwell.com · WhatsApp +971 50 525 1393 · in the app, under Report.',
      ],
    ),
    _LegalSection(
      number: '11',
      title: 'Language',
      paragraphs: [
        '11.1  This policy is published in Arabic and English. For clients, if the two versions differ, the Arabic version applies. For trainers, the language clause in the Trainer Agreement applies.',
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
        ...section.cards.expand((card) => [card.title, ...card.lines]),
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
                        'Prohibited Services',
                        style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Version 1.2 · 28 September 2026',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'This policy forms part of the Trainer Agreement and of the Terms of Service. It applies to every trainer listed on GetSetWell: to their profile and marketing, to sessions booked through GetSetWell, and to coaching they provide directly to clients we introduced.',
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
                                ? 'All 11 sections, expanded'
                                : '${_expandedSections.length} of 11 sections expanded',
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
            'Trainers on GetSetWell are fitness coaches. Nothing they provide through us is medical care.',
          ),

          _summaryItem(
            'No diagnosis, treatment, physiotherapy, therapeutic meal plans, counselling or therapeutic massage.',
          ),

          _summaryItem(
            'No supplements or other products sold to you, and no prescription or controlled substances.',
          ),

          _summaryItem(
            'Swimming, cycling, outdoor, pre and postnatal and home sessions have extra safety conditions.',
          ),

          _summaryItem(
            'If a trainer offers you something that sounds like treatment, or tries to sell you something, tell us.',
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

                  for (final card in section.cards) _policyCard(card),
                ],
              ),
            ),
          ],
        ],
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
            style: GSWTextStyles.bodyLarge.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 6),

          for (var index = 0; index < card.lines.length; index++) ...[
            Text(
              card.lines[index],
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            if (index != card.lines.length - 1) const SizedBox(height: 6),
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
          label: 'Cancellation and Refunds Policy',
          onTap: () {
            context.push(GSWRoutes.cancellationAndRefund);
          },
        ),
        _footerDivider(),

        const SizedBox(height: 24),
        Text(
          'Report something under this policy',
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
    this.secondaryParagraphs = const [],
    this.secondaryBullets = const [],
    this.tertiaryParagraphs = const [],
    this.tertiaryBullets = const [],
    this.finalParagraphs = const [],
    this.finalBullets = const [],
    this.cards = const [],
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

  final List<_PolicyCard> cards;
}

class _PolicyCard {
  const _PolicyCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}
