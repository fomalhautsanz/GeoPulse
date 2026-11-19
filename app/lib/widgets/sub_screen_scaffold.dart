import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'top_bar.dart';

/// The frame of screens opened from another screen (Thresholds, Alert
/// contacts, Notifications…): back chevron + red title pill, no bottom nav,
/// a scrolling body and an optional button pinned to the bottom.
class SubScreenScaffold extends StatelessWidget {
  const SubScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });

  final String title;
  final List<Widget> children; // the scrolling content, top to bottom
  final Widget? bottom; // e.g. "Save and sync to device"
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final bottom = this.bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, math.max(51, insets.top), 20, 0),
            child: TopBar(
              title: title,
              showNotifications: false,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: ListView(padding: padding, children: children),
          ),
          if (bottom != null)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, math.max(16, insets.bottom + 8)),
              child: bottom,
            ),
        ],
      ),
    );
  }
}
