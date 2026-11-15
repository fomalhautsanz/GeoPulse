import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/fade_route.dart';
import '../widgets/hero_arch.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

/// The first screen: logo, what GeoPulse does, and Log in / Create account.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // SafeArea keeps content out of the status bar and gesture bar.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(33, 0, 33, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Spacer/Expanded share out the free height, so the layout
              // works on short and tall phones.
              const Spacer(flex: 2),
              SizedBox(
                height: 300,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      height: 300,
                      child: HeroArch(tint: AppColors.heroGlow),
                    ),
                    Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/logo.svg',
                          width: 96,
                          height: 96,
                          semanticsLabel: 'GeoPulse logo',
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'GeoPulse',
                          style: TextStyle(
                            fontSize: 36,
                            height: 1.172,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Landslide and ground-movement alerts for your barangay, '
                          'even when the internet is down.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 21 / 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              AppButton(
                label: 'Log in',
                onPressed: () => Navigator.of(context).push(fadeRoute<void>(context, const LoginScreen())),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Create an account',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).push(fadeRoute<void>(context, const SignUpScreen())),
              ),
              const SizedBox(height: 16),
              const Text(
                'GeoPulse detects risky conditions. It can’t predict exactly when a '
                'landslide or earthquake will happen. Always follow official advisories.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, height: 15 / 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
