import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/agent.dart';
import '../../data/providers/profile_provider.dart';

class AgentsDirectoryScreen extends ConsumerWidget {
  const AgentsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(allAgentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Agent 目录', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: agentsAsync.when(
        data: (agents) => agents.isEmpty
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
                  ref.invalidate(allAgentsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: agents.length,
                  itemBuilder: (context, index) => _AgentCard(agent: agents[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text('加载失败，请稍后重试', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Agent agent;

  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF5856D6),
          child: Text(
            agent.name.isNotEmpty ? agent.name[0].toUpperCase() : 'A',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(agent.name, style: const TextStyle(color: Color(0xFFECECEC))),
        subtitle: agent.description != null
            ? Text(agent.description!, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: agent.invited
            ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 16), const SizedBox(width: 4), Text('已邀请', style: TextStyle(color: Colors.grey[500], fontSize: 12))])
            : TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2AABEE), minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () {
                  // TODO: implement invite to room
                },
                child: const Text('邀请', style: TextStyle(fontSize: 13)),
              ),
      ),
    );
  }
}
