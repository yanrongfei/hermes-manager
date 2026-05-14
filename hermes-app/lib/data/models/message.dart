enum ToolStatus { pending, running, completed, error }

class ToolCall {
  final String id;
  final String tool;
  final String preview;
  final Map<String, dynamic>? arguments;
  ToolStatus status;
  String? output;
  double? duration;
  String? error;

  ToolCall({
    required this.id,
    required this.tool,
    required this.preview,
    this.arguments,
    this.status = ToolStatus.pending,
    this.output,
    this.duration,
    this.error,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['toolCallId'] ?? '',
      tool: json['tool'] ?? '',
      preview: json['preview'] ?? '',
      arguments: json['arguments'],
      output: json['output'],
      duration: (json['duration'] as num?)?.toDouble(),
      error: json['error'],
    );
  }
}

class Message {
  final String id;
  final String roomId;
  final String? senderId;
  final String? senderType; // 'user' or 'agent'
  final String? senderName;
  final String content;
  final String contentType; // 'text', 'image', 'voice'
  final String? extra; // JSON for additional data
  final String? parentId;
  final int createdAt;
  final bool isStreaming;
  final bool isAborted;
  final String? reasoning;
  final int? inputTokens;
  final int? outputTokens;
  final String? error;

  Message({
    required this.id,
    required this.roomId,
    this.senderId,
    this.senderType,
    this.senderName,
    required this.content,
    this.contentType = 'text',
    this.extra,
    this.parentId,
    required this.createdAt,
    this.isStreaming = false,
    this.isAborted = false,
    this.reasoning,
    this.inputTokens,
    this.outputTokens,
    this.error,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderId: json['senderId'] as String?,
      senderType: json['senderType'] as String?,
      senderName: json['senderName'] as String?,
      content: json['content'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'text',
      extra: json['extra'] as String?,
      parentId: json['parentId'] as String?,
      createdAt: json['createdAt'] as int,
      isStreaming: json['isStreaming'] as bool? ?? false,
      isAborted: json['isAborted'] as bool? ?? false,
      reasoning: json['reasoning'],
      inputTokens: json['inputTokens'],
      outputTokens: json['outputTokens'],
      error: json['error'],
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromAgent => senderType == 'agent';

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderType,
    String? senderName,
    String? content,
    String? contentType,
    String? extra,
    String? parentId,
    int? createdAt,
    bool? isStreaming,
    bool? isAborted,
    String? reasoning,
    int? inputTokens,
    int? outputTokens,
    String? error,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      extra: extra ?? this.extra,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      isAborted: isAborted ?? this.isAborted,
      reasoning: reasoning ?? this.reasoning,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      error: error ?? this.error,
    );
  }
}
