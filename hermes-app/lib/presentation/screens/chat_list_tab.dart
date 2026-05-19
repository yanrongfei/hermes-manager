import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/room.dart';
import '../../data/providers/room_provider.dart';
import '../../data/providers/api_provider.dart';

class ChatListTab extends ConsumerWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with title and add button
            Container(
              color: const Color(0xFF2A2A2A),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  // Title centered
                  const Expanded(
                    child: Text(
                      'Hermes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFECECEC),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Add button on right
                  GestureDetector(
                    onTapDown: (details) => _showAddMenu(context, ref, details.globalPosition),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5856D6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Container(
              color: const Color(0xFF2A2A2A),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            // Chat list
            Expanded(
              child: roomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(
                            '暂无群聊',
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击右上角 + 创建群聊',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    color: const Color(0xFF212121),
                    child: ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _ChatListItem(room: room);
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: Colors.grey[500]),
                      const SizedBox(height: 12),
                      Text('加载失败，请检查网络', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref, Offset globalPosition) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx - 80,
        globalPosition.dy + 8,
        globalPosition.dx + 80,
        globalPosition.dy,
      ),
      color: const Color(0xFF3A3A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Color(0xFFECECEC), size: 18),
              const SizedBox(width: 12),
              const Text('新建对话', style: TextStyle(color: Color(0xFFECECEC))),
            ],
          ),
          onTap: () => Future.microtask(() => _createNewConversation(context, ref)),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.group_add, color: Color(0xFFECECEC), size: 18),
              const SizedBox(width: 12),
              const Text('发起群聊', style: TextStyle(color: Color(0xFFECECEC))),
            ],
          ),
          onTap: () => Future.microtask(() => _showCreateRoomDialog(context, ref)),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.link, color: Color(0xFFECECEC), size: 18),
              const SizedBox(width: 12),
              const Text('加入群聊', style: TextStyle(color: Color(0xFFECECEC))),
            ],
          ),
          onTap: () => Future.microtask(() => _showJoinRoomDialog(context, ref)),
        ),
      ],
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedMode = 'broadcast';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '创建群聊',
                style: TextStyle(
                  color: Color(0xFFECECEC),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  labelText: '群聊名称',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '协作模式',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('广播模式'),
                    selected: selectedMode == 'broadcast',
                    onSelected: (_) => setState(() => selectedMode = 'broadcast'),
                    selectedColor: const Color(0xFF5856D6),
                    labelStyle: TextStyle(
                      color: selectedMode == 'broadcast'
                          ? Colors.white
                          : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('指定模式'),
                    selected: selectedMode == 'mention',
                    onSelected: (_) => setState(() => selectedMode = 'mention'),
                    selectedColor: const Color(0xFF5856D6),
                    labelStyle: TextStyle(
                      color: selectedMode == 'mention'
                          ? Colors.white
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5856D6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      await ref.read(roomsProvider.notifier).createRoom(
                        nameController.text.trim(),
                        mode: selectedMode,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    '创建',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewConversation(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/rooms', data: {'name': '新对话', 'mode': 'broadcast'});
    final room = Room.fromJson(response.data);
    if (context.mounted) {
      context.push('/chat/${room.id}');
    }
  }

  void _showJoinRoomDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '加入群聊',
              style: TextStyle(
                color: Color(0xFFECECEC),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              style: const TextStyle(color: Color(0xFFECECEC)),
              decoration: InputDecoration(
                labelText: '邀请码',
                labelStyle: TextStyle(color: Colors.grey[500]),
                hintText: '输入6位邀请码',
                hintStyle: TextStyle(color: Colors.grey[700]),
                filled: true,
                fillColor: const Color(0xFF343541),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5856D6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (codeController.text.isNotEmpty) {
                    await ref.read(roomsProvider.notifier).joinByCode(
                      codeController.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  '加入',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final dynamic room;

  const _ChatListItem({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(room.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text('删除对话', style: TextStyle(color: Color(0xFFECECEC))),
            content: Text('确定删除"${room.name}"吗？', style: const TextStyle(color: Color(0xFFECECEC))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        ref.read(roomsProvider.notifier).deleteRoom(room.id);
      },
      child: InkWell(
        onTap: () => context.push('/chat/${room.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    room.name.isNotEmpty ? room.name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: const TextStyle(
                              color: Color(0xFFECECEC),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '刚刚',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            room.mode == 'broadcast' ? '广播模式' : '指定模式',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5856D6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '99+',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
