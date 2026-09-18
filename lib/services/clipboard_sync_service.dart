import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'settings_service.dart';
import 'share_service.dart';

class ClipboardSyncService {
  ClipboardSyncService({
    required this.shareService,
    required this.settings,
  });

  final ShareService shareService;
  final SettingsService settings;

  Timer? _timer;
  String? _lastClipboard;
  bool _busy = false;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (!Platform.isWindows || isRunning || !settings.autoClipboardSync) return;
    _lastClipboard = await _readText();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> restartForSettings() async {
    stop();
    await start();
  }

  Future<void> _poll() async {
    if (_busy) return;
    final value = await _readText();
    if (value == null || value.isEmpty || value == _lastClipboard) return;
    if (value.length > 200000) {
      _lastClipboard = value;
      return;
    }

    _busy = true;
    try {
      if (!await shareService.hasRecentText(value)) {
        await shareService.sendText(value, settings.deviceName);
      }
      _lastClipboard = value;
    } catch (_) {
      // Keep the old marker so a transient network error can retry later.
    } finally {
      _busy = false;
    }
  }

  Future<String?> _readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.trim();
    } catch (_) {
      return null;
    }
  }

  void dispose() => stop();
}
