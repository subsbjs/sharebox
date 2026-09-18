import 'package:flutter_test/flutter_test.dart';
import 'package:sharebox/services/clear_history.dart';

void main() {
  test('clears more than 1000 mixed records without skipping attachments', () async {
    final rows = List.generate(1205, (i) => <String, dynamic>{
      'id': '$i', 'storage_path': i % 3 == 0 ? null : 'user/$i.pdf',
    });
    final removed = <String>[];
    final expected = rows.map((r) => r['storage_path']).whereType<String>().toSet();
    var batches = 0;
    await clearHistoryBatches(
      loadBatch: () async => rows.take(100).toList(),
      removeObjects: (paths) async { removed.addAll(paths); },
      deleteRows: (ids) async {
        batches++;
        // No database record disappears before its actual file is removed.
        for (final row in rows.where((r) => ids.contains(r['id']))) {
          if (row['storage_path'] != null) expect(removed, contains(row['storage_path']));
        }
        rows.removeWhere((r) => ids.contains(r['id']));
      },
    );
    expect(rows, isEmpty);
    expect(removed.toSet(), expected);
    expect(batches, 13);
  });

  test('failed storage deletion preserves records for retry', () async {
    var deleted = false;
    await expectLater(clearHistoryBatches(
      loadBatch: () async => [{'id': '1', 'storage_path': 'user/file.zip'}],
      removeObjects: (_) async { throw StateError('offline'); },
      deleteRows: (_) async { deleted = true; },
    ), throwsStateError);
    expect(deleted, isFalse);
  });

  test('stops if deletion did not take effect instead of looping forever', () async {
    await expectLater(clearHistoryBatches(
      loadBatch: () async => [{'id': '1', 'storage_path': null}],
      removeObjects: (_) async {}, deleteRows: (_) async {},
    ), throwsStateError);
  });
}
