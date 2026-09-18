import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/shared_item.dart';

class ShareService {
  ShareService(this.client);

  final SupabaseClient client;
  final Uuid _uuid = const Uuid();

  User get _user {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user;
  }

  Stream<List<SharedItem>> watchItems() {
    final userId = _user.id;
    return client
        .from('shared_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(300)
        .map(
          (rows) => rows
              .map(SharedItem.fromMap)
              .toList(growable: false),
        );
  }

  Future<void> sendText(String text, String deviceName) async {
    final value = text.trim();
    if (value.isEmpty) return;

    await client.from('shared_items').insert({
      'user_id': _user.id,
      'type': 'text',
      'text_content': value,
      'device_name': deviceName,
    });
  }

  Future<void> sendImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String deviceName,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('Image is empty');
    if (bytes.length > AppConfig.maxImageBytes) {
      throw ArgumentError('Image exceeds the 20 MB limit');
    }

    final mimeType = lookupMimeType(
      fileName,
      headerBytes: bytes.length >= 16 ? bytes.sublist(0, 16) : bytes,
    );
    const supportedMimeTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'image/bmp',
    };
    if (mimeType == null || !supportedMimeTypes.contains(mimeType)) {
      throw ArgumentError('Only JPG, PNG, WebP, GIF and BMP images are supported');
    }

    final extension = _safeExtension(fileName);
    final storagePath = '${_user.id}/${_uuid.v4()}$extension';

    await client.storage.from(AppConfig.storageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: mimeType,
            upsert: false,
          ),
        );

    try {
      await client.from('shared_items').insert({
        'user_id': _user.id,
        'type': 'image',
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': bytes.length,
        'device_name': deviceName,
      });
    } catch (_) {
      await client.storage.from(AppConfig.storageBucket).remove([storagePath]);
      rethrow;
    }
  }

  Future<String> createImageUrl(SharedItem item) async {
    final path = item.storagePath;
    if (path == null || path.isEmpty) {
      throw StateError('Missing storage path');
    }
    return client.storage
        .from(AppConfig.storageBucket)
        .createSignedUrl(path, 60 * 60);
  }

  Future<Uint8List> downloadImage(SharedItem item) async {
    final path = item.storagePath;
    if (path == null || path.isEmpty) {
      throw StateError('Missing storage path');
    }
    return client.storage.from(AppConfig.storageBucket).download(path);
  }

  Future<void> deleteItem(SharedItem item) async {
    if (item.isImage && item.storagePath != null) {
      await client.storage.from(AppConfig.storageBucket).remove([
        item.storagePath!,
      ]);
    }
    await client.from('shared_items').delete().eq('id', item.id);
  }

  Future<void> clearAll() async {
    final userId = _user.id;
    final imageRows = await client
        .from('shared_items')
        .select('storage_path')
        .eq('user_id', userId)
        .eq('type', 'image');

    final paths = (imageRows as List)
        .map((row) => (row as Map<String, dynamic>)['storage_path'] as String?)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    for (var i = 0; i < paths.length; i += 100) {
      final end = (i + 100 < paths.length) ? i + 100 : paths.length;
      await client.storage
          .from(AppConfig.storageBucket)
          .remove(paths.sublist(i, end));
    }

    await client.from('shared_items').delete().eq('user_id', userId);
  }

  Future<bool> hasRecentText(String text) async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 10))
        .toIso8601String();

    final rows = await client
        .from('shared_items')
        .select('id')
        .eq('user_id', _user.id)
        .eq('type', 'text')
        .eq('text_content', text)
        .gte('created_at', cutoff)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  String _safeExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    final ext = fileName.substring(dot).toLowerCase();
    if (ext.length > 10 || !RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) {
      return '';
    }
    return ext;
  }
}
