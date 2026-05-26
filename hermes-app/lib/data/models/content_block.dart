enum ContentBlockType { text, image, file, code }

class ContentBlock {
  final ContentBlockType type;
  final String? text;
  final String? url;
  final String? name;
  final int? size;
  final String? language;
  final String? mimeType;

  ContentBlock({
    required this.type,
    this.text,
    this.url,
    this.name,
    this.size,
    this.language,
    this.mimeType,
  });

  bool get isText => type == ContentBlockType.text;
  bool get isImage => type == ContentBlockType.image;
  bool get isFile => type == ContentBlockType.file;
  bool get isCode => type == ContentBlockType.code;

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'text';
    ContentBlockType type;
    switch (typeStr) {
      case 'image':
        type = ContentBlockType.image;
        break;
      case 'file':
        type = ContentBlockType.file;
        break;
      case 'code':
        type = ContentBlockType.code;
        break;
      default:
        type = ContentBlockType.text;
    }

    return ContentBlock(
      type: type,
      text: json['text'] as String?,
      url: json['url'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
      language: json['language'] as String?,
      mimeType: json['mime_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (text != null) 'text': text,
      if (url != null) 'url': url,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
      if (language != null) 'language': language,
      if (mimeType != null) 'mime_type': mimeType,
    };
  }
}