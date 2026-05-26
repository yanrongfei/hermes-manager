import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/message.dart';
import '../../data/models/room.dart';
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
  bool _showScrollBottom = false;
  bool _isLoadingMoreHistory = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Listen for agent_busy toast
    ref.listen(chatProvider(widget.roomId), (prev, next) {
      if (prev?.agentBusyMessage != next.agentBusyMessage && next.agentBusyMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(next.agentBusyMessage!),
                backgroundColor: Colors.orange,
                duration: const Duration(milliseconds: 2500),
              ),
            );
          }
        });
      }
    });
  }

  // With reverse: true on ListView:
  // - offset 0 = bottom (newest messages)
  // - maxScrollExtent = top (oldest messages)
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Show scroll-to-bottom button when user has scrolled up away from bottom
    final show = _scrollController.offset > 200;
    if (show != _showScrollBottom) setState(() => _showScrollBottom = show);

    // Load more when near top (oldest messages)
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent - _scrollController.offset < 200 && !_isLoadingMoreHistory) {
      final chatState = ref.read(chatProvider(widget.roomId));
      if (chatState.hasMore && !chatState.isLoadingMore && chatState.messages.isNotEmpty) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMoreHistory) return;
    _isLoadingMoreHistory = true;
    ref.read(chatProvider(widget.roomId).notifier).loadMore();
    // Wait for state update and next frame
    await Future.delayed(const Duration(milliseconds: 100));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isLoadingMoreHistory = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  Room? get _currentRoom {
    final roomsState = ref.read(roomsProvider);
    return roomsState.whenOrNull(
      data: (rooms) => rooms.where((r) => r.id == widget.roomId).firstOrNull,
    );
  }

  bool get _is1v1 => _currentRoom?.is1v1 ?? widget.roomName != null;

  void _syncLastMessageToRoomList() {
    ref.read(roomsProvider.notifier).markRoomRead(widget.roomId);
    final chatState = ref.read(chatProvider(widget.roomId));
    final messages = chatState.messages;
    if (messages.isEmpty) return;
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isStreaming && m.content.trim().isNotEmpty) {
        ref.read(roomsProvider.notifier).updateRoomPreview(
          widget.roomId,
          m.content.replaceAll('\n', ' ').trim(),
          m.createdAt,
        );
        return;
      }
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(content);
    _messageController.clear();
    _showMentionPicker = false;
    _focusNode.requestFocus();
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

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _syncLastMessageToRoomList();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: _is1v1 ? _build1v1AppBar() : _buildGroupAppBar(),
      body: Column(
        children: [
          // Running agents bar (group only)
          if (!_is1v1 && hasRunningAgents)
            _RunningAgentsBar(
              count: chatState.runningAgents.length,
              onAbort: _sendAbort,
              isAborting: isAborting,
            ),

          // Queue indicator (group only)
          if (!_is1v1 && chatState.queueLength > 0)
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

          // Messages - reverse ListView for WeChat-like behavior
          Expanded(
            child: Stack(
              children: [
                chatState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : chatState.error != null && chatState.messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.grey[500]),
                                const SizedBox(height: 12),
                                Text('连接失败', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => ref.read(chatProvider(widget.roomId).notifier).reconnect(),
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          )
                        : chatState.messages.isEmpty
                        ? Center(
                            child: Text(
                              '暂无消息\n发送消息开始对话',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          )
                        : _buildMessageList(chatState),
                if (_showScrollBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: const Color(0xFF2A2A2A),
                      onPressed: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
                    ),
                  ),
              ],
            ),
          ),

          // @mention picker (group only)
          if (!_is1v1 && _showMentionPicker && widget.agents.isNotEmpty)
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
      ),
    );
  }

  /// Reversed ListView: newest messages at bottom, oldest at top.
  /// - reverse: true → ListView renders bottom-to-top, starts at offset 0 (bottom)
  /// - Messages are reversed: index 0 = newest (at bottom), index N = oldest (at top)
  /// - Load-more indicator at the very top (end of reversed list)
  /// - No scroll hack needed: naturally starts showing latest messages
  Widget _buildMessageList(ChatState chatState) {
    final reversedMessages = chatState.messages.reversed.toList();
    final itemCount = reversedMessages.length + (chatState.hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Load-more indicator at the top (end of reversed list)
        if (index == reversedMessages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: chatState.isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '上拉加载更多',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
            ),
          );
        }

        final message = reversedMessages[index];
        final toolCalls = chatState.toolCalls[message.id];
        final thinkingMs = chatState.thinkingStartedAt[message.id] != null
            ? DateTime.now().millisecondsSinceEpoch - chatState.thinkingStartedAt[message.id]!
            : null;
        return MessageBubble(
          message: message,
          toolCalls: toolCalls,
          thinkingDurationMs: message.isStreaming ? thinkingMs : null,
        );
      },
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Group chat: show @ button for mentions; 1:1: no button
            if (!_is1v1)
              IconButton(
                icon: const Icon(Icons.alternate_email, color: Color(0xFFA0A0A0)),
                onPressed: () {
                  // Focus input and show mention picker
                  _focusNode.requestFocus();
                },
              ),
            if (_is1v1)
              const SizedBox(width: 48), // Placeholder for 1:1 to align input
            Flexible(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: _onTextChanged,
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF5856D6)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _build1v1AppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFFECECEC)),
        onPressed: () {
          _syncLastMessageToRoomList();
          context.pop();
        },
      ),
      title: Text(
        _getDisplayName().isNotEmpty ? _getDisplayName() : '对话',
        style: const TextStyle(color: Color(0xFFECECEC), fontSize: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFECECEC)),
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildGroupAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFFECECEC)),
        onPressed: () {
          _syncLastMessageToRoomList();
          context.pop();
        },
      ),
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
            } else if (value == 'members') {
              _showMembersSheet();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'members',
              child: Row(
                children: [
                  Icon(Icons.people, color: Color(0xFFECECEC), size: 18),
                  SizedBox(width: 12),
                  Text('成员', style: TextStyle(color: Color(0xFFECECEC))),
                ],
              ),
            ),
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
    );
  }

  void _showMembersSheet() {
    // TODO: Implement members sheet
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
