import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sharebox/services/download_service.dart';
import 'package:sharebox/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sharebox/storage');

  test('manual saves keep originals and select distinct names even concurrently', () async {
    final dir = await Directory.systemTemp.createTemp('sharebox-save-');
    try {
      final original = File('${dir.path}/report.pdf');
      await original.writeAsString('original');
      final paths = await Future.wait(List.generate(4, (i) =>
          DownloadService.saveInDirectory(dir.path, 'report.pdf', Uint8List.fromList([i]))));
      expect(paths.toSet().length, 4);
      expect(await original.readAsString(), 'original');
      for (var i = 0; i < paths.length; i++) {
        expect(await File(paths[i]).readAsBytes(), [i]);
      }
      final escaped = await DownloadService.saveInDirectory(
          dir.path, '../../outside.txt', Uint8List.fromList([42]));
      expect(File(escaped).parent.path, dir.path);
      expect(DownloadService.safeFileName('CON.txt'), '_CON.txt');
    } finally { await dir.delete(recursive: true); }
  });

  test('missing directory errors without silently saving elsewhere', () async {
    final dir = await Directory.systemTemp.createTemp('sharebox-missing-');
    await dir.delete();
    await expectLater(DownloadService.saveInDirectory(dir.path, 'a.txt', Uint8List(0)),
      throwsA(isA<FileSystemException>()));
  });

  test('Android directory survives reload; selection never writes or downloads', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'chooseDirectory') {
        return {'uri': 'content://documents/tree/primary:Documents/ShareBox', 'label': 'Documents/ShareBox'};
      }
      return 'notes.txt';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final downloads = DownloadService(await SettingsService.load(), android: true);
    expect(await downloads.chooseDirectory(), isTrue);
    expect(calls.map((c) => c.method), ['chooseDirectory']);
    final reloaded = DownloadService(await SettingsService.load(), android: true);
    expect(reloaded.directoryLabel, 'Documents/ShareBox');
    expect(await reloaded.ensureDirectory(), isTrue);
    expect(calls.length, 1);
    await reloaded.save(Uint8List.fromList([65]), 'notes.txt', 'text/plain');
    expect(calls.last.method, 'saveFile');
    expect(calls.last.arguments['uri'], 'content://documents/tree/primary:Documents/ShareBox');
    expect(calls.last.arguments['bytes'], [65]);
  });

  test('cancelling directory choice leaves existing folder intact', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await settings.setSaveDirectory('content://old', 'Old folder');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    expect(await DownloadService(settings, android: true).chooseDirectory(), isFalse);
    expect(settings.saveDirectory, 'content://old');
  });
}
