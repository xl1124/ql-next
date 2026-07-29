import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../../theme/app_theme.dart';

class LocalStorage {
  static const _keyServerUrl = 'server_url';
  static const _keyToken = 'token';
  static const _keyUsername = 'username';
  static const _keyAccounts = 'accounts';
  static const _secureTokenKey = 'auth_token';
  static const _secureAccountsKey = 'saved_accounts';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  Future<String?> getToken() async {
    final secureToken = await _secure.read(key: _secureTokenKey);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    // Migrate tokens written by older versions out of SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_keyToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secure.write(key: _secureTokenKey, value: legacyToken);
      await prefs.remove(_keyToken);
    }
    return legacyToken;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  Future<void> saveLoginInfo(
    String serverUrl,
    String token,
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // 保存当前账号前先把旧的存到账号列表
    final oldServer = prefs.getString(_keyServerUrl);
    final oldToken = await getToken();
    final oldUsername = prefs.getString(_keyUsername);
    if (oldServer != null &&
        oldServer.isNotEmpty &&
        oldToken != null &&
        oldToken.isNotEmpty) {
      await _saveAccount(
        prefs,
        AccountEntry(
          server: oldServer,
          token: oldToken,
          username: oldUsername ?? '',
        ),
      );
    }
    // 设置当前账号
    await prefs.setString(_keyServerUrl, serverUrl);
    await _secure.write(key: _secureTokenKey, value: token);
    await prefs.remove(_keyToken);
    await prefs.setString(_keyUsername, username);
    // 保存当前账号到列表
    await _saveAccount(
      prefs,
      AccountEntry(server: serverUrl, token: token, username: username),
    );
  }

  Future<void> clearLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    await _secure.delete(key: _secureTokenKey);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
  }

  Future<void> updateCurrentUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);

    final server = prefs.getString(_keyServerUrl) ?? '';
    final token = await getToken() ?? '';
    if (server.isEmpty || token.isEmpty) return;

    final accounts = await _loadAccounts(prefs);
    final index = accounts.indexWhere(
      (account) => account.server == server && account.token == token,
    );
    if (index < 0) return;
    accounts[index] = AccountEntry(
      server: server,
      token: token,
      username: username,
    );
    await _secure.write(
      key: _secureAccountsKey,
      value: jsonEncode(accounts.map((entry) => entry.toJson()).toList()),
    );
    await prefs.remove(_keyAccounts);
  }

  // ==== Multi-Account ====

  Future<List<AccountEntry>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadAccounts(prefs);
  }

  Future<AccountEntry?> getCurrentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString(_keyServerUrl) ?? '';
    final token = await getToken() ?? '';
    if (server.isEmpty || token.isEmpty) return null;
    return AccountEntry(
      server: server,
      token: token,
      username: prefs.getString(_keyUsername) ?? '',
    );
  }

  Future<void> switchAccount(AccountEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    // 保存当前账号
    final curServer = prefs.getString(_keyServerUrl);
    final curToken = await getToken();
    final curUsername = prefs.getString(_keyUsername);
    if (curServer != null &&
        curServer.isNotEmpty &&
        curToken != null &&
        curToken.isNotEmpty) {
      await _saveAccount(
        prefs,
        AccountEntry(
          server: curServer,
          token: curToken,
          username: curUsername ?? '',
        ),
      );
    }
    // 切换到目标账号
    await prefs.setString(_keyServerUrl, entry.server);
    await _secure.write(key: _secureTokenKey, value: entry.token);
    await prefs.remove(_keyToken);
    await prefs.setString(_keyUsername, entry.username);
    // 从列表中移除已被选中的
    await _removeAccount(prefs, entry);
  }

  Future<void> removeAccount(AccountEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await _removeAccount(prefs, entry);
  }

  Future<void> _saveAccount(SharedPreferences prefs, AccountEntry entry) async {
    final accounts = await _loadAccounts(prefs);
    final idx = accounts.indexWhere(
      (a) => a.server == entry.server && a.username == entry.username,
    );
    if (idx >= 0) {
      accounts[idx] = entry;
    } else {
      accounts.add(entry);
    }
    await _secure.write(
      key: _secureAccountsKey,
      value: jsonEncode(accounts.map((e) => e.toJson()).toList()),
    );
    await prefs.remove(_keyAccounts);
  }

  Future<void> _removeAccount(
    SharedPreferences prefs,
    AccountEntry entry,
  ) async {
    final accounts = await _loadAccounts(prefs);
    accounts.removeWhere(
      (a) => a.server == entry.server && a.username == entry.username,
    );
    await _secure.write(
      key: _secureAccountsKey,
      value: jsonEncode(accounts.map((e) => e.toJson()).toList()),
    );
    await prefs.remove(_keyAccounts);
  }

  Future<String> getThemeMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('theme_mode') ?? 'system';
  }

  Future<void> setThemeMode(String m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', m);
  }

  Future<int> getAccentColor() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('accent_color') ?? AppThemes.defaultAccentColor.toARGB32();
  }

  Future<void> setAccentColor(int c) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('accent_color', c);
  }

  Future<bool> getGlassEffects() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('glass_effects') ?? true;
  }

  Future<void> setGlassEffects(bool e) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('glass_effects', e);
  }

  Future<List<AccountEntry>> _loadAccounts(SharedPreferences prefs) async {
    var jsonStr = await _secure.read(key: _secureAccountsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      // Migrate the old account list, which included plaintext tokens.
      jsonStr = prefs.getString(_keyAccounts);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        await _secure.write(key: _secureAccountsKey, value: jsonStr);
        await prefs.remove(_keyAccounts);
      }
    }
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => AccountEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
