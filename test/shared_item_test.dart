import 'package:flutter_test/flutter_test.dart';
import 'package:sharebox/models/shared_item.dart';
import 'package:sharebox/utils/formatters.dart';

void main() {
  test('SharedItem parses a text row', () {
    final item = SharedItem.fromMap({
      'id': 'item-1',
      'user_id': 'user-1',
      'type': 'text',
      'text_content': 'hello',
      'device_name': 'Windows-PC',
      'created_at': '2026-09-18T06:00:00Z',
      'storage_path': null,
      'file_name': null,
      'mime_type': null,
      'file_size': null,
    });

    expect(item.isText, isTrue);
    expect(item.textContent, 'hello');
    expect(item.deviceName, 'Windows-PC');
  });

  test('ordinary file stays a file and preserves metadata', () {
    final item = SharedItem.fromMap({
      'id': 'file-1', 'user_id': 'user-1', 'type': 'file',
      'created_at': '2026-09-18T06:00:00Z', 'file_name': '报告.pdf',
      'storage_path': 'user-1/a.pdf', 'mime_type': 'application/pdf', 'file_size': 123,
    });
    expect(item.isFile, isTrue);
    expect(item.isText, isFalse);
    expect(item.isImage, isFalse);
    expect(item.fileName, '报告.pdf');
  });

  test('formatBytes formats common sizes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(2 * 1024 * 1024), '2.0 MB');
  });
}
