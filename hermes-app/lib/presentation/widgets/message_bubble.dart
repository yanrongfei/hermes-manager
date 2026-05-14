import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final List<ToolCall>? toolCalls;

  const MessageBubble({
    super.key,
    required this.message,
    this.toolCalls,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final agentName = message.senderName ?? 'Agent';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender row for agents
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 2),
              child: Row(
                children: [
                  Text(
                    agentName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (message.isStreaming) ...[
                    const SizedBox(width: 6),
                    const _StreamingDot(),
                  ],
                ],
              ),
            ),
          ],

          // Bubble row
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _AgentAvatar(name: agentName),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: _BubbleContent(message: message),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const _UserAvatar(),
              ],
            ],
          ),

          // Tool Calls
          if (toolCalls != null && toolCalls!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...toolCalls!.map((tc) => _ToolCallCard(toolCall: tc)),
          ],

          // Reasoning/Thinking collapsible
          if (message.reasoning != null && message.reasoning!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ReasoningCard(reasoning: message.reasoning!),
          ],

          // Usage stats
          if (message.inputTokens != null || message.outputTokens != null) ...[
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 48,
                right: isUser ? 48 : 0,
                top: 2,
              ),
              child: Text(
                '${message.inputTokens ?? 0} in / ${message.outputTokens ?? 0} out',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],

          // Error/aborted
          if (message.error != null || (message.isAborted ?? false)) ...[
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 48,
                right: isUser ? 48 : 0,
                top: 2,
              ),
              child: Text(
                message.isAborted == true ? '已中止' : '错误: ${message.error}',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreamingDot extends StatefulWidget {
  const _StreamingDot();

  @override
  State<_StreamingDot> createState() => _StreamingDotState();
}

class _StreamingDotState extends State<_StreamingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.5 + 0.5 * _controller.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  final String name;

  const _AgentAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF5856D6),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFF10A37F),
      child: Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  final Message message;

  const _BubbleContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final isStreaming = message.isStreaming;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF543EBE) : const Color(0xFF343541),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFFECECEC),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          if (isStreaming)
            const _StreamingCursor(),
        ],
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            color: Colors.grey[400],
          ),
        );
      },
    );
  }
}

class _ToolCallCard extends StatefulWidget {
  final ToolCall toolCall;

  const _ToolCallCard({required this.toolCall});

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tc = widget.toolCall;
    final isRunning = tc.status == ToolStatus.running;
    final isDone = tc.status == ToolStatus.completed;
    final isError = tc.status == ToolStatus.error;

    return Container(
      margin: const EdgeInsets.only(left: 48, top: 4),
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_toolIcon(tc.tool), size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      tc.tool,
                      style: const TextStyle(
                        color: Color(0xFFECECEC),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isRunning) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tc.preview,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (isDone) ...[
                      Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
                      const SizedBox(width: 4),
                      if (tc.duration != null)
                        Text(
                          '${tc.duration!.toStringAsFixed(1)}s',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                    ] else if (isError) ...[
                      Icon(Icons.error, size: 14, color: Colors.red[400]),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFF3A3A3A)),
                  const SizedBox(height: 8),
                  if (tc.arguments != null) ...[
                    _JsonView(label: 'Arguments', data: tc.arguments!),
                    const SizedBox(height: 8),
                  ],
                  if (tc.output != null) ...[
                    _JsonView(label: 'Result', data: tc.output!),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _toolIcon(String tool) {
    final name = tool.toLowerCase();
    if (name.contains('read') || name.contains('file')) {
      return Icons.description_outlined;
    }
    if (name.contains('write') || name.contains('save')) {
      return Icons.save_outlined;
    }
    if (name.contains('search')) return Icons.search;
    if (name.contains('bash') || name.contains('shell') || name.contains('exec')) {
      return Icons.terminal;
    }
    if (name.contains('web') || name.contains('fetch')) return Icons.language;
    return Icons.build_outlined;
  }
}

class _JsonView extends StatelessWidget {
  final String label;
  final dynamic data;

  const _JsonView({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    String text;
    if (data is String) {
      text = data;
    } else {
      try {
        text = const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        text = data.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFA0A0A0),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasoningCard extends StatefulWidget {
  final String reasoning;

  const _ReasoningCard({required this.reasoning});

  @override
  State<_ReasoningCard> createState() => _ReasoningCardState();
}

class _ReasoningCardState extends State<_ReasoningCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 48, top: 4),
      child: Material(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 14, color: Colors.purple[300]),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _expanded ? '收起思考过程' : '思考中: ${_truncate(widget.reasoning)}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncate(String text) {
    final lines = text.split('\n').take(2).join(' ');
    return lines.length > 80 ? '${lines.substring(0, 80)}...' : lines;
  }
}
