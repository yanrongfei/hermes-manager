import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/room_provider.dart';

class ChatListTab extends ConsumerWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('对话', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFA0A0A0)),
            onPressed: () {},
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    '暂无群聊',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角创建群聊',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(roomsProvider.notifier).loadRooms(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Card(
                  color: const Color(0xFF2A2A2A),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF5856D6),
                      child: Text(
                        room.name.isNotEmpty ? room.name[0].toUpperCase() : 'G',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      room.name,
                      style: const TextStyle(color: Color(0xFFECECEC)),
                    ),
                    subtitle: Text(
                      room.mode == 'broadcast' ? '广播模式' : '指定模式',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                    onTap: () => context.push('/chat/${room.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text('加载失败，请检查网络', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'join',
            backgroundColor: const Color(0xFF3A3A3A),
            onPressed: () => _showJoinRoomDialog(context, ref),
            child: const Icon(Icons.link, color: Color(0xFFA0A0A0)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create',
            backgroundColor: const Color(0xFF5856D6),
            onPressed: () => _showCreateRoomDialog(context, ref),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
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
