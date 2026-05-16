import 'package:flutter/material.dart';

class TelegramTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  const TelegramTextField({
    super.key,
    this.controller,
    required this.label,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
      ),
      cursorColor: const Color(0xFF2AABEE),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF6C7883) : const Color(0xFF8E8E93),
          fontSize: 15,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF2AABEE),
          fontSize: 13,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1C2733)
            : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF0E1621)
                : const Color(0xFFE0E0E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2AABEE), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
