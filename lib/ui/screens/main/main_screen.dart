import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/local/theme_controller.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import '../../components/floating_nav_bar.dart';
import '../tasks/tasks_screen.dart';
import '../env/env_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../config/config_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  final ThemeController themeController;
  final QingLongApi? api;
  final LocalStorage? storage;
  final VoidCallback onLogout;
  final VoidCallback? onAccountChanged;
  const MainScreen({
    super.key,
    required this.themeController,
    this.api,
    this.storage,
    required this.onLogout,
    this.onAccountChanged,
  });
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 2;

  static const _navItems = [
    FloatingNavItem(
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule,
      label: '任务',
    ),
    FloatingNavItem(
      icon: Icons.code_outlined,
      selectedIcon: Icons.code,
      label: '环境',
    ),
    FloatingNavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '仪表',
    ),
    FloatingNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '配置',
    ),
    FloatingNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '设置',
    ),
  ];

  void _handleLogout() {
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AppGradientBackground(
              child: IndexedStack(
                index: _index,
                children: [
                  TasksScreen(api: widget.api),
                  EnvScreen(api: widget.api),
                  DashboardScreen(api: widget.api),
                  ConfigScreen(api: widget.api),
                  SettingsScreen(
                    themeController: widget.themeController,
                    api: widget.api,
                    storage: widget.storage,
                    onLogout: _handleLogout,
                    onAccountChanged: widget.onAccountChanged,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 56 + bottomInset + 10,
              child: Align(
                alignment: Alignment.topCenter,
                child: FloatingNavBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  items: _navItems,
                  enableGlass: widget.themeController.glassEffects,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
