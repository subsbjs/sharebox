import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shared_item.dart';
import '../services/share_service.dart';
import '../utils/formatters.dart';

class SharedItemCard extends StatefulWidget {
  const SharedItemCard({
    super.key,
    required this.item,
    required this.service,
    required this.onDelete,
  });

  final SharedItem item;
  final ShareService service;
  final Future<void> Function(SharedItem item) onDelete;

  @override
  State<SharedItemCard> createState() => _SharedItemCardState();
}

class _SharedItemCardState extends State<SharedItemCard> {
  Future<String>? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isImage) {
      _imageUrl = widget.service.createImageUrl(widget.item);
    }
  }

  @override
  void didUpdateWidget(covariant SharedItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.storagePath != widget.item.storagePath && widget.item.isImage) {
      _imageUrl = widget.service.createImageUrl(widget.item);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyText() async {
    final text = widget.item.textContent ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('已复制到剪贴板');
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await widget.service.downloadImage(widget.item);
      final result = await FilePicker.saveFile(
        dialogTitle: '保存图片',
        fileName: widget.item.fileName ?? 'sharebox-image.jpg',
        bytes: bytes,
      );
      if (result != null) _snack('图片已保存');
    } catch (e) {
      _snack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后会从 Windows、Android 和云端历史中同时移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(widget.item);
  }

  void _showImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.92,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isText ? Icons.notes_rounded : Icons.image_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  formatDateTime(item.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.isText) ...[
              SelectableText(
                item.textContent ?? '',
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('复制'),
                ),
              ),
            ] else ...[
              FutureBuilder<String>(
                future: _imageUrl,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: Text('图片暂时无法加载')),
                    );
                  }
                  return InkWell(
                    onTap: () => _showImage(snapshot.data!),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: Image.network(
                          snapshot.data!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 140,
                            child: Center(child: Text('图片加载失败，可能需要刷新')), 
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.fileName ?? '图片'}  ${formatBytes(item.fileSize)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _saveImage,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
