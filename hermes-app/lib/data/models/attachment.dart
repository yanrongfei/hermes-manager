class Attachment {
  final String id;
  final String type; // 'image', 'file'
  final String name;
  final String? url;
  final int? size;
  final String? thumbnailUrl;
  final String? mimeType;
  final String? localPath;

  Attachment({
    required this.id,
    required this.type,
    required this.name,
    this.url,
    this.size,
    this.thumbnailUrl,
    this.mimeType,
    this.localPath,
  });

  bool get isImage => type == 'image';
  bool get isFile => type == 'file';

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      name: json['name'] as String? ?? 'unknown',
      url: json['url'] as String?,
      size: json['size'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      mimeType: json['mime_type'] as String?,
      localPath: json['local_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      if (url != null) 'url': url,
      if (size != null) 'size': size,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (localPath != null) 'local_path': localPath,
    };
  }

  Attachment copyWith({
    String? id,
    String? type,
    String? name,
    String? url,
    int? size,
    String? thumbnailUrl,
    String? mimeType,
    String? localPath,
  }) {
    return Attachment(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      url: url ?? this.url,
      size: size ?? this.size,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
    );
  }
}