import 'dart:io';
import 'dart:convert';

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

  Map<String, dynamic>? get _savedDirectory {
    final raw = _prefs.getString('save_directory_v1');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  String? get saveDirectory => _savedDirectory?['path'] as String?;
  String? get saveDirectoryLabel => _savedDirectory?['label'] as String?;

  Future<void> setSaveDirectory(String path, String label) async {
    final ok = await _prefs.setString('save_directory_v1', jsonEncode({'path': path, 'label': label}));
    if (!ok) throw StateError('无法记住保存目录，请重试');
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
