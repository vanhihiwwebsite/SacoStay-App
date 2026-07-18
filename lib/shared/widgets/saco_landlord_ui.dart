import 'package:flutter/material.dart';

import '../../core/design/design_system.dart';
import 'app_ui.dart';

/// Wraps wide content (tables, stat rows) with horizontal swipe on mobile.
class SacoHorizontalScroll extends StatelessWidget {
  const SacoHorizontalScroll({
    super.key,
    required this.child,
    this.minWidth,
    this.padding = const EdgeInsets.only(bottom: 4),
    this.showHint = false,
  });

  final Widget child;
  final double? minWidth;
  final EdgeInsets padding;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Vuốt sang để xem thêm →',
              style: AppTypography.captionStyle.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.right,
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth ?? 640),
            child: child,
          ),
        ),
      ],
    );
  }
}

class SacoPageHeader extends StatelessWidget {
  const SacoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

class SacoSectionCard extends StatelessWidget {
  const SacoSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.titleStyle),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle!, style: AppTypography.captionStyle),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class SacoPillTabs extends StatelessWidget {
  const SacoPillTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.mdAll,
      ),
      child: SacoHorizontalScroll(
        showHint: tabs.length > 3,
        minWidth: tabs.length * 130.0,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: AppRadius.smAll,
                elevation: selected ? 0 : 0,
                shadowColor: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: AppRadius.smAll,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : Colors.transparent,
                      borderRadius: AppRadius.smAll,
                      boxShadow: selected ? AppShadows.sm : null,
                    ),
                    child: Text(
                      tabs[i],
                      style: AppTypography.captionStyle.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class SacoGradientBanner extends StatelessWidget {
  const SacoGradientBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, Color(0xFF2D2D44), Color(0xFF8B5E3C)],
        ),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.headlineStyle.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTypography.captionStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class SacoPrimaryButton extends StatelessWidget {
  const SacoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        color: enabled ? null : AppColors.border,
        borderRadius: BorderRadius.circular(compact ? AppRadius.pill : AppRadius.lg),
        boxShadow: enabled ? AppShadows.primaryGlow(opacity: 0.24) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(compact ? AppRadius.pill : AppRadius.lg),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.lg + 2,
              vertical: compact ? AppSpacing.sm : AppSpacing.sm + 2,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.captionStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

/// Web-style label above input (not floating Material label).
class SacoFormField extends StatelessWidget {
  const SacoFormField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTypography.labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

InputDecoration sacoInputDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    labelText: null,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: AppSpacing.sm + 2,
    ),
    border: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    hintStyle: AppTypography.captionStyle.copyWith(color: AppColors.textTertiary),
  );
}
