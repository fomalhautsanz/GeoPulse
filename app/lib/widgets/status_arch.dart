import 'package:flutter/material.dart';

/// The soft arch behind the Status icon, title and pill: 334 × 300, 196 px
/// from the top of the screen, round only at the top, fading to white.
///
/// It returns a `Positioned`, so it must be a direct child of a `Stack`
/// that starts at the top of the screen (see `AppScaffold.background`).
class StatusArch extends StatelessWidget {
  final Color tint; // stable #EAF0F4, watch #FBE4E2, high #F7D6D3
  const StatusArch({super.key, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 196, left: 0, right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 334,
          height: 300,
          decoration: BoxDecoration(
            // ONLY the top is round = half circle on top, straight sides, square bottom
            borderRadius: const BorderRadius.vertical(top: Radius.circular(167)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tint, Colors.white],
              stops: const [0.1, 0.75], // fully white before the bottom edge
            ),
          ),
        ),
      ),
    );
  }
}
