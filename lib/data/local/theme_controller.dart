import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  final LocalStorage _storage;
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = AppThemes.defaultAccentColor;
  bool _glassEffects = true;

  ThemeController(this._storage) {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get glassEffects => _glassEffects;

  Future<void> _load() async {
    final mode = await _storage.getThemeMode();
    final color = await _storage.getAccentColor();
    final glass = await _storage.getGlassEffects();

    _themeMode = _parseThemeMode(mode);
    _accentColor = Color(color);
    _glassEffects = glass;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.setThemeMode(_themeModeName(mode));
  }

  Future<void> setAccentColor(Color color) async {
    if (_accentColor.toARGB32() == color.toARGB32()) return;
    _accentColor = color;
    notifyListeners();
    await _storage.setAccentColor(color.toARGB32());
  }

  Future<void> setGlassEffects(bool enabled) async {
    if (_glassEffects == enabled) return;
    _glassEffects = enabled;
    notifyListeners();
    await _storage.setGlassEffects(enabled);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Exposes the app-wide appearance controller to reusable UI components.
///
/// This mirrors open-reading's notifier-driven glass configuration: changing
/// the setting immediately rebuilds chrome without manually passing a boolean
/// through every page.
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
        ?.notifier;
  }
}

/// 预设强调色
/// The same accent palette used by open-reading's Material 3 theme builder.
const List<Color> presetAccentColors = AppThemes.accentColors;
