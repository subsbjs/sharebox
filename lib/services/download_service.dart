import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

/// Only called by an explicit Save/Download action, never by the sync stream.
class DownloadService {
  DownloadService(this.settings, {bool? android})
      : _android = android ?? Platform.isAndroid;

  final SettingsService settings;
  final bool _android;
  static const _channel = MethodChannel('sharebox/storage');

  String get directoryLabel => settings.saveDirectoryLabel ?? '尚未设置，首次保存时选择';

  Future<bool> chooseDirectory() async {
    if (_android) {
      final chosen = await _channel.invokeMapMethod<String, dynamic>('chooseDirectory');
      if (chosen == null) return false;
      await settings.setSaveDirectory(chosen['uri'] as String, chosen['label'] as String);
    } else {
      final chosen = await FilePicker.getDirectoryPath(dialogTitle: '选择 ShareBox 保存文件夹');
      if (chosen == null) return false;
      await settings.setSaveDirectory(chosen, chosen);
    }
    return true;
  }

  Future<bool> ensureDirectory() async =>
      settings.saveDirectory != null || await chooseDirectory();

  Future<String> save(Uint8List bytes, String fileName, String mimeType) async {
    final directory = settings.saveDirectory;
    if (directory == null) throw StateError('请先在设置中选择保存目录');
    final safeName = safeFileName(fileName);
    if (_android) {
      return (await _channel.invokeMethod<String>('saveFile', {
        'uri': directory,
        'name': safeName,
        'mimeType': mimeType,
        'bytes': bytes,
      }))!;
    }
    return saveInDirectory(directory, safeName, bytes);
  }

  static String safeFileName(String original) {
    var name = original.split(RegExp(r'[/\\]')).last
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '').trim();
    if (name.isEmpty || name == '.' || name == '..') name = 'sharebox-file';
    if (RegExp(r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)', caseSensitive: false).hasMatch(name)) {
      name = '_$name';
    }
    // Keep Unicode scalar boundaries and leave room for collision suffixes.
    if (utf8.encode(name).length > 180) {
      final dot = name.lastIndexOf('.');
      final ext = dot > 0 && name.length - dot <= 16 ? name.substring(dot) : '';
      final base = ext.isEmpty ? name : name.substring(0, dot);
      final out = StringBuffer();
      var length = utf8.encode(ext).length;
      for (final rune in base.runes) {
        final char = String.fromCharCode(rune);
        length += utf8.encode(char).length;
        if (length > 180) break;
        out.write(char);
      }
      name = '$out$ext';
    }
    return name;
  }

  static Future<String> saveInDirectory(String directory, String name, Uint8List bytes) async {
    if (!await Directory(directory).exists()) {
      throw FileSystemException('保存目录不存在，请在设置中重新选择', directory);
    }
    final safe = safeFileName(name);
    final dot = safe.lastIndexOf('.');
    final base = dot > 0 ? safe.substring(0, dot) : safe;
    final ext = dot > 0 ? safe.substring(dot) : '';
    for (var i = 0; i < 10000; i++) {
      final candidate = i == 0 ? safe : '$base ($i)$ext';
      final file = File('$directory${Platform.pathSeparator}$candidate');
      try {
        await file.create(exclusive: true);
      } on PathExistsException {
        continue;
      }
      try {
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (_) {
        try { await file.delete(); } catch (_) { /* Preserve the original error. */ }
        rethrow;
      }
    }
    throw FileSystemException('同名文件过多，请更换保存目录', directory);
  }
}
