import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// The soft half-circle arch behind a hero (status icon and title, the
/// Landing logo). 334 × 300, rounded only at the top, fading into white
/// so it has no visible bottom edge.
///
/// When [tint] changes, the colour fades over 200 ms; the shape never moves.
/// Place it in a `Stack`; it stays exactly 334 wide and centred.
class HeroArch extends StatelessWidget {
  const HeroArch({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minWidth: 334,
      maxWidth: 334,
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: AppMotion.levelChangeFor(context),
        curve: AppMotion.levelCurve,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(179)),
          // Fully white by 48% of the height, so it reads as a half circle
          // fading out and its rounded sides never show lower down.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint, AppColors.surface],
            stops: const [0.1, 0.48],
          ),
        ),
      ),
    );
  }
}
