import 'package:flutter/material.dart';

import '../../../../core/widgets/common/gsw_logo.dart';
import '../../theme/gsw_spacing.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, child: const GSWLogo()),
            const SizedBox(width: GSWSpacing.xxs),
            Image.asset('assets/logos/wordmark.png', width: 100),
          ],
        ),

        // Language selector
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EN', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 16),
            Text('|', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 16),
            Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
