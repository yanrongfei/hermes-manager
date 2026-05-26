import 'dart:convert';
import 'attachment.dart';
import 'content_block.dart';

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
  final List<Attachment>? attachments;
  final List<ContentBlock>? contentBlocks;
  final bool? isHighlighted;
  final bool? isCommand;

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
    this.attachments,
    this.contentBlocks,
    this.isHighlighted,
    this.isCommand,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    String? reasoning;
    if (json['reasoning'] != null) {
      reasoning = json['reasoning'] as String?;
    } else if (json['extra'] != null) {
      try {
        final extraJson = jsonDecode(json['extra'] as String) as Map<String, dynamic>;
        // Try both 'reasoning' and 'reasoning_content' field names
        reasoning = (extraJson['reasoning'] ?? extraJson['reasoning_content']) as String?;
      } catch (_) {}
    }

    List<Attachment>? attachments;
    List<ContentBlock>? contentBlocks;
    if (json['extra'] != null) {
      try {
        final extraJson = jsonDecode(json['extra'] as String);
        if (extraJson is Map<String, dynamic>) {
          if (extraJson['attachments'] != null) {
            attachments = (extraJson['attachments'] as List)
                .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
                .toList();
          }
          if (extraJson['content_blocks'] != null) {
            contentBlocks = (extraJson['content_blocks'] as List)
                .map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (_) {}
    }

    return Message(
      id: json['id'] as String,
      roomId: (json['roomId'] ?? json['room_id']) as String,
      senderId: (json['senderId'] ?? json['sender_id']) as String?,
      senderType: (json['senderType'] ?? json['sender_type']) as String?,
      senderName: (json['senderName'] ?? json['sender_name']) as String?,
      content: (json['content'] as String?) ?? '',
      contentType: (json['contentType'] ?? json['content_type']) as String? ?? 'text',
      extra: json['extra'] as String?,
      parentId: (json['parentId'] ?? json['parent_id']) as String?,
      createdAt: (json['createdAt'] ?? json['created_at']) as int,
      isStreaming: (json['isStreaming'] ?? json['is_streaming']) as bool? ?? false,
      isAborted: (json['isAborted'] ?? json['is_aborted']) as bool? ?? false,
      reasoning: reasoning,
      inputTokens: json['inputTokens'] ?? json['input_tokens'],
      outputTokens: json['outputTokens'] ?? json['output_tokens'],
      error: json['error'],
      attachments: attachments,
      contentBlocks: contentBlocks,
      isHighlighted: json['is_highlighted'] as bool? ?? json['isHighlighted'] as bool?,
      isCommand: json['is_command'] as bool? ?? json['isCommand'] as bool?,
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromAgent => senderType == 'agent';
  bool get isCommandMessage => isCommand == true || (content.startsWith('/') && isFromUser);
  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;
  bool get hasContentBlocks => contentBlocks != null && contentBlocks!.isNotEmpty;

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
    List<Attachment>? attachments,
    List<ContentBlock>? contentBlocks,
    bool? isHighlighted,
    bool? isCommand,
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
      attachments: attachments ?? this.attachments,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isCommand: isCommand ?? this.isCommand,
    );
  }
}
