import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._(this._prefs);

  static const _deviceNameKey = 'device_name';
  static const _autoClipboardKey = 'auto_clipboard_sync';

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  String get deviceName {
    final saved = _prefs.getString(_deviceNameKey)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    if (Platform.isWindows) return 'Windows-PC';
    if (Platform.isAndroid) return 'Android-Phone';
    return 'ShareBox-Device';
  }

  bool get autoClipboardSync =>
      Platform.isWindows && (_prefs.getBool(_autoClipboardKey) ?? false);

  Future<void> setDeviceName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    await _prefs.setString(_deviceNameKey, trimmed);
  }

  Future<void> setAutoClipboardSync(bool value) async {
    await _prefs.setBool(_autoClipboardKey, value);
  }
}
