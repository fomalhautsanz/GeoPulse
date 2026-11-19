import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_route.dart';
import '../widgets/form_fields.dart';
import '../widgets/pressable.dart';
import 'sign_up_screen.dart';
import 'main_shell.dart';

/// Log in with phone/email and password. Any non-empty details work for now
/// (mock data); the real check will happen in `auth_repository.dart`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // A GlobalKey lets us reach the Form to run every field's validator.
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    // Controllers hold resources; release them when the screen closes.
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await logIn(
      phoneOrEmail: _identifier.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    // Go to the app and remove Landing/Log in, so Back doesn't return here.
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute<void>(context, const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: AuthLayout(
          title: 'Log in',
          heading: 'Welcome back',
          subheading: 'Log in to see your sensor node’s status and alerts.',
          switchPrompt: 'New to GeoPulse?',
          switchAction: 'Create an account',
          // Replace (not push), so Back goes to Landing, not back to Log in.
          onSwitch: () => Navigator.of(context)
              .pushReplacement(fadeRoute<void>(context, const SignUpScreen())),
          children: [
            AppTextField(
              label: 'Phone number',
              controller: _identifier,
              hint: '09XX XXX XXXX',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.username],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your phone number'
                  : null,
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              label: 'Password',
              controller: _password,
              onSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Pressable(
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Password reset isn’t available yet.'),
                    ),
                  ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: _busy ? 'Logging in…' : 'Log in',
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
