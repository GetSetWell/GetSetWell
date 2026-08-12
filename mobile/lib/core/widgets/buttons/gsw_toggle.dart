import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';

class GSWToggle extends StatelessWidget {
  const GSWToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? GSWColors.primary : GSWColors.surfaceElevated,
                borderRadius: BorderRadius.circular(GSWRadius.full),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? GSWColors.surfacePrimary : GSWColors.neutral400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
