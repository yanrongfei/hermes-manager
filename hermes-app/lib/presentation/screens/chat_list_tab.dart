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
      appBar: AppBar(
        title: const Text('对话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(
              child: Text('暂无群聊\n点击右下角创建群聊', textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(roomsProvider.notifier).loadRooms(),
            child: ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: room.avatar != null ? NetworkImage(room.avatar!) : null,
                    child: room.avatar == null ? Text(room.name[0]) : null,
                  ),
                  title: Text(room.name),
                  subtitle: Text(room.mode),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/chat/${room.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoomDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建群聊'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '群聊名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(roomsProvider.notifier).createRoom(nameController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
