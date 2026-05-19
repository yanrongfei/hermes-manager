import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/message.dart';
import '../../data/providers/chat_provider.dart';
import '../../data/providers/room_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomName; // For 1:1 chats, the agent name
  final List<Message> agents; // Agents in this room for @mention

  const ChatScreen({
    super.key,
    required this.roomId,
    this.roomName,
    this.agents = const [],
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _roomNameController = TextEditingController();
  bool _isTyping = false;
  bool _showMentionPicker = false;
  String _mentionQuery = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(content);
    _messageController.clear();
    _showMentionPicker = false;
  }

  void _sendAbort() {
    ref.read(chatProvider(widget.roomId).notifier).sendAbort();
  }

  void _onTextChanged(String value) {
    // Detect @mention
    final cursorPos = _messageController.selection.baseOffset;
    if (cursorPos <= 0) {
      setState(() => _showMentionPicker = false);
      return;
    }

    final textBefore = value.substring(0, cursorPos);
    final atIndex = textBefore.lastIndexOf('@');

    if (atIndex != -1) {
      final afterAt = textBefore.substring(atIndex + 1);
      // Only show if no space after @
      if (!afterAt.contains(' ') && !afterAt.contains('\n')) {
        setState(() {
          _showMentionPicker = true;
          _mentionQuery = afterAt.toLowerCase();
        });
        return;
      }
    }

    setState(() => _showMentionPicker = false);

    // Typing indicator
    if (value.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(chatProvider(widget.roomId).notifier).sendTyping();
    } else if (value.isEmpty && _isTyping) {
      _isTyping = false;
      ref.read(chatProvider(widget.roomId).notifier).sendStopTyping();
    }
  }

  void _insertMention(String agentName) {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;
    final textBefore = text.substring(0, cursorPos);
    final atIndex = textBefore.lastIndexOf('@');

    final newText = text.substring(0, atIndex) + '@$agentName ' + text.substring(cursorPos);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + agentName.length + 2),
    );

    setState(() => _showMentionPicker = false);
    _focusNode.requestFocus();
  }

  String _getDisplayName() {
    // Priority: roomName (1:1 chat) > agents name > '群聊'
    if (widget.roomName != null && widget.roomName!.isNotEmpty) {
      return widget.roomName!;
    }
    if (widget.agents.isNotEmpty && widget.agents.first.senderName != null) {
      return widget.agents.first.senderName!;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.roomId));
    final hasRunningAgents = chatState.runningAgents.isNotEmpty;
    final isAborting = chatState.compressingStatus != null;

    // Auto-scroll on new messages
    ref.listen(chatProvider(widget.roomId), (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: GestureDetector(
          onTap: () => _showEditNameDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF5856D6),
                child: Text(
                  _getDisplayName().isNotEmpty
                      ? _getDisplayName()[0].toUpperCase()
                      : '群'[0],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getDisplayName().isNotEmpty ? _getDisplayName() : '群聊',
                style: const TextStyle(color: Color(0xFFECECEC), fontSize: 16),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, color: Colors.grey, size: 14),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            color: const Color(0xFF3A3A3A),
            onSelected: (value) {
              if (value == 'invite') {
                _showInviteDialog();
              } else if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: Color(0xFFECECEC), size: 18),
                    SizedBox(width: 12),
                    Text('邀请成员', style: TextStyle(color: Color(0xFFECECEC))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 12),
                    Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Running agents bar
          if (hasRunningAgents)
            _RunningAgentsBar(
              count: chatState.runningAgents.length,
              onAbort: _sendAbort,
              isAborting: isAborting,
            ),

          // Queue indicator
          if (chatState.queueLength > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: const Color(0xFF3A3A3A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${chatState.queueLength} 条消息等待中...',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? Center(
                        child: Text(
                          '暂无消息\n发送消息开始对话',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          final toolCalls = chatState.toolCalls[message.id];
                          return MessageBubble(
                            message: message,
                            toolCalls: toolCalls,
                          );
                        },
                      ),
          ),

          // @mention picker
          if (_showMentionPicker && widget.agents.isNotEmpty)
            _MentionPicker(
              agents: widget.agents.where((a) =>
                a.senderName!.toLowerCase().contains(_mentionQuery)
              ).toList(),
              onSelect: _insertMention,
              onDismiss: () => setState(() => _showMentionPicker = false),
            ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Color(0xFF3A3A3A))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFA0A0A0)),
              onPressed: () => _showAttachmentSheet(),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  hintText: '输入消息或在群聊中@成员...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.mic, color: Color(0xFFA0A0A0)),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF5856D6)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '邀请成员',
              style: TextStyle(
                color: Color(0xFFECECEC),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF5856D6)),
              title: const Text('添加 Agent', style: TextStyle(color: Color(0xFFECECEC))),
              subtitle: Text('将 Agent 添加到群聊', style: TextStyle(color: Colors.grey[500])),
              onTap: () {
                Navigator.pop(context);
                // TODO: navigate to agent selector
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Color(0xFF5856D6)),
              title: const Text('邀请码', style: TextStyle(color: Color(0xFFECECEC))),
              subtitle: Text('分享邀请码给其他用户', style: TextStyle(color: Colors.grey[500])),
              onTap: () {
                Navigator.pop(context);
                // TODO: show invite code
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF5856D6)),
              title: const Text('图片', style: TextStyle(color: Color(0xFFECECEC))),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF5856D6)),
              title: const Text('拍照', style: TextStyle(color: Color(0xFFECECEC))),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF5856D6)),
              title: const Text('文件', style: TextStyle(color: Color(0xFFECECEC))),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
        content: const Text('确定要删除这个对话吗？', style: TextStyle(color: Color(0xFFECECEC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(roomsProvider.notifier).deleteRoom(widget.roomId);
              if (mounted) {
                context.go('/home');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    _roomNameController.text = _getDisplayName().isNotEmpty ? _getDisplayName() : '群聊';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('编辑对话名称', style: TextStyle(color: Color(0xFFECECEC))),
        content: TextField(
          controller: _roomNameController,
          style: const TextStyle(color: Color(0xFFECECEC)),
          decoration: InputDecoration(
            hintText: '输入对话名称',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF343541),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = _roomNameController.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(chatProvider(widget.roomId).notifier).updateRoomName(newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _RunningAgentsBar extends StatelessWidget {
  final int count;
  final VoidCallback onAbort;
  final bool isAborting;

  const _RunningAgentsBar({
    required this.count,
    required this.onAbort,
    required this.isAborting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF343541),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAborting
                  ? 'Agent 正在中止...'
                  : '$count 个 Agent 正在思考...',
              style: const TextStyle(color: Color(0xFFECECEC), fontSize: 13),
            ),
          ),
          if (!isAborting)
            TextButton(
              onPressed: onAbort,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              child: const Text(
                '停止',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _MentionPicker extends StatelessWidget {
  final List<Message> agents;
  final void Function(String) onSelect;
  final VoidCallback onDismiss;

  const _MentionPicker({
    required this.agents,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: const Color(0xFF2A2A2A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '选择 Agent',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3A3A3A)),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF5856D6),
                    child: Text(
                      (agent.senderName ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    agent.senderName ?? 'Agent',
                    style: const TextStyle(color: Color(0xFFECECEC)),
                  ),
                  onTap: () => onSelect(agent.senderName ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
