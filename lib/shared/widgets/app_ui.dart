import 'package:flutter/material.dart';

import '../../core/design/design_system.dart';

/// Premium surface card — white, soft shadow, 20px radius.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: showShadow ? AppShadows.sm : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: content,
      ),
    );
  }
}

/// Section title + optional subtitle + trailing action.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headlineStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTypography.bodyStyle),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Modern empty / placeholder state.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppTypography.titleStyle),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!, textAlign: TextAlign.center, style: AppTypography.bodyStyle),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered loading indicator with optional message.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: AppTypography.captionStyle),
          ],
        ],
      ),
    );
  }
}

/// Fade-in wrapper for list items / sections.
class AppFadeIn extends StatefulWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
