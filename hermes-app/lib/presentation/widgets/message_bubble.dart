import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final List<ToolCall>? toolCalls;
  final int? thinkingDurationMs;
  final VoidCallback? onQuote;

  const MessageBubble({
    super.key,
    required this.message,
    this.toolCalls,
    this.thinkingDurationMs,
    this.onQuote,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final agentName = message.senderName ?? 'Agent';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Agent name label
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 2),
              child: Row(
                children: [
                  Text(agentName, style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                  if (message.isStreaming) ...[
                    const SizedBox(width: 6),
                    const _StreamingDots(size: 4),
                  ],
                ],
              ),
            ),

          // Bubble row
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _Avatar(name: agentName, isAgent: true),
                const SizedBox(width: 8),
              ],
              Flexible(child: _BubbleContent(message: message)),
              if (isUser) ...[
                const SizedBox(width: 8),
                const _Avatar(name: '', isAgent: false),
              ],
            ],
          ),

          // Tool Calls inline
          if (toolCalls != null && toolCalls!.isNotEmpty)
            ...toolCalls!.map((tc) => _ToolCallLine(toolCall: tc)),

          // Reasoning/Thinking
          if (message.reasoning != null && message.reasoning!.isNotEmpty)
            _ThinkingBlock(reasoning: message.reasoning!, durationMs: thinkingDurationMs),

          // Meta bar: copy, time, tokens
          _MessageMeta(message: message, onQuote: onQuote),

          // Error
          if (message.error != null)
            _ErrorCard(error: message.error!),
          if (message.isAborted == true)
            _AbortCard(),
        ],
      ),
    );
  }
}

// --- Avatar ---

class _Avatar extends StatelessWidget {
  final String name;
  final bool isAgent;
  const _Avatar({required this.name, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isAgent ? const Color(0xFF5856D6) : const Color(0xFF10A37F),
      child: isAgent
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
          : const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}

// --- Bubble Content ---

class _BubbleContent extends StatelessWidget {
  final Message message;
  const _BubbleContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF543EBE) : const Color(0xFF343541),
        borderRadius: BorderRadius.circular(16),
      ),
      child: message.content.isEmpty && message.isStreaming
          ? const _StreamingDots(size: 6)
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: isUser
                      ? SelectableText(message.content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5))
                      : _MarkdownContent(content: message.content),
                ),
                if (message.isStreaming) const _StreamingCursor(),
              ],
            ),
    );
  }
}

// --- Markdown ---

class _MarkdownContent extends StatelessWidget {
  final String content;
  const _MarkdownContent({required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: Color(0xFFECECEC), fontSize: 15, height: 1.5),
        code: TextStyle(color: const Color(0xFFECECEC), backgroundColor: Colors.grey[800], fontSize: 13, fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(color: Colors.grey[400]),
        blockquoteDecoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(4)),
        listBullet: const TextStyle(color: Color(0xFFECECEC)),
        h1: const TextStyle(color: Color(0xFFECECEC), fontSize: 20, fontWeight: FontWeight.bold),
        h2: const TextStyle(color: Color(0xFFECECEC), fontSize: 18, fontWeight: FontWeight.bold),
        h3: const TextStyle(color: Color(0xFFECECEC), fontSize: 16, fontWeight: FontWeight.w600),
        em: const TextStyle(color: Color(0xFFECECEC), fontStyle: FontStyle.italic),
        strong: const TextStyle(color: Color(0xFFECECEC), fontWeight: FontWeight.bold),
        a: const TextStyle(color: Color(0xFF2AABEE), decoration: TextDecoration.underline),
      ),
    );
  }
}

// --- Streaming Indicators ---

class _StreamingDots extends StatefulWidget {
  final double size;
  const _StreamingDots({this.size = 6});

  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = (_controller.value * 3 - i) % 1.0;
            final opacity = progress < 0.5 ? 0.3 + progress * 1.4 : 1.0 - (progress - 0.5) * 1.4;
            return Container(
              width: widget.size,
              height: widget.size,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..repeat(reverse: true);
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
      builder: (context, _) => Opacity(
        opacity: _controller.value,
        child: Container(width: 2, height: 16, margin: const EdgeInsets.only(left: 2), color: Colors.grey[400]),
      ),
    );
  }
}

// --- Thinking/Reasoning ---

