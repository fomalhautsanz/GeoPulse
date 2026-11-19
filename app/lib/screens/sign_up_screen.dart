import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../models/user_profile.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_layout.dart';
import '../widgets/fade_route.dart';
import '../widgets/form_fields.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Create an account: name, phone, role, barangay/site and password.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _barangay = TextEditingController();
  final _password = TextEditingController();
  UserRole? _role; // null until chosen
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _barangay.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), ''); // keep digits only
    if (digits.isEmpty) return 'Enter your phone number';
    if (digits.length < 10) return 'Enter a full phone number, e.g. 09XX XXX XXXX';
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await signUp(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      role: _role!, // `!` = "I know it's not null": the validator checked it
      barangay: _barangay.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
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
          title: 'Sign up',
          heading: 'Create your account',
          subheading: 'Get alerts for your barangay and see live readings from the sensor node.',
          switchPrompt: 'Already have an account?',
          switchAction: 'Log in',
          onSwitch: () => Navigator.of(context).pushReplacement(fadeRoute<void>(context, const LoginScreen())),
          children: [
            AppTextField(
              label: 'Full name',
              controller: _name,
              autofillHints: const [AutofillHints.name],
              validator: (v) => _required(v, 'Enter your name'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone number',
              controller: _phone,
              hint: '09XX XXX XXXX',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),
            AppDropdownField<UserRole>(
              label: 'Role',
              value: _role,
              hint: 'Choose your role',
              items: UserRole.values,
              itemLabel: (role) => role.label,
              onChanged: (role) => setState(() => _role = role),
              validator: (role) => role == null ? 'Choose your role' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Barangay / site',
              controller: _barangay,
              hint: 'e.g. Brgy. San Isidro',
              autofillHints: const [AutofillHints.addressCity],
              validator: (v) => _required(v, 'Enter your barangay or site'),
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              label: 'Password',
              controller: _password,
              isNewPassword: true,
              onSubmitted: (_) => _submit(),
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 24),
            AppButton(label: _busy ? 'Creating account…' : 'Create account', onPressed: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}
