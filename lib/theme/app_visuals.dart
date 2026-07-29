import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/local/theme_controller.dart';

/// Shared page surfaces inspired by open-reading's Material 3 visual system.
///
/// The palette is derived from the active ColorScheme so theme mode and the
/// configured accent color continue to affect the background automatically.
class AppVisualPalette {
  const AppVisualPalette({
    required this.backgroundStart,
    required this.backgroundMiddle,
    required this.backgroundEnd,
    required this.card,
    required this.cardStrong,
    required this.border,
    required this.textMuted,
  });

  final Color backgroundStart;
  final Color backgroundMiddle;
  final Color backgroundEnd;
  final Color card;
  final Color cardStrong;
  final Color border;
  final Color textMuted;
}

class AppVisuals {
  AppVisuals._();

  static bool glassEnabled(BuildContext context) {
    return ThemeControllerScope.maybeOf(context)?.glassEffects ?? true;
  }

  static AppVisualPalette palette(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enabled = glassEnabled(context);

    return AppVisualPalette(
      backgroundStart: Color.alphaBlend(
        scheme.surfaceContainer.withValues(alpha: isDark ? 0.82 : 0.92),
        scheme.surface,
      ),
      backgroundMiddle: Color.alphaBlend(
        scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.78 : 0.90),
        scheme.surface,
      ),
      backgroundEnd: scheme.surface,
      // Glass mode deliberately uses a deeper card layer than the gradient
      // below it. The solid mode keeps cards opaque and predictable.
      card: enabled
          ? scheme.surfaceContainer.withValues(alpha: isDark ? 0.96 : 0.98)
          : scheme.surfaceContainer,
      cardStrong: enabled
          ? scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.98 : 1.0)
          : scheme.surfaceContainerHigh,
      border: scheme.outline.withValues(alpha: isDark ? 0.36 : 0.24),
      textMuted: scheme.onSurfaceVariant.withValues(
        alpha: isDark ? 0.84 : 0.72,
      ),
    );
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    final p = palette(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      colors: [p.backgroundStart, p.backgroundMiddle, p.backgroundEnd],
    );
  }

  static Color glassColor(BuildContext context, {double? opacity}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final enabled = glassEnabled(context);
    if (!enabled) return scheme.surface;

    final source = Color.lerp(
      scheme.surface,
      scheme.primary,
      isDark ? 0.06 : 0.08,
    )!;
    return source.withValues(
      alpha: enabled ? (opacity ?? (isDark ? 0.30 : 0.60)) : 1.0,
    );
  }

  static BoxDecoration glassDecoration(
    BuildContext context, {
    BorderRadius? borderRadius,
    double? opacity,
    bool withShadow = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      color: glassColor(context, opacity: opacity),
      borderRadius: borderRadius,
      border: Border.all(
        color: scheme.outline.withValues(alpha: isDark ? 0.14 : 0.10),
        width: 0.6,
      ),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ]
          : const [],
    );
  }

  static Widget glassSurface({
    required BuildContext context,
    required Widget child,
    BorderRadius? borderRadius,
    bool enabled = true,
    double blur = 14,
    double? opacity,
    bool withShadow = false,
  }) {
    final surface = DecoratedBox(
      decoration: glassDecoration(
        context,
        borderRadius: borderRadius,
        opacity: opacity,
        withShadow: withShadow,
      ),
      child: child,
    );

    if (!enabled || !glassEnabled(context) || blur <= 0) {
      return borderRadius == null
          ? surface
          : ClipRRect(borderRadius: borderRadius, child: surface);
    }

    final filtered = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: surface,
    );
    return borderRadius == null
        ? ClipRect(child: filtered)
        : ClipRRect(borderRadius: borderRadius, child: filtered);
  }
}

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppVisuals.glassEnabled(context)) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppVisuals.backgroundGradient(context),
      ),
      child: child,
    );
  }
}
