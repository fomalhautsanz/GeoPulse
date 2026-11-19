import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';
import 'top_bar.dart';

/// The shared frame of Log in and Sign up: header with a back chevron, a big
/// heading, a scrollable form, and a "switch screens" line at the bottom.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.heading,
    required this.subheading,
    required this.children,
    required this.switchPrompt,
    required this.switchAction,
    required this.onSwitch,
  });

  final String title; // in the red pill
  final String heading; // big text
  final String subheading;
  final List<Widget> children; // the form
  final String switchPrompt; // "New to GeoPulse?"
  final String switchAction; // "Create an account"
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(33, math.max(61, insets.top), 33, 0),
            child: TopBar(
              title: title,
              showNotifications: false,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            // Scrolls when the keyboard takes up space.
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(33, 28, 33, 24 + insets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 34 / 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subheading,
                    style: const TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  ...children, // `...` spreads a list into this list
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$switchPrompt ',
                        style: const TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                      Pressable(
                        onTap: onSwitch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            switchAction,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
