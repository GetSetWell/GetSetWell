import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Shared pieces for the legal document screens, matched to Figma
/// 12.5a Terms of Service (1068:3500), 12.5b Privacy Policy (1069:3530)
/// and the full-text layout frames (e.g. 1108:3736).

/// Content padding below the top bar: 8 top, 16 sides, 40 bottom.
const EdgeInsets kLegalContentPadding = EdgeInsets.fromLTRB(16, 8, 16, 40);

/// Gap between top-level blocks.
const double kLegalBlockGap = 24;

TextStyle get _bodyStyle =>
    GSWTextStyles.bodyMedium.copyWith(height: 21 / 14, color: GSWColors.textSecondary);

/// Top bar: 46px back button and "Arabic" with a Coming soon pill, 16 sides,
/// 4 vertical.
class LegalDocTopBar extends StatelessWidget {
  const LegalDocTopBar({super.key, this.onReadArabic, this.showArabic = true});

  /// False on screens that are not legal documents, such as Help & support.
  final bool showArabic;

  /// Kept for when the Arabic text ships. Not used while it is coming soon.
  final VoidCallback? onReadArabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(GSWRoutes.userProfile);
                }
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GSWColors.borderSecondary),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  GSWIcons.arrowheadLeft,
                  width: 30,
                  height: 30,
                  colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          if (showArabic) const LegalArabicComingSoon(),
        ],
      ),
    );
  }
}

/// "Arabic" plus a "Coming soon" pill (same pill as Language settings).
/// Not tappable, so it never looks like a button that does nothing.
class LegalArabicComingSoon extends StatelessWidget {
  const LegalArabicComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Arabic, coming soon',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Arabic',
            style: GSWTextStyles.labelMedium.copyWith(
              fontSize: 13,
              height: 16 / 13,
              color: GSWColors.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: GSWColors.surfaceInteractive,
              borderRadius: BorderRadius.circular(GSWRadius.full),
            ),
            child: Text(
              'Coming soon',
              style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title (Bold 24/30), version (12/16 tertiary) and intro (14/20 secondary), 6 apart.
class LegalDocTitle extends StatelessWidget {
  const LegalDocTitle({
    super.key,
    required this.title,
    required this.version,
    required this.intro,
    this.extra = const [],
  });

  final String title;
  final String version;
  final String intro;

  /// Extra intro paragraphs (same style as [intro]).
  final List<String> extra;

  @override
  Widget build(BuildContext context) {
    final introStyle = GSWTextStyles.bodyMedium.copyWith(
      height: 20 / 14,
      color: GSWColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GSWTextStyles.titleLarge.copyWith(height: 30 / 24, color: GSWColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          version,
          style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
        ),
        const SizedBox(height: 6),
        Text(intro, style: introStyle),
        for (final paragraph in extra) ...[
          const SizedBox(height: 6),
          Text(paragraph, style: introStyle),
        ],
      ],
    );
  }
}

/// "THE SHORT VERSION" card: Surface/Primary, 1px Surface/Interactive border,
/// radius 16, padding 16, gap 12.
class LegalShortVersionCard extends StatelessWidget {
  const LegalShortVersionCard({super.key, required this.points, required this.footnote});

  final List<String> points;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE SHORT VERSION',
            style: GSWTextStyles.labelSmall.copyWith(
              height: 16 / 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.96,
              color: GSWColors.textAccent,
            ),
          ),
          for (final point in points) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: GSWColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      height: 20 / 14,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            footnote,
            style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Search field: Surface/Interactive fill, radius 12, 14 x 12 padding,
/// 20px search icon, 10 gap, 14/20 text.
class LegalSearchField extends StatelessWidget {
  const LegalSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.control),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            GSWIcons.search,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(GSWColors.textSecondary, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: GSWColors.primary,
              textInputAction: TextInputAction.search,
              style: GSWTextStyles.bodyMedium.copyWith(
                height: 20 / 14,
                color: GSWColors.textPrimary,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: GSWTextStyles.bodyMedium.copyWith(
                  height: 20 / 14,
                  color: GSWColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SvgPicture.asset(
                  GSWIcons.close,
                  width: 12,
                  height: 12,
                  colorFilter: const ColorFilter.mode(GSWColors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "All N sections" (secondary) and "Expand all" (accent), Medium 13/16.
class LegalSectionsHeader extends StatelessWidget {
  const LegalSectionsHeader({
    super.key,
    required this.label,
    required this.allExpanded,
    required this.onToggle,
  });

  final String label;
  final bool allExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final style = GSWTextStyles.labelMedium.copyWith(fontSize: 13, height: 16 / 13);

    return Row(
      children: [
        Expanded(
          child: Text(label, style: style.copyWith(color: GSWColors.textSecondary)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Text(
            allExpanded ? 'Collapse all' : 'Expand all',
            style: style.copyWith(color: GSWColors.textAccent),
          ),
        ),
      ],
    );
  }
}

/// 1px Surface/Interactive divider used between accordion rows and links.
class LegalDivider extends StatelessWidget {
  const LegalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: GSWColors.surfaceInteractive),
    );
  }
}

/// One accordion section. Header: py 16, gap 12, number Bebas 20/24 (24 wide,
/// tertiary, accent when open), title Outfit Medium 15/20, 20px chevron.
/// Body: 36 left, 20 bottom.
class LegalAccordionSection extends StatelessWidget {
  const LegalAccordionSection({
    super.key,
    required this.number,
    required this.title,
    required this.expanded,
    required this.onTap,
    required this.children,
  });

  final String number;
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    number,
                    style: GSWTextStyles.headingSmall.copyWith(
                      fontSize: 20,
                      height: 24 / 20,
                      color: expanded ? GSWColors.textAccent : GSWColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GSWTextStyles.labelLarge.copyWith(
                      fontSize: 15,
                      height: 20 / 15,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SvgPicture.asset(
                  expanded ? GSWIcons.arrowheadUp : GSWIcons.arrowheadDown,
                  width: 20,
                  height: 16.667,
                  colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            // Children carry their own bottom spacing (14 after a paragraph),
            // so 6 here makes the 20px bottom padding from the design.
            padding: const EdgeInsets.only(left: 36, bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
      ],
    );
  }
}

/// Body paragraph, Regular 14/21 secondary. A leading clause number such as
/// "2.1" is shown in Medium, tertiary, like the design.
class LegalParagraph extends StatelessWidget {
  const LegalParagraph(this.text, {super.key, this.detectHeading = false});

  final String text;

  /// When true, a short numbered line with no closing punctuation, such as
  /// "3.1  Swimming", is shown as a sub-heading (Medium 14/20, white).
  final bool detectHeading;

  static final RegExp _clause = RegExp(r'^(\d+\.\d+)\s+');

  bool _isHeading(String rest) {
    final trimmed = rest.trim();
    if (trimmed.isEmpty || trimmed.length > 48) return false;
    if (trimmed.contains(':') || trimmed.contains('@')) return false;
    final last = trimmed[trimmed.length - 1];
    return last != '.' && last != ':' && last != ';' && last != ',';
  }

  @override
  Widget build(BuildContext context) {
    final match = _clause.firstMatch(text);

    final Widget child;
    if (match != null && detectHeading && _isHeading(text.substring(match.end))) {
      child = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: match.group(1),
              style: const TextStyle(color: GSWColors.textTertiary),
            ),
            TextSpan(text: '  ${text.substring(match.end)}'),
          ],
        ),
        style: GSWTextStyles.labelMedium.copyWith(height: 20 / 14, color: GSWColors.textPrimary),
      );
    } else if (match == null) {
      child = Text(text, style: _bodyStyle);
    } else {
      child = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: match.group(1),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: GSWColors.textTertiary,
              ),
            ),
            TextSpan(text: '  ${text.substring(match.end)}'),
          ],
        ),
        style: _bodyStyle,
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 14), child: child);
  }
}

