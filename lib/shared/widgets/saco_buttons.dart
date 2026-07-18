import 'package:flutter/material.dart';

import '../../core/design/design_system.dart';

class SacoPrimaryButton extends StatelessWidget {
  const SacoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: (enabled && !loading) ? AppShadows.primaryGlow(opacity: 0.22) : null,
      ),
      child: FilledButton(
        onPressed: (!enabled || loading) ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class SacoTextField extends StatelessWidget {
  const SacoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelStyle),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autocorrect: autocorrect,
          style: AppTypography.bodyStyle.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}

class SacoOutlinedButton extends StatelessWidget {
  const SacoOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
