import 'package:flutter/material.dart';
import '../services/download_service.dart';

class SaveDirectorySetting extends StatefulWidget {
  const SaveDirectorySetting({super.key, required this.downloads});
  final DownloadService downloads;

  @override
  State<SaveDirectorySetting> createState() => _SaveDirectorySettingState();
}

class _SaveDirectorySettingState extends State<SaveDirectorySetting> {
  bool _busy = false;
  String? _error;

  Future<void> _choose() async {
    setState(() { _busy = true; _error = null; });
    try {
      await widget.downloads.chooseDirectory();
    } catch (e) {
      if (mounted) setState(() => _error = '选择失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('本机保存目录', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(widget.downloads.directoryLabel, maxLines: 3, overflow: TextOverflow.ellipsis),
      TextButton.icon(onPressed: _busy ? null : _choose,
        icon: const Icon(Icons.folder_open), label: const Text('选择 / 更改文件夹')),
      const Text('选择后立即记住。点击下载时保存到此处，不自动下载；同名文件自动加序号。',
        style: TextStyle(fontSize: 12)),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ],
  );
}
