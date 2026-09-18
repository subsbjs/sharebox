import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/shared_item.dart';
import '../services/clipboard_sync_service.dart';
import '../services/settings_service.dart';
import '../services/share_service.dart';
import '../services/download_service.dart';
import '../widgets/save_directory_setting.dart';
import '../widgets/shared_item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  late final ShareService _shareService;
  late final DownloadService _downloads;
  late final ClipboardSyncService _clipboardSync;
  late final Stream<List<SharedItem>> _itemsStream;

  bool _sending = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _shareService = ShareService(Supabase.instance.client);
    _downloads = DownloadService(widget.settings);
    _itemsStream = _shareService.watchItems();
    _clipboardSync = ClipboardSyncService(
      shareService: _shareService,
      settings: widget.settings,
    );
    _clipboardSync.start();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _clipboardSync.dispose();
    _messageController.dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendText() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _shareService.sendText(text, widget.settings.deviceName);
      _messageController.clear();
    } catch (e) {
      _snack('发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment({bool imageOnly = false}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final file = await FilePicker.pickFile(type: imageOnly ? FileType.image : FileType.any);
      if (file == null) return;
      final limit = imageOnly ? AppConfig.maxImageBytes : AppConfig.maxFileBytes;
      if ((await file.length() ?? 0) > limit) {
        throw ArgumentError(imageOnly ? '图片不能超过 20 MB' : '文件不能超过 50 MB');
      }
      final bytes = await file.readAsBytes();
      await _shareService.sendAttachment(bytes: bytes, fileName: file.name,
          deviceName: widget.settings.deviceName, imageOnly: imageOnly);
      _snack('已发送');
    } catch (e) {
      _snack('发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleDroppedFiles(DropDoneDetails detail) async {
    if (!Platform.isWindows || _sending) return;
    setState(() => _sending = true);
    try {
      for (final file in detail.files.take(10)) {
        try {
          if (await file.length() > AppConfig.maxFileBytes) {
            throw ArgumentError('文件不能超过 50 MB');
          }
          await _shareService.sendAttachment(bytes: Uint8List.fromList(await file.readAsBytes()),
              fileName: file.name, deviceName: widget.settings.deviceName);
          _snack('${file.name} 已发送');
        } catch (e) {
          _snack('${file.name} 上传失败：$e');
        }
      }
      if (detail.files.length > 10) _snack('每次最多发送 10 个文件，其余文件请再次拖入');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteItem(SharedItem item) async {
    try {
      await _shareService.deleteItem(item);
    } catch (e) {
      _snack('删除失败：$e');
    }
  }

  Future<void> _openSettings() async {
    final nameController = TextEditingController(text: widget.settings.deviceName);
    var clipboard = widget.settings.autoClipboardSync;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('设置'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '设备名称',
                    helperText: '历史记录里会显示此名称',
                  ),
                ),
                const SizedBox(height: 16),
                SaveDirectorySetting(downloads: _downloads),
                if (Platform.isWindows) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动同步 Windows 文本剪贴板'),
                    subtitle: const Text('仅运行期间生效，关闭窗口即退出进程。'),
                    value: clipboard,
                    onChanged: (value) => setDialogState(() => clipboard = value),
                  ),
                ],
              ],
            )),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      await widget.settings.setDeviceName(nameController.text);
      if (Platform.isWindows) {
        await widget.settings.setAutoClipboardSync(clipboard);
        await _clipboardSync.restartForSettings();
      }
      if (mounted) setState(() {});
    }
    nameController.dispose();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部历史？'),
        content: const Text('此刻之前的文字、图片、文件及其云端原文件都会被删除。本机已下载文件不受影响，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _shareService.clearAll();
      _snack('历史记录已清空');
    } catch (e) {
      _snack('清空失败：$e');
    }
  }

  bool _matchesSearch(SharedItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return (item.textContent ?? '').toLowerCase().contains(query) ||
        (item.fileName ?? '').toLowerCase().contains(query) ||
        item.deviceName.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildHistory()),
        _buildComposer(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            const Icon(Icons.sync_alt_rounded),
            const SizedBox(width: 10),
            const Text('ShareBox', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.settings.deviceName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '清空历史',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Platform.isWindows
            ? DropTarget(
                onDragDone: _handleDroppedFiles,
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                child: Stack(
                  children: [
                    content,
                    if (_dragging)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.92),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 64),
                                SizedBox(height: 12),
                                Text(
                                  '松开即可发送图片或文件',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : content,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索文字、图片名称或设备名称',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return StreamBuilder<List<SharedItem>>(
      stream: _itemsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                '同步失败，请检查网络后重新打开应用。\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.where(_matchesSearch).toList(growable: false);
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 62,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.trim().isEmpty
                        ? '还没有内容\n从下面发送文字、图片或文件'
                        : '没有找到匹配内容',
                    textAlign: TextAlign.center,
                  ),
                  if (Platform.isWindows && _searchController.text.trim().isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('也可以把图片、PDF、文档等直接拖进窗口'),
                  ],
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              itemCount: items.length,
              itemBuilder: (context, index) => SharedItemCard(
                key: ValueKey(items[index].id),
                item: items[index],
                service: _shareService,
                downloads: _downloads,
                onDelete: _deleteItem,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton.filledTonal(
                  tooltip: '发送图片',
                  onPressed: _sending ? null : () => _pickAttachment(imageOnly: true),
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  tooltip: '发送文件（最大 50 MB）',
                  onPressed: _sending ? null : () => _pickAttachment(),
                  icon: const Icon(Icons.attach_file),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '输入要同步到另一台设备的文字…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: '发送文字',
                  onPressed: _sending ? null : _sendText,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
