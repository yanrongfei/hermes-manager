import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/gateway.dart';
import '../../data/providers/gateway_provider.dart';
import '../../data/providers/room_provider.dart';

class AgentsDirectoryScreen extends ConsumerWidget {
  const AgentsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewaysAsync = ref.watch(gatewaysNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Agents', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: gatewaysAsync.when(
        data: (gateways) => gateways.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text('暂无 Agent', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('请先添加并同步 Gateway', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.read(gatewaysNotifierProvider.notifier).loadGateways();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: gateways.length,
                  itemBuilder: (context, index) => _AgentCard(gateway: gateways[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text('加载失败，请稍后重试', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends ConsumerStatefulWidget {
  final GatewayStatus gateway;

  const _AgentCard({required this.gateway});

  @override
  ConsumerState<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends ConsumerState<_AgentCard> {
  void _startConversation(BuildContext context) async {
    try {
      final room = await ref.read(roomsProvider.notifier).createOneOnOneRoom(
        widget.gateway.profile,
        widget.gateway.profile,
      );
      if (context.mounted) {
        context.push('/chat/${room.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF5856D6),
                  child: Text(
                    widget.gateway.profile.isNotEmpty ? widget.gateway.profile[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gateway.profile,
                        style: const TextStyle(color: Color(0xFFECECEC), fontWeight: FontWeight.w600),
                      ),
                      if (widget.gateway.model != null && widget.gateway.model!.isNotEmpty)
                        Text(
                          '模型 ${widget.gateway.model}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.gateway.running
                        ? const Color(0xFF34C759).withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.gateway.running ? '运行中' : '已停止',
                    style: TextStyle(
                      color: widget.gateway.running ? const Color(0xFF34C759) : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (widget.gateway.running)
                  IconButton(
                    onPressed: () => _startConversation(context),
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF5856D6)),
                    tooltip: '开始对话',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF343541)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: 'Provider', value: widget.gateway.provider ?? '-'),
                _InfoChip(label: '路径', value: _shortPath(widget.gateway.profilePath ?? '')),
                _InfoChip(label: '技能', value: widget.gateway.skillsCount.toString()),
                _InfoChip(label: '.env', value: widget.gateway.hasEnv ? 'Yes' : 'No'),
                _InfoChip(label: 'soul.md', value: widget.gateway.hasSoul ? 'Yes' : 'No'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortPath(String path) {
    if (path.length <= 20) return path;
    final parts = path.split('/');
    if (parts.length <= 3) return path;
    return '.../${parts.sublist(parts.length - 2).join('/')}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF343541),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11),
      ),
    );
  }
}