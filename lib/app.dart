import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/theme_controller.dart';
import 'package:qinglong_flutter/theme/app_theme.dart';
import 'package:qinglong_flutter/ui/screens/main/main_screen.dart';
import 'package:qinglong_flutter/ui/screens/login/login_screen.dart';
import 'data/local/local_storage.dart';

class QingLongApp extends StatefulWidget {
  final LocalStorage? storage;
  final QingLongApi? api;

  const QingLongApp({super.key, this.storage, this.api});
  @override
  State<QingLongApp> createState() => _QingLongAppState();
}

class _QingLongAppState extends State<QingLongApp> {
  late final LocalStorage _storage;
  late final ThemeController _themeController;
  bool _isLoggedIn = false;
  bool _checked = false;
  int _sessionVersion = 0;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? LocalStorage();
    _themeController = ThemeController(_storage);
    _themeController.addListener(_onThemeChange);
    _checkLogin();
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChange);
    _themeController.dispose();
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _checkLogin() async {
    final token = await _storage.getToken();
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _themeController.accentColor;
    final appTheme = AppThemes.fromAccentColor(accent);
    final home = _checked
        ? (_isLoggedIn
              ? MainScreen(
                  key: ValueKey(_sessionVersion),
                  themeController: _themeController,
                  api: widget.api,
                  storage: _storage,
                  onLogout: () => setState(() => _isLoggedIn = false),
                  onAccountChanged: () => setState(() => _sessionVersion++),
                )
              : LoginScreen(
                  api: widget.api,
                  onLoginSuccess: () {
                    setState(() => _isLoggedIn = true);
                  },
                ))
        : const Scaffold(body: Center(child: CircularProgressIndicator()));

    return MaterialApp(
      title: 'QL-Next',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: appTheme.lightColorScheme,
        scaffoldBackgroundColor: appTheme.lightColorScheme.surface,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: appTheme.darkColorScheme,
        scaffoldBackgroundColor: appTheme.darkColorScheme.surface,
      ),
      themeMode: _themeController.themeMode,
      home: ThemeControllerScope(controller: _themeController, child: home),
    );
  }
}
