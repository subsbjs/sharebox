enum SharedItemType { text, image }

class SharedItem {
  const SharedItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.deviceName,
    required this.createdAt,
    this.textContent,
    this.storagePath,
    this.fileName,
    this.mimeType,
    this.fileSize,
  });

  final String id;
  final String userId;
  final SharedItemType type;
  final String deviceName;
  final DateTime createdAt;
  final String? textContent;
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;

  bool get isText => type == SharedItemType.text;
  bool get isImage => type == SharedItemType.image;

  factory SharedItem.fromMap(Map<String, dynamic> map) {
    return SharedItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: (map['type'] as String) == 'image'
          ? SharedItemType.image
          : SharedItemType.text,
      deviceName: (map['device_name'] as String?)?.trim().isNotEmpty == true
          ? map['device_name'] as String
          : 'Unknown device',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      textContent: map['text_content'] as String?,
      storagePath: map['storage_path'] as String?,
      fileName: map['file_name'] as String?,
      mimeType: map['mime_type'] as String?,
      fileSize: (map['file_size'] as num?)?.toInt(),
    );
  }
}
