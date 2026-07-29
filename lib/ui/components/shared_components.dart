import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String dismissText;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '确定',
    this.dismissText = '取消',
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      backgroundColor: cs.surfaceContainerHigh,
      actions: [
        TextButton(onPressed: onDismiss, child: Text(dismissText)),
        TextButton(onPressed: onConfirm, child: Text(confirmText)),
      ],
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Shared top handle used by settings bottom sheets.
class QlSheetHandle extends StatelessWidget {
  const QlSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Consistent outer surface for management pages opened from SettingsScreen.
class QlSettingsSheet extends StatelessWidget {
  final Widget child;
  final double heightFactor;

  const QlSettingsSheet({
    super.key,
    required this.child,
    this.heightFactor = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(28));
    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: AppVisuals.glassSurface(
        context: context,
        blur: 8,
        withShadow: false,
        borderRadius: borderRadius,
        child: SafeArea(
          top: false,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Accent-colored search field shared by settings management pages.
class QlSettingsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const QlSettingsSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: cs.primary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                  icon: const Icon(Icons.clear),
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: cs.onSurfaceVariant.withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: cs.onSurfaceVariant.withAlpha(179)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Consistent empty state for management pages.
class QlEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const QlEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Consistent error state showing the backend message and a retry action.
class QlErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? hint;

  const QlErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = '重试',
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: cs.error),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (hint != null && hint!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// open-reading 风格圆形动作按钮（44x44，surfaceContainer 背景，细边框）
class CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const CircleActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.22),
              width: 0.6,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: onPressed == null ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// open-reading 风格顶部栏（大标题 + 底部细边框 + 右侧操作区）
///
/// 用法：在 Scaffold 中用 PreferredSize 包裹：
/// ```dart
/// appBar: PreferredSize(
///   preferredSize: Size.fromHeight(kToolbarHeight + MediaQuery.of(context).padding.top),
///   child: QlTopBar(title: '标题', trailing: [ ... ]),
/// ),
/// ```
class QlTopBar extends StatelessWidget {
  final String title;
  final List<Widget>? trailing;
  final Widget? leading;

  const QlTopBar({super.key, required this.title, this.trailing, this.leading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    final hasTrailing = trailing != null && trailing!.isNotEmpty;

    final content = Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
      decoration: BoxDecoration(
        color: AppVisuals.glassColor(context),
        border: Border(
          bottom: BorderSide(
            color: cs.outline.withValues(alpha: 0.24),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasTrailing) ...trailing!,
        ],
      ),
    );

    final shouldBlur = AppVisuals.glassEnabled(context);
    return shouldBlur
        ? ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.75, sigmaY: 12.75),
              child: content,
            ),
          )
        : content;
  }
}

/// QlTopBar 右侧统一的圆形强调色操作按钮。
class QlTopBarActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const QlTopBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: cs.primary.withValues(alpha: enabled ? 0.07 : 0.04),
        shape: CircleBorder(
          side: BorderSide(
            color: cs.primary.withValues(alpha: enabled ? 0.24 : 0.14),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: cs.primary.withValues(alpha: enabled ? 1 : 0.42),
            ),
          ),
        ),
      ),
    );
  }
}