/// Body list item: 5px dot, 10 gap, Regular 14/21 secondary, 8 between items.
class LegalBullet extends StatelessWidget {
  const LegalBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: GSWColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }
}

/// Numbered list item (worked examples): number 20 wide, 10 gap, 12 between.
class LegalNumberedItem extends StatelessWidget {
  const LegalNumberedItem({super.key, required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$number.',
              style: _bodyStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: GSWColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }
}

class LegalLink {
  const LegalLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

/// "READ WITH THESE" list: eyebrow SemiBold 12/16 tertiary, rows py 14,
/// Regular 15/20 and a 16.667 x 20 chevron, divider after each row.
class LegalReadWith extends StatelessWidget {
  const LegalReadWith({super.key, required this.links});

  final List<LegalLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READ WITH THESE',
          style: GSWTextStyles.labelSmall.copyWith(
            height: 16 / 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.96,
            color: GSWColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        for (final link in links) ...[
          InkWell(
            onTap: link.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link.label,
                      style: GSWTextStyles.bodyLarge.copyWith(
                        fontSize: 15,
                        height: 20 / 15,
                        color: GSWColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SvgPicture.asset(
                    GSWIcons.arrowheadRight,
                    width: 16.667,
                    height: 20,
                    colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
          const LegalDivider(),
        ],
      ],
    );
  }
}

/// Contact block (Medium 14/20 white, then Regular 14/20 accent, 4 apart)
/// followed by the published-in note (12/16 tertiary), 24 apart.
class LegalDocFooter extends StatelessWidget {
  const LegalDocFooter({
    super.key,
    required this.contactHeading,
    required this.contactLine,
    this.note =
        'Published in Arabic and English. If the two differ, the Arabic version applies. '
        'Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams).',
  });

  final String contactHeading;
  final String contactLine;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contactHeading,
          style: GSWTextStyles.labelMedium.copyWith(height: 20 / 14, color: GSWColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          contactLine,
          style: GSWTextStyles.bodyMedium.copyWith(height: 20 / 14, color: GSWColors.textAccent),
        ),
        const SizedBox(height: kLegalBlockGap),
        Text(
          note,
          style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
        ),
      ],
    );
  }
}

class LegalTableRow {
  const LegalTableRow({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

/// Bordered table (Figma 1108:3897, 1109:4037): 1px Surface/Interactive border,
/// radius 12, optional 34px eyebrow header, rows padded 14 x 12 with a title
/// (Medium 14/20 white) and lines (Regular 14/20 secondary) 4 apart.
/// A "Label:  value" line shows its label in Medium.
class LegalTable extends StatelessWidget {
  const LegalTable({super.key, required this.rows, this.header});

  final List<LegalTableRow> rows;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final lineStyle = GSWTextStyles.bodyMedium.copyWith(
      height: 20 / 14,
      color: GSWColors.textSecondary,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSWRadius.inner),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                header!,
                style: GSWTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.88,
                  color: GSWColors.textTertiary,
                ),
              ),
            ),
            const LegalDivider(),
          ],
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const LegalDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[index].title,
                    style: GSWTextStyles.labelMedium.copyWith(
                      height: 20 / 14,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                  for (final line in rows[index].lines) ...[
                    const SizedBox(height: 4),
                    _line(line, lineStyle),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String line, TextStyle style) {
    final split = line.indexOf(':  ');
    if (split <= 0) return Text(line, style: style);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: line.substring(0, split + 1),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: line.substring(split + 1)),
        ],
      ),
      style: style,
    );
  }
}
