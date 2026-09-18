/// Delete only rows whose attachments were successfully removed. Repeatedly
/// fetching the first remaining batch avoids both API row caps and offset skips.
Future<void> clearHistoryBatches({
  required Future<List<Map<String, dynamic>>> Function() loadBatch,
  required Future<void> Function(List<String>) removeObjects,
  required Future<void> Function(List<String>) deleteRows,
}) async {
  String? previousFirstId;
  while (true) {
    final rows = await loadBatch();
    if (rows.isEmpty) return;
    if (rows.first['id'] == previousFirstId) {
      throw StateError('删除未生效，请重新登录后重试');
    }
    previousFirstId = rows.first['id'] as String;
    final paths = rows.map((r) => r['storage_path']).whereType<String>()
        .where((p) => p.isNotEmpty).toList();
    if (paths.isNotEmpty) await removeObjects(paths);
    await deleteRows(rows.map((r) => r['id'] as String).toList());
  }
}
