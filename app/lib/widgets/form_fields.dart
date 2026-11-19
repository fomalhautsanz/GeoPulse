import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// A label above a text box. The box's look comes from the app theme.
///
/// `validator` is a function that returns an error message, or null when the
/// value is fine. The surrounding `Form` runs it when you call `validate()`.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.obscureText = false,
    this.suffix,
    this.suffixText,
    this.fillColor,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller; // holds what the user typed
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction; // "Next" or "Done" key
  final Iterable<String>? autofillHints; // lets password managers fill it
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText; // hide the text (passwords)
  final Widget? suffix; // e.g. a show/hide button
  final String? suffixText; // a unit after the value, e.g. "%"
  final Color? fillColor; // null = the theme's light grey
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _Labelled(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: suffix,
          suffixText: suffixText,
          suffixStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          fillColor: fillColor,
        ),
      ),
    );
  }
}

/// A password box with a show/hide eye button. Stateful because it
/// remembers whether the password is currently visible.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.isNewPassword = false,
    this.textInputAction = TextInputAction.done,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool isNewPassword; // Sign Up: lets password managers suggest one
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      obscureText: !_visible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      suffix: Pressable(
        onTap: () => setState(() => _visible = !_visible),
        semanticLabel: _visible ? 'Hide password' : 'Show password',
        child: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// A label above a dropdown. `<T>` makes it work with any value type, e.g.
/// `AppDropdownField<UserRole>`.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.validator,
  });

  final String label;
  final T? value; // null = nothing chosen yet
  final List<T> items;
  final String Function(T item) itemLabel; // turns a value into its text
  final ValueChanged<T?> onChanged;
  final String? hint;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return _Labelled(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        validator: validator,
        onChanged: onChanged,
        hint: hint == null ? null : Text(hint!),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
        borderRadius: BorderRadius.circular(12),
        dropdownColor: AppColors.surface,
        style: const TextStyle(fontSize: 15, color: AppColors.ink, fontFamily: 'Roboto'),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            height: 1.172,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