class _ThinkingBlock extends StatefulWidget {
  final String reasoning;
  final int? durationMs;
  const _ThinkingBlock({required this.reasoning, this.durationMs});

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  String _formatDuration(int ms) {
    final s = (ms / 1000).round();
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${s % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.reasoning.length;
    final durationStr = widget.durationMs != null && widget.durationMs! > 0 ? _formatDuration(widget.durationMs!) : null;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 14, color: Colors.purple[300]),
                    const SizedBox(width: 6),
                    Text(
                      _expanded ? '收起思考过程' : '思考过程',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (durationStr != null) ...[
                      const SizedBox(width: 6),
                      Text('· $durationStr', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                    const SizedBox(width: 6),
                    Text('· $charCount 字符', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    const Spacer(),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.grey[600]),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey[700]!, width: 2)),
                    ),
                    child: _MarkdownContent(content: widget.reasoning),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Tool Call Line ---

class _ToolCallLine extends StatefulWidget {
  final ToolCall toolCall;
  const _ToolCallLine({required this.toolCall});

  @override
  State<_ToolCallLine> createState() => _ToolCallLineState();
}

class _ToolCallLineState extends State<_ToolCallLine> {
  bool _expanded = false;

  String _truncate(String text, {int limit = 200}) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}...';
  }

  IconData _toolIcon(String tool) {
    final name = tool.toLowerCase();
    if (name.contains('read') || name.contains('file')) return Icons.description_outlined;
    if (name.contains('write') || name.contains('save')) return Icons.save_outlined;
    if (name.contains('search')) return Icons.search;
    if (name.contains('bash') || name.contains('shell') || name.contains('exec')) return Icons.terminal;
    if (name.contains('web') || name.contains('fetch')) return Icons.language;
    return Icons.build_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.toolCall;
    final isRunning = tc.status == ToolStatus.running || tc.status == ToolStatus.pending;
    final isDone = tc.status == ToolStatus.completed;
    final isError = tc.status == ToolStatus.error;
    final hasDetails = tc.arguments != null || tc.output != null;

    return Container(
      margin: const EdgeInsets.only(left: 48, top: 3),
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasDetails)
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 12, color: Colors.grey[500])
                    else
                      Icon(_toolIcon(tc.tool), size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Icon(_toolIcon(tc.tool), size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(tc.tool, style: TextStyle(color: Colors.grey[300], fontSize: 11, fontFamily: 'monospace')),
                    if (tc.preview.isNotEmpty && !_expanded) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Text(_truncate(tc.preview, limit: 80), style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    if (isRunning) ...[
                      const SizedBox(width: 6),
                      const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.orange))),
                    ],
                    if (isDone) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, size: 12, color: Colors.green[400]),
                      if (tc.duration != null) ...[
                        const SizedBox(width: 4),
                        Text('${tc.duration!.toStringAsFixed(1)}s', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      ],
                    ],
                    if (isError) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.error, size: 12, color: Colors.red[400]),
                    ],
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFF3A3A3A)),
                  const SizedBox(height: 6),
                  if (tc.arguments != null) _JsonBlock(label: '参数', data: tc.arguments!),
                  if (tc.output != null) _JsonBlock(label: '结果', data: tc.output!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- JSON Block ---

class _JsonBlock extends StatelessWidget {
  final String label;
  final dynamic data;
  const _JsonBlock({required this.label, required this.data});

  String _format(dynamic data) {
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _truncate(String text, {int limit = 1000}) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}\n... (truncated)';
  }

  @override
  Widget build(BuildContext context) {
    final text = _truncate(_format(data));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4)),
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(text, style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 11, fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Message Meta ---

class _MessageMeta extends StatelessWidget {
  final Message message;
  final VoidCallback? onQuote;
  const _MessageMeta({required this.message, this.onQuote});

  @override
  Widget build(BuildContext context) {
    final hasTokens = message.inputTokens != null || message.outputTokens != null;
    final time = _formatTime(message.createdAt);

    return Padding(
      padding: EdgeInsets.only(left: message.isFromUser ? 0 : 48, right: message.isFromUser ? 48 : 0, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button
          _MetaButton(
            icon: Icons.copy_outlined,
            size: 12,
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
              );
            },
          ),
          if (hasTokens) ...[
            const SizedBox(width: 8),
            Text('↑${message.inputTokens ?? 0} ↓${message.outputTokens ?? 0}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
          const SizedBox(width: 8),
          Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _MetaButton({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: size, color: Colors.grey[500]),
      ),
    );
  }
}

// --- Error & Abort ---

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 48, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[300]),
          const SizedBox(width: 6),
          Flexible(child: Text(error, style: TextStyle(color: Colors.red[300], fontSize: 12))),
        ],
      ),
    );
  }
}

class _AbortCard extends StatelessWidget {
  const _AbortCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 48, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.stop_circle_outlined, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('已中止', style: TextStyle(color: Colors.grey[500], fontSize: 12, decoration: TextDecoration.lineThrough)),
        ],
      ),
    );
  }
}
