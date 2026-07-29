import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';

/// 悬浮药丸导航栏 — 仿 open-reading 风格
class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavItem> items;
  final bool enableGlass;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.enableGlass = true,
  });

  @override
  Widget build(BuildContext context) {
    final navHeight = 56.0;
    final borderRadius = BorderRadius.circular(navHeight / 2);
    final itemWidth = 64.0;

    final navBar = Container(
      height: navHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: AppVisuals.glassDecoration(
        context,
        borderRadius: borderRadius,
        withShadow: true,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isSelected = i == selectedIndex;
          return _NavBarItem(
            icon: item.icon,
            selectedIcon: item.selectedIcon,
            label: item.label,
            isSelected: isSelected,
            width: itemWidth,
            onTap: () => onDestinationSelected(i),
          );
        }),
      ),
    );

    final shouldBlur = enableGlass && AppVisuals.glassEnabled(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: shouldBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.75, sigmaY: 12.75),
              child: navBar,
            )
          : navBar,
    );
  }
}

class FloatingNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavBarItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, child) {
          final scale = 1 - (_pressAnimation.value * 0.06);
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: widget.width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? cs.primary.withValues(alpha: isLight ? 0.13 : 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                size: 24,
                color: widget.isSelected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
